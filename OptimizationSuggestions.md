# Backend Performance & Correctness Review — Gemini Slowness

I reviewed `app/services/gemini_pool.py`, `app/services/gemini_service.py`, `fix_models.py`/`unfix_models.py`, and the endpoints that call them (`meals.py`, `coach.py`, `coaching.py`). Your instinct was right on both counts: the model names are wrong, and the rotation logic is broken. Below is everything, ranked by impact on the "Gemini is slow" symptom.

---

## 🔴 Root Cause #1: The model names in your rotation list don't exist

In `gemini_pool.py`:

```python
priority_models = [
    "gemini-3.5-flash-lite",
    "gemini-3.5-flash",
    "gemini-3.7-flash",
    "gemini-3.6-flash"
]
```

And in `gemini_service.py`, calls use `model='gemini-3.7-flash'` and `model='gemini-3.5-flash-lite'`.

**None of these are real Gemini model IDs.** I checked current Google documentation (as of Aug 2026). The real, valid model IDs are things like:

- `gemini-2.5-flash-lite` (fast, stable, still supported)
- `gemini-2.5-flash`
- `gemini-3-pro-preview` / `gemini-3.1-pro-preview`
- `gemini-3-flash-preview` (the actual current "fast" Gemini 3 model)
- `gemini-3.1-flash-image-preview` (image-specific)

There is no `3.5`, `3.6`, or `3.7` generation — Google went `2.5 → 3 → 3.1`. It looks like someone (or a previous AI pass) invented a fake sequential numbering scheme.

**This is almost certainly why requests feel slow.** When you call the API with an invalid `model` string, Google's SDK doesn't fail instantly — depending on the error, it can take a few seconds to come back with a 404/"model not found." Your rotation logic (see below) then retries that same *wrong* name against **every API key**, then moves to the **next wrong model name** and repeats. With a 30-second client timeout configured (`http_options=types.HttpOptions(timeout=30_000)`), a single user request can end up serially attempting 4 bad model names × N keys before anything succeeds or fails — this alone could add tens of seconds.

**Smoking gun found in your repo:** `fix_models.py` and `unfix_models.py` at the project root. `fix_models.py` does a blind find-and-replace of the string `"gemini-3.6-flash"` → `"gemini-3.7-flash"` across every `.py` file. Neither name is valid — this was a cosmetic swap between two equally-wrong strings, not an actual fix. This is the direct source of the "some model names are wrong" issue.

**Fix:** Replace the model list with real IDs, and pick them by actual purpose (see the "wrong model logic" section below), e.g.:

```python
priority_models = [
    "gemini-2.5-flash-lite",   # fastest, cheapest — text-only tasks
    "gemini-2.5-flash",        # balanced fallback
    "gemini-3-flash-preview",  # higher capability fallback
]
```
Then delete `fix_models.py` / `unfix_models.py` — they're one-off scripts that shouldn't ship in the repo, and they'll cause this exact bug again if anyone reruns them.

---

## 🔴 Root Cause #2: The model-rotation/fallback logic is unsafe and slow by design

In `GeminiPool.generate_content`:

```python
models_to_try = [model] + [m for m in priority_models if m != model]
```

Problems:

1. **It silently falls back to a completely different model for a task that model may not support.** `scan_meal()` sends an *image* and a `response_schema=MealScanResponse` (structured output). If `gemini-3.7-flash` fails, the pool happily retries the exact same image + schema call against `gemini-3.5-flash-lite`, `gemini-3.6-flash`, etc. If any of those don't support vision or your schema, you get a wrong/janky failure a second time, doubling latency instead of failing fast.
2. **No fallback ordering by task type.** The same fixed 4-model list is used for *every* call — image recognition, JSON-array generation, one-line coaching text. A one-paragraph coaching message doesn't need the same fallback chain as a vision-based meal scan.
3. **Worst case is very slow, on purpose.** If a model is rate-limited or times out on every key, the loop tries the next model in the *same request*, synchronously, one after another. In the pathological case (all wrong names) that's up to 4 models × N keys × up to a 30s timeout each — a single request could theoretically hang for minutes before the user sees an error.
4. **Non-transient errors get treated like transient ones.** The final `else` branch (`logger.error(...)`) catches *any* exception that isn't a 429/RESOURCE_EXHAUSTED/timeout — including a plain "model not found" 404 — and disables that key **for the entire day** (`self._quota_status[current_model][key_idx] = False`). This means one bad model name can silently zero out all your keys for that "model" for 24 hours, forcing every request to burn time falling through the whole chain repeatedly.

**Fix:**
- Fail fast on 4xx "invalid argument / not found" errors — don't disable the key, don't retry other keys, just move to the next model immediately (or surface the error).
- Pass task-appropriate fallback chains into `generate_content()` instead of one global list (e.g. a `capabilities={"vision": True}` flag, or just an explicit `fallback_models=[...]` argument per call site).
- Add a max total wall-clock budget per request (e.g. 8–10s) so a user-facing call can never cascade through the whole matrix.

---

## 🟠 Root Cause #3: Blocking, synchronous Gemini calls inside `async def` FastAPI routes

`meals.py`, `coach.py`, and `coaching.py` all do this pattern:

```python
@router.post("/scan")
async def scan_meal(...):
    ...
    scan_result = GeminiService.scan_meal(...)   # <- synchronous, blocking network call
```

`GeminiService.scan_meal` calls `gemini_pool.generate_content`, which uses the **synchronous** `google.genai` client (`client.models.generate_content`, not `client.aio.models.generate_content`). A blocking network call made directly inside an `async def` handler **blocks the entire asyncio event loop** for its full duration (which, per Root Cause #1/#2, can be many seconds to minutes).

**Impact:** while one user's meal scan is waiting on Gemini, *every other request your server is handling* — including totally unrelated ones like `/health` or a different user's profile fetch — stalls too, because there's only one event loop thread. This will look exactly like "everything is slow," especially under any concurrent traffic, even if Gemini itself responds in 1-2s.

Same issue applies to the Supabase calls (`supabase.table(...).execute()`), which use the sync `supabase-py` client inside `async def` routes.

**Fix (pick one):**
- Easiest: wrap each blocking call with `fastapi.concurrency.run_in_threadpool` (or `asyncio.to_thread`):
  ```python
  scan_result = await run_in_threadpool(GeminiService.scan_meal, image_bytes, mime_type, profile)
  ```
- Better long-term: migrate `GeminiPool` to use `genai.Client(...).aio.models.generate_content(...)` (the async client) and make `GeminiService` methods `async def`.

---

## 🟠 A new `genai.Client` is created on every single call

```python
def _get_client(self, index: int) -> genai.Client:
    key = self._keys[index % len(self._keys)]
    return genai.Client(api_key=key, http_options=types.HttpOptions(timeout=30_000))
```

This constructs a brand-new client (and likely a new underlying HTTP connection pool / TLS handshake) on every `generate_content` call, instead of reusing a persistent client per key. Under load this adds avoidable per-request latency and prevents HTTP keep-alive from ever kicking in.

**Fix:** create one `genai.Client` per key **once** (e.g. in `__init__`, stored in a list/dict) and reuse it:
```python
def __init__(self):
    self._keys = settings.get_gemini_keys()
    self._clients = [genai.Client(api_key=k, http_options=types.HttpOptions(timeout=15_000)) for k in self._keys]
    ...

def _get_client(self, index: int) -> genai.Client:
    return self._clients[index % len(self._clients)]
```
Also consider lowering the 30s timeout — 30s is a very long time to let a single attempt hang before failover even starts.

---

## 🟠 N+1 sequential network calls in `/scan`

In `meals.py`, after Gemini returns the list of food items, you do:

```python
for item in scan_result.get("items", []):
    ...
    usda_macros = await UsdaService.fetch_macros_per_100g(item.get("name", ""))
```

Each item's USDA lookup (a separate HTTP call with its own 5s timeout) happens **sequentially**, one after another. A 4-item meal means up to 4× the USDA latency stacked on top of the Gemini call, serially.

**Fix:** run them concurrently:
```python
import asyncio
results = await asyncio.gather(*[
    UsdaService.fetch_macros_per_100g(item.get("name", ""))
    for item in scan_result.get("items", [])
])
```
then zip `results` back onto `scan_result["items"]`.

---

## 🟡 Other things worth fixing for performance/reliability

1. **No caching for repeated/near-duplicate text prompts.** `estimate_food_macros`, `generate_coaching_summary`, `generate_food_swaps`, `generate_grocery_list` all hit Gemini fresh every time, even though many users will log very similar foods ("2 eggs", "chai", "roti"). A simple cache (Redis, or even an in-memory LRU keyed on normalized query text) for `estimate_food_macros` alone would cut a large fraction of Gemini calls and their latency entirely.
2. **`response_mime_type="application/json"` + manual regex JSON cleanup** (`_parse_gemini_json` strips ```` ```json ```` fences) — with `response_mime_type` already set, the model shouldn't be wrapping output in fences, so this is defensive but also a sign the schema/config isn't being fully trusted. Prefer `response_schema` (already used for meal scan) on the other JSON-returning calls too (`evaluate_ingredients`, `generate_food_swaps`, `generate_grocery_list`) — schema-constrained decoding is both faster and more reliable than hoping the model emits clean JSON, and removes a whole class of "malformed JSON" retries.
3. **Daily quota reset is calendar-day based, not rolling.** `_reset_quotas` resets once per process day (`datetime.date.today()`), which is fine, but it also means **a single process restart or a key error right before midnight can look like Gemini is "still down"** to users until the date rolls over, even though quota may have already recovered server-side. Consider a shorter TTL-based cooldown (e.g. disable a key for 60s on 429, not 24h) instead of a full-day ban — actual per-minute quotas usually reset in under a minute, not a day.
4. **CORS `allow_origins=["*"]` with `allow_credentials=True`** — not a latency issue, but worth flagging: browsers reject this combination in practice for credentialed requests, and it's a security smell regardless. Lock this down to your actual frontend origin(s).
5. **No structured concurrency/timeout budget at the endpoint level.** Consider wrapping the whole Gemini call chain in `asyncio.wait_for(..., timeout=X)` at the route level so a worst-case cascade (Root Cause #2) can never make a single HTTP request hang indefinitely from the client's perspective — fail fast and return a clear "AI service busy" error instead.
6. **`fill_macros_and_evaluate`, `identify_barcode_food`, etc. use `gemini-3.5-flash-lite`** (same invalid-name problem as above) — once you fix the model list in `gemini_pool.py`, double check every direct `model='...'` string literal in `gemini_service.py`, since several call sites hardcode model names outside the pool's own list.

---

## Priority order to fix

| Priority | Fix | Why |
|---|---|---|
| 1 | Replace all invalid model IDs (`gemini-3.5-*`, `gemini-3.6-*`, `gemini-3.7-*`) with real ones (`gemini-2.5-flash-lite`, `gemini-2.5-flash`, `gemini-3-flash-preview`) | This is very likely the majority of your latency — bad model names causing failed attempts across the whole rotation matrix |
| 2 | Delete `fix_models.py` / `unfix_models.py`, don't let a script silently rewrite model strings again | Prevents this recurring |
| 3 | Offload blocking Gemini/Supabase calls with `run_in_threadpool` or move to the async `genai` client | Fixes event-loop stalls affecting *all* concurrent users, not just the one waiting on Gemini |
| 4 | Reuse `genai.Client` instances instead of creating one per call | Removes per-request connection setup overhead |
| 5 | Fail fast on non-retryable errors (don't ban a key for a day because of a bad model name) | Stops one bug from cascading into hour-long key bans |
| 6 | Parallelize the USDA lookups in `/scan` with `asyncio.gather` | Cuts N× sequential latency to 1× |
| 7 | Add caching for common `estimate_food_macros` queries | Reduces Gemini call volume entirely for repeat foods |
