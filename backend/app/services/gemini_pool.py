import logging
import threading
import time
from typing import Any, Dict, List, Optional, Set
from google import genai
from google.genai import types
from app.core.config import settings

logger = logging.getLogger("gemini_pool")

# ---------------------------------------------------------------------------
# Verified available models (confirmed via Google AI Studio API, Sep 2026).
# Ordered from newest/best to oldest/lightest for general-purpose fallback.
# ---------------------------------------------------------------------------
PRIORITY_MODELS: List[str] = [
    "gemini-3.8-flash",        # Newest flash — highest quality
    "gemini-3.7-flash",        # Excellent reasoning, structured output
    "gemini-3.6-flash",        # Solid all-rounder, vision-capable
    "gemini-3.5-flash",        # Balanced speed / quality
    "gemini-3.5-flash-lite",   # Fast & cheap text tasks
    "gemini-3.1-flash-lite",   # Fallback lite
    "gemini-2.5-flash-lite",   # Last-resort lite (oldest confirmed)
]

# Models confirmed to accept image / multimodal inputs (vision-capable)
VISION_CAPABLE_MODELS: Set[str] = {
    "gemini-3.8-flash",
    "gemini-3.7-flash",
    "gemini-3.6-flash",
    "gemini-3.5-flash",
}

# ---------------------------------------------------------------------------
# Task-tier aliases — import and use these in service files instead of raw
# string literals so that updating the model name is a one-line change here.
# ---------------------------------------------------------------------------
MODEL_SIMPLE_TEXT   = "gemini-3.5-flash-lite"  # Coaching summaries, one-liners
MODEL_CLINICAL_JSON = "gemini-3.5-flash"         # Macros, ingredients, barcode
MODEL_COMPLEX_JSON  = "gemini-3.7-flash"         # Workout plans, weekly reports
MODEL_VISION        = "gemini-3.6-flash"         # Meal image scan (vision)


class RateLimitExceeded(Exception):
    """Raised when all API keys have exhausted their quotas across all fallback models."""
    pass


class GeminiPool:
    """
    Manages a pool of Gemini API keys with automatic stateful rate-limit
    tracking, client-instance reuse, and rolling cooldowns for efficient
    failover.

    Key design decisions:
    - PRIORITY_MODELS is the single source of truth for model ordering.
    - Vision support is determined by VISION_CAPABLE_MODELS (not string matching).
    - current_time is refreshed inside each retry iteration to avoid stale comparisons.
    - Thinking budget is NOT injected globally; callers set it via their config.
    """

    _instance: Optional["GeminiPool"] = None
    _lock = threading.Lock()

    def __init__(self) -> None:
        self._keys: List[str] = settings.get_gemini_keys()
        # Quota status: model_name -> list of unlock timestamps (one per key index).
        # 0.0 means "available immediately".
        self._quota_status: Dict[str, List[float]] = {}
        # Keys permanently quarantined due to 403 / invalid credentials
        self._disabled_keys: Set[int] = set()

        # One genai.Client per API key — reuse HTTP connections
        self._clients: List[genai.Client] = [
            genai.Client(
                api_key=key,
                http_options=types.HttpOptions(timeout=60_000),
            )
            for key in self._keys
        ]
        self._reset_quotas()
        logger.info(
            f"GeminiPool initialised with {len(self._keys)} API key(s) "
            f"and {len(PRIORITY_MODELS)} tracked model(s)."
        )

    def _reset_quotas(self) -> None:
        """Pre-populate quota tracking for all known priority models."""
        for model in PRIORITY_MODELS:
            self._quota_status[model] = [0.0] * len(self._keys)
        logger.info("Rate-limit quotas reset to active for all models.")

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
        model: str = MODEL_CLINICAL_JSON,
        config: Optional[types.GenerateContentConfig] = None,
        require_vision: bool = False,
    ) -> Any:
        """
        Generate content with automatic key rotation and model fallback.

        Args:
            contents:       The prompt / multimodal content to send.
            model:          Preferred model name. Use the MODULE_* constants above.
            config:         Optional GenerateContentConfig, passed through as-is.
            require_vision: If True, only vision-capable models are attempted.
        """
        import copy

        # Build the ordered list of models to try
        if require_vision:
            vision_fallbacks = [m for m in PRIORITY_MODELS if m in VISION_CAPABLE_MODELS]
            if model not in VISION_CAPABLE_MODELS:
                logger.warning(
                    f"Model '{model}' does not support vision; "
                    f"switching to '{vision_fallbacks[0]}' for this request."
                )
                model = vision_fallbacks[0]
            models_to_try = [model] + [m for m in vision_fallbacks if m != model]
        else:
            models_to_try = [model] + [m for m in PRIORITY_MODELS if m != model]

        last_error: Optional[Exception] = None

        for current_model in models_to_try:
            # Ensure this model has a quota tracking slot (handles ad-hoc model names)
            with self._lock:
                if current_model not in self._quota_status:
                    self._quota_status[current_model] = [0.0] * len(self._keys)

            while True:
                # ⚠️  Refresh timestamp on EVERY iteration — prevents stale
                # comparisons after a cooldown period elapses mid-retry loop.
                current_time = time.time()

                key_idx: Optional[int] = None
                with self._lock:
                    for i in range(len(self._keys)):
                        if i in self._disabled_keys:
                            continue
                        if self._quota_status[current_model][i] <= current_time:
                            key_idx = i
                            break

                # All keys for this model are cooling down — advance to next model
                if key_idx is None:
                    logger.debug(
                        f"All keys cooling down for '{current_model}'; "
                        f"advancing to next fallback model."
                    )
                    break

                masked_key = (
                    self._keys[key_idx][:8] + "..."
                    if len(self._keys[key_idx]) > 8
                    else "***"
                )

                try:
                    client = self._get_client(key_idx)
                    # Deep-copy config so callers' objects are never mutated
                    req_config = (
                        copy.deepcopy(config)
                        if config is not None
                        else types.GenerateContentConfig()
                    )

                    response = client.models.generate_content(
                        model=current_model,
                        contents=contents,
                        config=req_config,
                    )
                    return response

                except Exception as e:
                    err_str = str(e)
                    last_error = e

                    # 1. 403 / PERMISSION_DENIED — quarantine key permanently
                    if (
                        "403" in err_str
                        or "permission" in err_str.lower()
                        or "denied" in err_str.lower()
                        or "api key not valid" in err_str.lower()
                    ):
                        logger.warning(
                            f"Key #{key_idx + 1} ({masked_key}) denied access (403). "
                            f"Quarantining permanently across all models."
                        )
                        with self._lock:
                            self._disabled_keys.add(key_idx)
                            for m in self._quota_status:
                                self._quota_status[m][key_idx] = time.time() + 86_400.0
                        continue  # Try next key on the same model

                    # 2. 429 / RESOURCE_EXHAUSTED — 60 s rolling cooldown
                    elif (
                        "429" in err_str
                        or "RESOURCE_EXHAUSTED" in err_str
                        or "quota" in err_str.lower()
                    ):
                        logger.warning(
                            f"Rate limit on '{current_model}' key #{key_idx + 1} "
                            f"({masked_key}). Cooling down 60 s."
                        )
                        with self._lock:
                            self._quota_status[current_model][key_idx] = time.time() + 60.0
                        continue  # Try next key on this model

                    # 3. 404 / NOT_FOUND — model deprecated or unavailable
                    elif "404" in err_str or "not found" in err_str.lower():
                        logger.warning(
                            f"Model '{current_model}' not found (404). Skipping model."
                        )
                        break  # Skip to the next model family

                    # 4. 503 / 504 / timeout — transient outage, 30 s cooldown
                    elif (
                        "504" in err_str
                        or "503" in err_str
                        or "timeout" in err_str.lower()
                        or "timed out" in err_str.lower()
                        or "deadline" in err_str.lower()
                    ):
                        logger.warning(
                            f"Transient outage on '{current_model}' key "
                            f"#{key_idx + 1} ({masked_key}): {e}. Cooling down 30 s."
                        )
                        with self._lock:
                            self._quota_status[current_model][key_idx] = time.time() + 30.0
                        continue

                    # 5. Unexpected error — 10 s cooldown, then try next key
                    else:
                        logger.error(
                            f"Unexpected Gemini API error on '{current_model}' "
                            f"key #{key_idx + 1} ({masked_key}): {e}"
                        )
                        with self._lock:
                            self._quota_status[current_model][key_idx] = time.time() + 10.0
                        continue

        raise RateLimitExceeded(
            f"All Gemini API keys and fallback models exhausted. "
            f"Last error: {last_error}"
        )


gemini_pool = GeminiPool.get_instance()


