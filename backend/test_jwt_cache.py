"""
Test suite for the JWT validation cache (Fix 4).

Covers the full lifecycle of app.core.security.JwtCache and the
get_current_user_id FastAPI dependency:
  - first validation -> Supabase round-trip -> cached
  - subsequent calls -> instant cache hit, zero network
  - token without 'exp' claim -> never cached (safe fallback)
  - malformed token -> never cached, falls through to Supabase
  - near-expiry token -> refused by cache (margin respected)
  - long-lived token -> bounded to MAX_CACHE_SECONDS window
  - expired entry -> evicted lazily on get()
  - LRU eviction at MAX_ENTRIES
  - 401 propagation for None user / generic Supabase errors
  - cached token survives a Supabase outage (resilience)
  - per-token isolation (no cross-user contamination)
  - concurrency: same token hammered from many threads
  - concurrency: cache internals safe under parallel set/get

Run from the backend directory:
    venv\\Scripts\\python.exe test_jwt_cache.py -v
"""

import base64
import json
import sys
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
from unittest import mock
from pathlib import Path

# Ensure the backend root is importable regardless of cwd
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi import HTTPException

from app.core import security
from app.core.security import JwtCache, jwt_cache


def make_jwt(payload: dict) -> str:
    """Build a structurally valid (unsigned) JWT for testing."""
    def b64(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

    header = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    body = b64(json.dumps(payload).encode())
    return f"{header}.{body}.fakesignature"


def creds(token: str):
    """Minimal stand-in for HTTPAuthorizationCredentials."""
    return SimpleNamespace(credentials=token)


def make_user(user_id: str):
    """Fake Supabase UserResponse shaped object."""
    return SimpleNamespace(user=SimpleNamespace(id=user_id))


def mock_supabase(user_id=None, exc=None, none_response=False):
    """Patch get_supabase_admin_client with a scripted auth.get_user."""
    def side_effect(token):
        if exc is not None:
            raise exc
        if none_response:
            return None
        return make_user(user_id)

    client = SimpleNamespace(auth=SimpleNamespace(get_user=mock.Mock(side_effect=side_effect)))
    patcher = mock.patch.object(security, "get_supabase_admin_client", return_value=client)
    patcher.start()
    return client.auth.get_user  # exposes call_count for assertions


class JwtCacheBaseTest(unittest.TestCase):
    def setUp(self):
        jwt_cache._entries.clear()

    def tearDown(self):
        jwt_cache._entries.clear()
        mock.patch.stopall()


class TestBasicValidationFlow(JwtCacheBaseTest):
    def test_first_call_validates_and_caches(self):
        token = make_jwt({"sub": "u1", "exp": int(time.time()) + 3600})
        get_user_mock = mock_supabase(user_id="user-123")

        result = security.get_current_user_id(creds(token))

        self.assertEqual(result, "user-123")
        self.assertEqual(get_user_mock.call_count, 1)
        self.assertIn(token, jwt_cache._entries)

    def test_second_call_hits_cache_without_network(self):
        token = make_jwt({"sub": "u1", "exp": int(time.time()) + 3600})
        get_user_mock = mock_supabase(user_id="user-123")

        first = security.get_current_user_id(creds(token))
        second = security.get_current_user_id(creds(token))

        self.assertEqual(first, "user-123")
        self.assertEqual(second, "user-123")
        self.assertEqual(get_user_mock.call_count, 1, "Second call must not hit Supabase")

    def test_cache_hit_isolated_per_token(self):
        token_a = make_jwt({"sub": "ua", "exp": int(time.time()) + 3600})
        token_b = make_jwt({"sub": "ub", "exp": int(time.time()) + 3600})

        def side_effect(token):
            return make_user("user-A" if token == token_a else "user-B")

        client = SimpleNamespace(auth=SimpleNamespace(get_user=mock.Mock(side_effect=side_effect)))
        with mock.patch.object(security, "get_supabase_admin_client", return_value=client):
            result_a = security.get_current_user_id(creds(token_a))
            result_b = security.get_current_user_id(creds(token_b))

        self.assertEqual(result_a, "user-A")
        self.assertEqual(result_b, "user-B")
        # Cross-check: hitting A again must not return B's user
        with mock.patch.object(security, "get_supabase_admin_client", return_value=client):
            self.assertEqual(security.get_current_user_id(creds(token_a)), "user-A")


class TestUncachedFallbacks(JwtCacheBaseTest):
    def test_token_without_exp_claim_is_not_cached(self):
        token = make_jwt({"sub": "u2"})  # no 'exp'
        get_user_mock = mock_supabase(user_id="user-noexp")

        first = security.get_current_user_id(creds(token))
        second = security.get_current_user_id(creds(token))

        self.assertEqual(first, "user-noexp")
        self.assertEqual(second, "user-noexp")
        self.assertNotIn(token, jwt_cache._entries)
        self.assertEqual(get_user_mock.call_count, 2, "Token without exp must re-validate each time")

    def test_malformed_token_not_cached_and_401(self):
        token = "not-a-real-jwt"
        get_user_mock = mock_supabase(exc=RuntimeError("invalid JWT"))

        with self.assertRaises(HTTPException) as ctx:
            security.get_current_user_id(creds(token))
        self.assertEqual(ctx.exception.status_code, 401)
        self.assertIn("invalid JWT", ctx.exception.detail)
        self.assertNotIn(token, jwt_cache._entries)

        with self.assertRaises(HTTPException):
            security.get_current_user_id(creds(token))
        self.assertEqual(get_user_mock.call_count, 2)

    def test_none_user_response_raises_401_clean(self):
        token = make_jwt({"sub": "u3", "exp": int(time.time()) + 3600})
        mock_supabase(none_response=True)

        with self.assertRaises(HTTPException) as ctx:
            security.get_current_user_id(creds(token))

        self.assertEqual(ctx.exception.status_code, 401)
        self.assertEqual(ctx.exception.detail, "Invalid authentication token")
        self.assertNotIn(token, jwt_cache._entries, "Failed validations must never be cached")

    def test_generic_supabase_error_raises_401(self):
        token = make_jwt({"sub": "u4", "exp": int(time.time()) + 3600})
        mock_supabase(exc=RuntimeError("boom: service down"))

        with self.assertRaises(HTTPException) as ctx:
            security.get_current_user_id(creds(token))

        self.assertEqual(ctx.exception.status_code, 401)
        self.assertIn("boom", ctx.exception.detail)
        self.assertNotIn(token, jwt_cache._entries)

    def test_cached_token_survives_supabase_outage(self):
        token = make_jwt({"sub": "u5", "exp": int(time.time()) + 3600})
        get_user_mock = mock_supabase(user_id="user-resilient")

        self.assertEqual(security.get_current_user_id(creds(token)), "user-resilient")

        # Supabase now goes down entirely
        get_user_mock.side_effect = RuntimeError("network down")

        self.assertEqual(security.get_current_user_id(creds(token)), "user-resilient")
        self.assertEqual(get_user_mock.call_count, 1, "Cached token must not touch Supabase")


class TestTtlAndExpiry(JwtCacheBaseTest):
    def test_near_expiry_token_is_not_cached(self):
        # exp is only 30s away -> inside the 60s EXP_MARGIN -> refuse caching
        token = make_jwt({"sub": "u6", "exp": int(time.time()) + 30})
        get_user_mock = mock_supabase(user_id="user-near-exp")

        security.get_current_user_id(creds(token))
        self.assertNotIn(token, jwt_cache._entries)

        security.get_current_user_id(creds(token))
        self.assertEqual(get_user_mock.call_count, 2)

    def test_exp_margin_boundary_token_is_cached(self):
        # exp is 61s away -> just outside the 60s margin -> cached for ~1s
        token = make_jwt({"sub": "u7", "exp": int(time.time()) + 61})
        mock_supabase(user_id="user-boundary")

        security.get_current_user_id(creds(token))
        self.assertIn(token, jwt_cache._entries)

    def test_long_lived_token_capped_at_max_window(self):
        token = make_jwt({"sub": "u8", "exp": int(time.time()) + 86400})
        mock_supabase(user_id="user-long")

        security.get_current_user_id(creds(token))

        _, cached_until = jwt_cache._entries[token]
        remaining = cached_until - time.time()
        self.assertGreater(remaining, JwtCache.MAX_CACHE_SECONDS - 5)
        self.assertLessEqual(remaining, JwtCache.MAX_CACHE_SECONDS + 1)

    def test_expired_entry_removed_on_get(self):
        token = make_jwt({"sub": "u9", "exp": int(time.time()) + 3600})
        jwt_cache._entries[token] = ("user-stale", time.time() - 1)  # already expired

        self.assertIsNone(jwt_cache.get(token))
        self.assertNotIn(token, jwt_cache._entries)

    def test_missing_entry_returns_none(self):
        self.assertIsNone(jwt_cache.get("never-seen-token"))


class TestLruEviction(JwtCacheBaseTest):
    def test_lru_eviction_at_max_entries(self):
        with mock.patch.object(JwtCache, "MAX_ENTRIES", 3):
            tokens = []
            for i in range(4):
                token = make_jwt({"sub": f"u{i}", "exp": int(time.time()) + 3600})
                jwt_cache.set(token, f"user-{i}")
                tokens.append(token)

            self.assertEqual(len(jwt_cache._entries), 3)
            self.assertNotIn(tokens[0], jwt_cache._entries, "Oldest entry must be evicted")
            for t in tokens[1:]:
                self.assertIn(t, jwt_cache._entries)

    def test_lru_touch_moves_to_end(self):
        with mock.patch.object(JwtCache, "MAX_ENTRIES", 3):
            tokens = [make_jwt({"sub": f"u{i}", "exp": int(time.time()) + 3600}) for i in range(3)]
            for i, t in enumerate(tokens):
                jwt_cache.set(t, f"user-{i}")

            # Touch the oldest -> moves to MRU position
            jwt_cache.get(tokens[0])

            # Adding a 4th token evicts the next-oldest, not the touched one
            token_new = make_jwt({"sub": "u9", "exp": int(time.time()) + 3600})
            jwt_cache.set(token_new, "user-9")

            self.assertIn(tokens[0], jwt_cache._entries)
            self.assertNotIn(tokens[1], jwt_cache._entries)


class TestDecodeExpEdgeCases(JwtCacheBaseTest):
    def test_decode_various_malformed_inputs(self):
        self.assertIsNone(jwt_cache._decode_exp("abc"))                      # no dots
        self.assertIsNone(jwt_cache._decode_exp("a.b.c"))                    # invalid b64 payload
        self.assertIsNone(jwt_cache._decode_exp("a.b"))                      # two segments only
        self.assertIsNone(jwt_cache._decode_exp(""))                         # empty token

    def test_decode_non_int_exp(self):
        token = make_jwt({"exp": "not-a-number"})
        self.assertIsNone(jwt_cache._decode_exp(token))

    def test_decode_zero_or_missing_exp(self):
        self.assertIsNone(jwt_cache._decode_exp(make_jwt({"exp": 0})))
        self.assertIsNone(jwt_cache._decode_exp(make_jwt({})))

    def test_decode_valid_exp(self):
        exp = int(time.time()) + 500
        self.assertEqual(jwt_cache._decode_exp(make_jwt({"exp": exp})), exp)

    def test_decode_unpadded_base64_payload(self):
        # JWT payloads commonly lose '=' padding on the wire
        token = make_jwt({"sub": "u10", "exp": int(time.time()) + 3600})
        # Force-remove padding from the middle segment to simulate real-world JWTs
        header, body, sig = token.split(".")
        unpadded = f"{header}.{body.rstrip('=')}.{sig}"
        self.assertEqual(jwt_cache._decode_exp(unpadded), jwt_cache._decode_exp(token))


class TestConcurrency(JwtCacheBaseTest):
    def test_same_token_hammered_from_many_threads(self):
        token = make_jwt({"sub": "u11", "exp": int(time.time()) + 3600})
        get_user_mock = mock_supabase(user_id="user-threads")
        num_threads = 20

        with ThreadPoolExecutor(max_workers=num_threads) as pool:
            results = list(pool.map(lambda _: security.get_current_user_id(creds(token)), range(num_threads)))

        self.assertTrue(all(r == "user-threads" for r in results))
        self.assertLessEqual(get_user_mock.call_count, num_threads)

        # Deterministic: after all threads finish, the token IS cached
        calls_before = get_user_mock.call_count
        self.assertEqual(security.get_current_user_id(creds(token)), "user-threads")
        self.assertEqual(get_user_mock.call_count, calls_before)

    def test_parallel_set_get_thread_safety(self):
        entries_per_thread = 50
        num_threads = 10

        def worker(thread_id: int):
            for i in range(entries_per_thread):
                token = make_jwt({"sub": f"t{thread_id}-{i}", "exp": int(time.time()) + 3600})
                user = f"user-{thread_id}-{i}"
                jwt_cache.set(token, user)
                self.assertEqual(jwt_cache.get(token), user)

        with ThreadPoolExecutor(max_workers=num_threads) as pool:
            list(pool.map(worker, range(num_threads)))

        self.assertLessEqual(len(jwt_cache._entries), JwtCache.MAX_ENTRIES)

    def test_singleton_identity(self):
        self.assertIs(JwtCache.get_instance(), jwt_cache)
        self.assertIs(JwtCache.get_instance(), JwtCache.get_instance())


if __name__ == "__main__":
    unittest.main(verbosity=2)
