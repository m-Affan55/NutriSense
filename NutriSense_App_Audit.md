# NutriSense — Code Audit
**Scope:** Flutter frontend (`lib/`) + FastAPI backend (`app/`), reviewed for errors, UX, optimization, and Web + Android deployment readiness.
**Note on scope:** No `android/`, `ios/`, or `web/` platform folders were included in the upload — only `lib/` + `pubspec.yaml`. Manifest/permission/PWA config could not be reviewed; see the note at the end.

---

## 🔴 Critical

### 1. Account deletion doesn't delete anything
`backend/app/api/v1/endpoints/profile.py` → `POST /profile/delete-account`

```python
supabase = get_supabase_admin_client()
# Supabase Python SDK admin deletes user from auth.users   <- comment only, no code
user_cache.invalidate_profile(data.user_id)
user_cache.invalidate_meals(data.user_id)
return {"status": "success", "message": "User account and associated records deleted."}
```
There is no call to `supabase.auth.admin.delete_user()` and no deletion from `health_profiles`, `meal_logs`, `water_logs`, or `risk_flags`. The endpoint only clears an in-memory cache and reports success. Users are told their account and health data were deleted when they still exist in the database.

- This is a functional bug and a compliance risk — both the App Store and Play Store require a working account-deletion path for apps that collect health data, and misrepresenting deletion is a real liability for a clinical-adjacent app.
- **Fix:** actually call `supabase.auth.admin.delete_user(user_id)` and delete/cascade the user's rows from every table before returning success.

### 2. No authentication on any backend endpoint
Checked every router in `app/api/v1/endpoints/` and `app/core/security.py` (the latter is an empty `# TODO` stub) — there is no JWT verification, no `Depends()` auth guard, and no check that the caller owns the `user_id` they send.

- Every endpoint (`meals.py`, `health_profile.py`, `coach.py`, `profile.py`, `coaching.py`) accepts `user_id` as a plain field in the request body/query and trusts it.
- All Supabase calls go through `get_supabase_admin_client()` — the **service-role key**, which bypasses Row Level Security entirely.
- Net effect: anyone who has (or guesses/enumerates) a `user_id` can read another user's health profile and meal history, overwrite their onboarding data, or delete their account via endpoint #1.
- **Fix:** verify the Supabase JWT from the `Authorization` header server-side, derive `user_id` from the verified token (never trust the client-sent one), and switch reads/writes to the anon client so RLS policies apply as a second line of defense.

### 3. AI Coach caches client-supplied medical data as ground truth
`backend/app/api/v1/endpoints/coach.py` → `POST /coach/chat`
```python
if req.client_profile:
    profile = req.client_profile
    user_cache.set_profile(req.user_id, profile)   # overwrites the server cache
```
The Flutter client (`ai_coach_screen.dart`) sends a **partial** profile on every message — only `goal` and `medical_conditions`, no calorie/macro targets:
```dart
if (_goal != null || _medicalConditions.isNotEmpty)
  'client_profile': {
    'goal': _goal,
    'medical_conditions': _medicalConditions,
  },
```
Because the server unconditionally caches whatever the client sends, this partial payload **overwrites the richer profile fetched from Supabase** for every subsequent cache hit, silently reverting `daily_calorie_target`, `daily_protein_g`, `daily_carbs_g`, `daily_fat_g` to hardcoded defaults (2000 kcal / 130g / 220g / 65g) for the rest of the user's session — even for users with customized targets. It also means a compromised or modified client can inject arbitrary "medical conditions" that the AI coach and the risk evaluator will treat as fact.
- **Fix:** never let client-supplied data overwrite the server cache; treat `client_profile` as a display hint at most, and always source medical/nutrition facts from the database.

---

## 🟠 High — specific to your Web + Android release

### 4. Android app icon generation is disabled
`pubspec.yaml`:
```yaml
flutter_launcher_icons:
  android: false
```
Since Android is one of your two target platforms, this needs to be `true` (with an Android-appropriate adaptive icon) before release, or the app ships with the default Flutter icon.

### 5. Secrets are bundled into the client binary
```yaml
assets:
  - assets/
  - .env
```
`.env` (Supabase URL + anon key) is packaged as a Flutter asset, meaning it's extractable from both the compiled APK and the deployed web bundle by anyone (unzip the APK / inspect the web build's asset manifest). The Supabase anon key being public is expected, but shipping it via `.env` this way is also why RLS (see #2) is essential — right now there's neither.

### 6. CORS is misconfigured for a browser client
`backend/app/main.py`:
```python
allow_origins=["*"],
allow_credentials=True,
```
Browsers reject wildcard origins combined with credentials — this combination is invalid per the Fetch/CORS spec. If your Flutter Web build ever sends credentialed requests (cookies, `Authorization` headers with credentials mode), the browser will block them regardless of what the server sends. Since you're deploying to web, replace `allow_origins=["*"]` with your actual deployed origins.

### 7. USDA lookup uses a shared demo key, capped at 30 req/min per IP
`backend/app/services/usda_service.py`:
```python
API_KEY = "DEMO_KEY"  # Limited to 30 requests per IP per minute.
```
Every item Gemini detects in a meal photo triggers a parallel USDA call (`asyncio.gather`). A single busy meal-scan (say, 5 items) already uses 5 of your 30/min budget, shared across **all users hitting your backend from the same egress IP**. This will start silently degrading (falling back to `ai_estimate`/zeros) well before you have meaningful traffic. Register a free USDA API key (not `DEMO_KEY`) before launch.

### 8. Local SQLite barcode cache won't survive typical cloud deployment
`backend/app/services/food_db_service.py` writes resolved barcodes into `backend/data/foods.db` on local disk via `INSERT OR REPLACE`. Most container hosts (Render, Railway, Fly, Cloud Run, etc.) use **ephemeral or read-only filesystems**, and if you ever scale to more than one instance, each replica has its own copy of the file — writes on one instance are invisible to the others, and everything resets on redeploy. This doesn't break anything (it degrades gracefully to the Gemini/OpenFoodFacts fallback), but the "instant offline hit for this barcode on all subsequent scans" caching benefit described in the code comments won't actually materialize in a typical cloud deployment. If this matters, move the cache into the `foods` table's origin location or a Supabase table instead of local disk.

### 9. Platform config wasn't in the upload — can't verify manifest/web setup
No `android/AndroidManifest.xml`, `web/index.html`, `web/manifest.json`, or `ios/Info.plist` were included. Before shipping to web + Android specifically, verify:
- Android: camera (`mobile_scanner`), notification, and Health Connect permissions are declared, `minSdkVersion` is compatible with `health` / `flutter_local_notifications` / `mobile_scanner`.
- Web: `index.html` has a proper title/meta/PWA manifest, and CanvasKit vs HTML renderer is chosen deliberately (the particle background + custom fonts in this app render more reliably under CanvasKit).
- Both: that `sqflite` (mobile/desktop-only, see #10) isn't reached from any code path that can run on web.

---

## 🟡 Medium — bugs

### 10. Post-login and password-reset navigation is dead code
`frontend/lib/main.dart`:
```dart
final _navigatorKey = GlobalKey<NavigatorState>();
...
home: const SplashScreen()  // MaterialApp is actually keyed with `globalNavigatorKey`, not `_navigatorKey`
...
void _initAuthListener() {
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    if (event == AuthChangeEvent.signedIn && session != null) {
      _navigatorKey.currentState?.pushAndRemoveUntil(...)   // _navigatorKey is never attached to any Navigator
```
`MaterialApp` is built with `navigatorKey: globalNavigatorKey`, but the auth-state listener navigates through a completely different, never-attached `_navigatorKey`. `_navigatorKey.currentState` is always `null`, so this block silently does nothing. If sign-in/password-recovery navigation is currently working in your testing, it's because `SplashScreen` (or another screen) happens to handle it independently — this listener itself is inert and should either be fixed (use `globalNavigatorKey`) or removed.

### 11. Meal-photo scanning has no offline fallback (inconsistent with the rest of the app)
The app has a well-built offline-first design for manual meal logging and water logging (`OfflineCache` + `SyncService`, correctly gated behind `kIsWeb` checks). The AI **photo-scan** flow (`scan_meal_screen.dart`) doesn't use it — it inserts directly to Supabase:
```dart
await supabase.from('meal_logs').insert(payload);
```
with no `OfflineCache` fallback. If the connection drops right after a successful (and costly — image upload + Gemini + USDA) scan, the whole result is thrown away and the user sees a raw exception in a toast (`'Failed to save meal: ${e.toString()}'`), with no path to retry saving without rescanning. Route this through the same offline queue used elsewhere.

### 12. No client-side timeout on the most latency-prone request
`scan_meal_screen.dart`'s `_uploadAndScanImage()` (image upload → Gemini vision → parallel USDA lookups) is the slowest network call in the app, and it's the one call in the codebase with no `.timeout(...)`. (`manual_log_screen.dart`, `barcode_scanner_screen.dart`, `ai_coach_screen.dart`, and others all set explicit timeouts.) If this hangs, the user is stuck on the loading screen indefinitely with no way to cancel or retry.

### 13. Raw exception text shown to users in multiple places
`e.toString()` (or the equivalent) is surfaced directly in `CustomToast` in at least the onboarding submit flow, the meal-scan save flow, and the delete-account flow. These will show things like `Exception: SocketException: Failed host lookup` to end users instead of a friendly message ("Couldn't reach the server — check your connection and try again"). Worth centralizing into a single error-message mapper.

### 14. Duplicate/overlapping backend routes
- `GET /reports/weekly` (`reports.py`) and `GET /meals/weekly-report` (`meals.py`) both generate the same weekly report via `ReportService`.
- `router.py` mounts both `health_profile.router` and `profile.router` under the same `/profile` prefix.
These aren't broken, but they're confusing to maintain and easy to accidentally diverge. Consolidate to one canonical path per resource.

### 15. In-memory `UserCache` won't scale past a single backend process
`backend/app/services/user_cache.py` is a genuinely well-built thread-safe LRU cache (bounded, with lazy rehydration and invalidation hooks) — but it's process-local. The moment you run more than one Uvicorn worker or more than one container replica (normal for horizontal scaling on most hosts), each instance has its own independent cache: invalidations on one instance won't clear stale data cached on another, and cache hit rates drop as traffic is spread across instances. Fine for a single-instance deployment; needs Redis (or similar) before scaling out.

### 16. Habit score triggers a synchronous AI call on every load
`GET /coaching/habit-score/{user_id}` (`coaching.py`) calls `GeminiService.generate_coaching_summary` on every single request, with no caching. If this is rendered on a frequently-visited screen (predictive coaching), every view/pull-to-refresh pays for a live Gemini round-trip. Consider caching the summary for a few hours or regenerating it only when the underlying meal data actually changes.

### 17. Dashboard reloads block the whole screen with a spinner on every minor update
`dashboard_screen.dart`'s `_loadData()` is wired up as a listener on both `FamilyViewModel` and `MealSyncNotifier`, and the very first thing it does is `setState(() => _isLoading = true)`, which the `build()` method uses to swap the **entire scrollable dashboard** for a bare `CircularProgressIndicator()`:
```dart
_isLoading
  ? const Center(child: CircularProgressIndicator())
  : RefreshIndicator(...)
```
Since `_loadData` fires after logging water, logging a meal, switching family member, etc., the whole dashboard blanks out and rebuilds from scratch for what should be a quick, subtle background refresh — jarring on every interaction, and worse on a slower web/mobile connection. Keep the existing content visible and use a small inline refresh indicator instead of tearing down the whole tree.

### 18. Dashboard fetches profile, meals, and water sequentially instead of in parallel
Still in `_loadData()`: the profile query, meal-logs query, and water-logs query are each `await`-ed one after another. Since none of them depend on each other's result, wrapping them in `Future.wait([...])` would cut dashboard load latency by roughly a third with no behavior change.

### 19. Backend URL is a hardcoded compile-time constant
`frontend/lib/core/api_client.dart`:
```dart
static const bool useLocalBackend = false;
static const String _liveBackendUrl = 'https://nutrisense-backend-v1.onrender.com/api/v1';
static const String _localBackendUrl = 'http://127.0.0.1:8000/api/v1';
```
Switching environments (local/staging/prod) requires editing source and rebuilding, rather than using `--dart-define` or per-flavor config. Low risk of accidentally shipping `useLocalBackend = true`, but worth moving to build-time config, especially once you have separate web and Android release pipelines that may need to point at different backends during testing.

---

## 🟢 Lower priority — cleanup & architecture

### 20. ~32 files are unimplemented `// TODO` stubs, and the intended architecture was abandoned
Every file below is a single-line placeholder comment with no code:
```
frontend/lib/data/**  (all models, repositories, services)
frontend/lib/domain/models/**  (all)
frontend/lib/ui/features/{auth,settings,onboarding,subscription,predictive_coaching,notifications}/**viewmodel.dart
frontend/lib/shared/services/{logger_service,local_storage_service}.dart
frontend/lib/ui/core/constants.dart
backend/app/schemas/{chat,report,user}.py
backend/app/api/v1/endpoints/auth.py
backend/app/models/db_models.py
backend/app/core/{database,security}.py
```
The app clearly started with a clean layered architecture (data/domain/repository/viewmodel separation on the frontend; schemas/models/security on the backend) and then abandoned it — all the real logic instead lives directly inside massive screen `State` classes (`dashboard_screen.dart` 1833 lines, `ai_coach_screen.dart` 1411 lines, `settings_view.dart` 1280 lines, `manual_log_screen.dart` 1399 lines). This isn't a bug by itself, but it's the root cause of several issues above (no `security.py` → no auth; no `user.py`/`chat.py` schemas → unvalidated request shapes in places; huge screen files → hard to test, hard to reuse logic). Worth either deleting the dead scaffolding or actually migrating logic into it — right now it signals an intended design the code doesn't follow.

### 21. Dead file: `onboarding_chat_backup.dart`
318 lines, not imported anywhere in the codebase (confirmed via full-project search). Safe to delete or move out of `lib/`.

### 22. Perpetual full-screen particle animation ticks every frame regardless of visibility
`animated_particles_background.dart` runs a `Ticker` calling `setState`-equivalent (`ValueNotifier` increment) on every animation frame indefinitely once started, with `shouldRepaint` hardcoded to `true` on the `CustomPainter` — meaning it repaints every frame forever, even if the widget is scrolled off-screen or the app is backgrounded (no visibility/lifecycle pause). It's only used on the language-selection screen currently, so impact is limited, but if it's reused on more screens later, watch battery/CPU usage, especially on lower-end Android devices and on web.

---

## Summary — before you ship to Web + Android

**Must fix:**
1. Implement real account deletion (#1)
2. Add backend authentication + stop trusting client-sent `user_id` (#2)
3. Stop letting `client_profile` overwrite the server-side cache (#3)
4. Enable Android icon generation (#4)
5. Fix CORS for your real origins (#6)

**Should fix before real users hit it:**
6. Replace the USDA `DEMO_KEY` (#7)
7. Add the account-deletion fix's data cascade + review platform manifests once available (#9)
8. Route meal-photo scans through the offline queue and add a timeout (#11, #12)

**Worth doing, lower urgency:** everything under Medium/Lower priority above — mostly about robustness and maintainability rather than launch blockers.
