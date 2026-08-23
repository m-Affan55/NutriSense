import logging
import threading
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
    Manages a pool of Gemini API keys with automatic round-robin 
    and instant failover on 429 Quota Exceeded / Resource Exhausted errors.
    """
    _instance = None
    _lock = threading.Lock()

    def __init__(self):
        self._keys = settings.get_gemini_keys()
        self._current_index = 0
        logger.info(f"Initialized GeminiPool with {len(self._keys)} active API key(s).")

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
            http_options=types.HttpOptions(timeout=10_000),
        )

    def generate_content(
        self,
        contents: Any,
        model: str = "gemini-3.6-flash",
        config: Optional[types.GenerateContentConfig] = None,
        max_retries: Optional[int] = None
    ) -> Any:
        total_keys = len(self._keys)
        attempts = max_retries if max_retries is not None else max(total_keys * 2, 2)
        last_error = None

        for attempt in range(attempts):
            with self._lock:
                idx = self._current_index
            
            masked_key = self._keys[idx][:8] + "..." if len(self._keys[idx]) > 8 else "***"
            try:
                client = self._get_client(idx)
                response = client.models.generate_content(
                    model=model,
                    contents=contents,
                    config=config,
                )
                return response
            except Exception as e:
                err_str = str(e)
                last_error = e
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str or "quota" in err_str.lower():
                    logger.warning(
                        f"Key #{idx+1} ({masked_key}) hit 429 Rate Limit. Attempting failover to next key in pool..."
                    )
                    with self._lock:
                        self._current_index = (self._current_index + 1) % total_keys
                else:
                    logger.error(f"Gemini API error on key #{idx+1}: {e}")
                    with self._lock:
                        self._current_index = (self._current_index + 1) % total_keys

        raise RateLimitExceeded(f"All Gemini API keys in pool exhausted or failed. Last error: {last_error}")

gemini_pool = GeminiPool.get_instance()
