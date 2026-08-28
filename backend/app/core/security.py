import base64
import json
import threading
import time
from collections import OrderedDict
from typing import Optional

from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.db.supabase_client import get_supabase_admin_client

security_scheme = HTTPBearer()


class JwtCache:
    """
    Thread-safe, in-memory TTL cache for validated JWTs.

    Eliminates the per-message Supabase Auth network round-trip by remembering
    token -> user_id mappings. Entries expire slightly before the JWT's own
    'exp' claim and are additionally bounded to a maximum freshness window.
    """
    _instance = None
    _lock = threading.Lock()
    MAX_ENTRIES = 2000
    MAX_CACHE_SECONDS = 600  # Never trust a cached token for more than 10 minutes
    EXP_MARGIN_SECONDS = 60  # Expire cache well before the JWT itself expires

    def __init__(self):
        self._entries: OrderedDict[str, tuple] = OrderedDict()
        self._cache_lock = threading.Lock()

    @classmethod
    def get_instance(cls) -> "JwtCache":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = JwtCache()
        return cls._instance

    def _decode_exp(self, token: str) -> Optional[int]:
        """Extract the 'exp' claim from a JWT without verifying the signature."""
        try:
            payload_part = token.split(".")[1]
            payload_part += "=" * (-len(payload_part) % 4)
            payload = json.loads(base64.urlsafe_b64decode(payload_part))
            exp = payload.get("exp")
            return int(exp) if exp else None
        except Exception:
            return None

    def get(self, token: str) -> Optional[str]:
        """Return cached user_id if the entry is still fresh, else None."""
        now = time.time()
        with self._cache_lock:
            entry = self._entries.get(token)
            if entry is None:
                return None
            user_id, cached_until = entry
            if now >= cached_until:
                self._entries.pop(token, None)
                return None
            self._entries.move_to_end(token)
            return user_id

    def set(self, token: str, user_id: str) -> None:
        """Cache a validated token until min(jwt exp - margin, now + max window)."""
        exp = self._decode_exp(token)
        if exp is None:
            return
        now = time.time()
        cached_until = min(exp - self.EXP_MARGIN_SECONDS, now + self.MAX_CACHE_SECONDS)
        if cached_until <= now:
            return
        with self._cache_lock:
            self._entries[token] = (user_id, cached_until)
            self._entries.move_to_end(token)
            if len(self._entries) > self.MAX_ENTRIES:
                self._entries.popitem(last=False)


jwt_cache = JwtCache.get_instance()


def get_current_user_id(credentials: HTTPAuthorizationCredentials = Security(security_scheme)) -> str:
    """
    FastAPI security dependency to verify the Supabase JWT from the Authorization header
    and return the authenticated user ID.

    Validated tokens are cached in-memory (TTL bounded by the JWT's own expiry),
    so subsequent chat messages skip the Supabase Auth network round-trip.
    """
    token = credentials.credentials

    cached_user_id = jwt_cache.get(token)
    if cached_user_id:
        return cached_user_id

    try:
        supabase = get_supabase_admin_client()
        user_resp = supabase.auth.get_user(token)
        if not user_resp or not user_resp.user:
            raise HTTPException(status_code=401, detail="Invalid authentication token")
        jwt_cache.set(token, user_resp.user.id)
        return user_resp.user.id
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")
