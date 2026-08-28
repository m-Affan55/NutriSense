import logging
import threading
import time
from typing import Any, List, Optional
from google import genai
from google.genai import types
from app.core.config import settings

logger = logging.getLogger("gemini_pool")

class RateLimitExceeded(Exception):
    """Raised when all API keys have exhausted their quotas."""
    pass

class GeminiPool:
    """
    Manages a pool of Gemini API keys with automatic stateful rate limit tracking,
    reusing client instances and utilizing rolling cooldowns for efficient failover.
    """
    _instance = None
    _lock = threading.Lock()

    def __init__(self):
        self._keys = settings.get_gemini_keys()
        self._quota_status = {}
        
        # Instantiate genai.Client instances once per API key for connection reuse
        self._clients = [
            genai.Client(
                api_key=key,
                http_options=types.HttpOptions(timeout=12_000),  # Reduced timeout to 12s for faster failover
            )
            for key in self._keys
        ]
        self._reset_quotas()
        logger.info(f"Initialized GeminiPool with {len(self._keys)} active API key(s) and rolling rate limit tracking.")

    def _reset_quotas(self):
        priority_models = [
            "gemini-2.5-flash-lite",
            "gemini-2.5-flash",
            "gemini-3-flash-preview"
        ]
        for m in priority_models:
            # Stores the timestamp when a key is allowed to be used again (0.0 means immediately)
            self._quota_status[m] = [0.0] * len(self._keys)
        logger.info("Rate-limit tracking quotas reset to active for all models.")

    @classmethod
    def get_instance(cls) -> "GeminiPool":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = GeminiPool()
        return cls._instance

    def _get_client(self, index: int) -> genai.Client:
        if not self._clients:
            raise RuntimeError("No Gemini API keys configured.")
        return self._clients[index % len(self._clients)]

    def generate_content(
        self,
        contents: Any,
        model: str = "gemini-2.5-flash-lite",  # Default to the fastest model
        config: Optional[types.GenerateContentConfig] = None,
        max_retries: Optional[int] = None,
        require_vision: bool = False
    ) -> Any:
        priority_models = [
            "gemini-2.5-flash-lite",
            "gemini-2.5-flash",
            "gemini-3-flash-preview"
        ]

        # If the task requires vision, exclude model families that don't support image inputs
        if require_vision:
            priority_models = [m for m in priority_models if m != "gemini-2.5-flash-lite"]
            if model == "gemini-2.5-flash-lite":
                model = "gemini-2.5-flash"

        models_to_try = [model] + [m for m in priority_models if m != model]
        last_error = None
        current_time = time.time()

        for current_model in models_to_try:
            while True:
                key_idx = None
                with self._lock:
                    if current_model not in self._quota_status:
                        self._quota_status[current_model] = [0.0] * len(self._keys)
                    
                    # Pick the first key that is not in a rate-limit cooldown
                    for i in range(len(self._keys)):
                        if self._quota_status[current_model][i] <= current_time:
                            key_idx = i
                            break

                # If all keys for this model are currently cooling down, move to the next model family
                if key_idx is None:
                    break

                masked_key = self._keys[key_idx][:8] + "..." if len(self._keys[key_idx]) > 8 else "***"
                try:
                    client = self._get_client(key_idx)
                    response = client.models.generate_content(
                        model=current_model,
                        contents=contents,
                        config=config,
                    )
                    return response
                except Exception as e:
                    err_str = str(e)
                    last_error = e
                    
                    # 1. Catch non-transient developer/setup errors (400, 404, 403, invalid arguments)
                    # and propagate them instantly without trying other keys/models to avoid latency hangs.
                    is_non_transient = (
                        "400" in err_str or
                        "404" in err_str or
                        "403" in err_str or
                        "invalid" in err_str.lower() or
                        "not found" in err_str.lower() or
                        "permission" in err_str.lower()
                    )
                    if is_non_transient:
                        logger.error(f"Non-transient Gemini API error on model {current_model}: {e}")
                        raise e
                    
                    # 2. Handle rate limits (429 / RESOURCE_EXHAUSTED) -> put key on a short cooldown (60s)
                    if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str or "quota" in err_str.lower():
                        logger.warning(
                            f"Model {current_model} on key #{key_idx+1} ({masked_key}) hit rate limit. Cooling down for 60s."
                        )
                        with self._lock:
                            self._quota_status[current_model][key_idx] = time.time() + 60.0
                            
                    # 3. Handle network timeouts or deadlines (504, 503, timeout) -> skip directly to next model
                    elif "504" in err_str or "503" in err_str or "timeout" in err_str.lower() or "timed out" in err_str.lower() or "deadline" in err_str.lower():
                        logger.warning(
                            f"Model {current_model} on key #{key_idx+1} ({masked_key}) timed out or returned 504/503. Skipping model generation."
                        )
                        break  # Try the next model family
                    else:
                        logger.error(f"Gemini API error on model {current_model}, key #{key_idx+1}: {e}")
                        # Cooling down for 10 seconds for general unexpected network/API errors
                        with self._lock:
                            self._quota_status[current_model][key_idx] = time.time() + 10.0

        raise RateLimitExceeded(f"All Gemini API keys and models exhausted. Last error: {last_error}")

gemini_pool = GeminiPool.get_instance()
