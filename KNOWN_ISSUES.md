# Known Issues & Required Fixes

## 1. Duplicate Sync Risk (Offline Mode)

**Severity:** High
**Component:** `SyncService` (Frontend) & Supabase Schema

### The Bug
When a user logs a meal while offline, the app caches it in a local SQLite database (`pending_meal_logs`) with `synced = 0`. When the internet connection is restored, `SyncService` attempts to upload this row to Supabase. 

If the app successfully POSTs the meal to Supabase, but the app is killed by the OS or crashes *before* it can update the local SQLite row to `synced = 1`, the next time the app opens, it will attempt to upload the exact same meal again. 

Because Supabase has no idempotency key or unique constraint linking the local meal to the remote meal, it will blindly accept the duplicate, doubling the user's calories.

### The Required Fix (Idempotency)
To fix this, you must implement an idempotency key:
1. **Frontend:** Add the `uuid` package to `pubspec.yaml`. Update `offline_cache.dart` to generate a `Uuid().v4()` string for every new offline row, storing it in a new column `sync_id TEXT PRIMARY KEY`.
2. **Backend/Supabase:** Add a `sync_id UUID UNIQUE` column to the `meal_logs` and `water_logs` tables in Supabase.
3. **Sync Logic:** When `SyncService` uploads a meal, it must include the `sync_id`. If Supabase throws a Postgres `23505` (Unique Violation) error, it means the meal was already uploaded successfully in the past. `SyncService` should catch this error, ignore it, and safely mark the local row as `synced = 1`.

*Note: Modifying the local SQLite schema will require upgrading the database version and potentially wiping existing pending logs, so this must be handled carefully in production.*

---

## 2. Health Connect Permission Race Condition

**Severity:** Low
**Component:** `HealthService` (Frontend)

### The Bug
The `health_service.dart` caches the permission state in an in-memory boolean `_authorized`. If a user goes into the Android OS Settings and manually revokes Health Connect permissions while the app is backgrounded, `_authorized` remains `true` in memory.

When the app resumes, it attempts to fetch step counts without requesting permissions, leading to a silent native crash or empty data being returned, causing the dashboard to render 0 active calories without telling the user why.

### The Required Fix
Remove the in-memory `_authorized` cache or verify permissions via `Health().hasPermissions()` every time the app resumes from the background using the `WidgetsBindingObserver` lifecycle hooks.
