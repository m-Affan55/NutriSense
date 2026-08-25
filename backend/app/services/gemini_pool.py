import logging
import threading
import datetime
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
    disabling exhausted keys for the day per model to ensure near-zero latency failovers.
    """
    _instance = None
    _lock = threading.Lock()

    def __init__(self):
        self._keys = settings.get_gemini_keys()
        self._last_reset_date = datetime.date.today()
        self._quota_status = {}
        self._reset_quotas()
        logger.info(f"Initialized GeminiPool with {len(self._keys)} active API key(s) and stateful daily tracking.")

    def _reset_quotas(self):
        priority_models = [
            "gemini-3.5-flash-lite",  # Fastest (~0.75s latency, 30 RPM)
            "gemini-3.5-flash",       # Fast (~1.4s latency, 15 RPM)
            "gemini-3.7-flash",       # Highest capability (15 RPM)
            "gemini-3.6-flash"        # Fallback capability (15 RPM)
        ]
        for m in priority_models:
            self._quota_status[m] = [True] * len(self._keys)
        logger.info("Daily rate-limit tracking quotas reset to True for all active models.")

    @classmethod
    def get_instance(cls) -> "GeminiPool":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = GeminiPool()
        return cls._instance

    def _get_client(self, index: int) -> genai.Client:
        key = self._keys[index % len(self._keys)]
        return genai.Client(
            api_key=key,
            http_options=types.HttpOptions(timeout=30_000),
        )

    def generate_content(
        self,
        contents: Any,
        model: str = "gemini-3.5-flash-lite",  # Default to the fastest model first
        config: Optional[types.GenerateContentConfig] = None,
        max_retries: Optional[int] = None
    ) -> Any:
        # Check for daily reset
        today = datetime.date.today()
        with self._lock:
            if self._last_reset_date != today:
                self._reset_quotas()
                self._last_reset_date = today

        priority_models = [
            "gemini-3.5-flash-lite",
            "gemini-3.5-flash",
            "gemini-3.7-flash",
            "gemini-3.6-flash"
        ]
        models_to_try = [model] + [m for m in priority_models if m != model]
        last_error = None

        for current_model in models_to_try:
            while True:
                key_idx = None
                with self._lock:
                    if current_model not in self._quota_status:
                        self._quota_status[current_model] = [True] * len(self._keys)
                    
                    # Pick the first key index that has remaining rate limits for this model
                    for i in range(len(self._keys)):
                        if self._quota_status[current_model][i]:
                            key_idx = i
                            break

                # If all keys for this model are exhausted, skip to next model generation
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
                    
                    # If it's a rate limit / quota exhaustion (429), mark key as false for today and retry another key
                    if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str or "quota" in err_str.lower():
                        logger.warning(
                            f"Model {current_model} on key #{key_idx+1} ({masked_key}) hit rate limit. Disabling key for today."
                        )
                        with self._lock:
                            self._quota_status[current_model][key_idx] = False
                    # If it's a timeout or network deadline error (504, 503, timeout), rotate key and skip directly to the next model
                    elif "504" in err_str or "503" in err_str or "timeout" in err_str.lower() or "timed out" in err_str.lower() or "deadline" in err_str.lower():
                        logger.warning(
                            f"Model {current_model} on key #{key_idx+1} ({masked_key}) timed out or returned 504/503. Skipping model generation."
                        )
                        break  # Break key attempts loop for this model and try next model generation
                    else:
                        logger.error(f"Gemini API error on model {current_model}, key #{key_idx+1}: {e}")
                        # Disable key for today on unhandled API exceptions to prevent crash loops
                        with self._lock:
                            self._quota_status[current_model][key_idx] = False

        raise RateLimitExceeded(f"All Gemini API keys and models exhausted. Last error: {last_error}")

gemini_pool = GeminiPool.get_instance()
