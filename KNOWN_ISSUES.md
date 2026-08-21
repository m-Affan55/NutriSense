# Resolved & Monitored Issues

This document tracks previous technical challenges, architectural resolutions, and runtime considerations for the NutriSense platform.

---

## 🟢 Resolved Issues

### 1. Duplicate Sync Risk (Offline Mode) — RESOLVED
* **Previous Risk**: If the app successfully POSTed offline meal logs to Supabase but crashed before updating the local SQLite row to `synced = 1`, restarting the app could upload duplicate logs, doubling macro calculations.
* **Resolution Implemented**:
  1. Integrated the `uuid` package and generated a unique UUID v4 `sync_id` for every offline meal and water log in `OfflineCache` (`nutrisense_offline.db`).
  2. Added `sync_id UUID UNIQUE` columns to `public.meal_logs` and `public.water_logs` in Supabase.
  3. Upgraded `SyncService` to pass `sync_id`. If Supabase throws a Postgres `23505` (Unique Violation), the sync engine catches it and marks the local row as `synced = 1` safely, ensuring 100% idempotency.

### 2. Cross-Platform Health Sync Graceful Fallback — RESOLVED
* **Previous Risk**: Platform-specific health APIs (Health Connect on Android / Apple Health on iOS) caused crashes or unhandled exceptions when running on Windows Desktop or Web.
* **Resolution Implemented**:
  1. `HealthService` and `HealthSyncView` perform safe runtime checks (`kIsWeb`, `Platform.isAndroid`, `Platform.isIOS`, `Platform.isWindows`).
  2. Windows Desktop and Web gracefully supply real-time simulated telemetry (steps, active calories, sleep, heart rate), while Android/iOS connect to native health data stores.

### 3. Backend Weekly Report & PDF Generation — RESOLVED
* **Previous State**: Frontend called backend `/reports/weekly` endpoints which were previously stubs.
* **Resolution Implemented**:
  1. Fully implemented `ReportService.generate_weekly_report()` with 7-day adherence aggregation, Gemini narrative analysis, and health scoring.
  2. Implemented a zero-dependency pure-Python PDF 1.4 binary generator in `ReportService._build_pdf_stream()` serving downloadable PDF streams directly via `GET /api/v1/reports/weekly/pdf`.

---

## 🔍 Runtime Recommendations & Considerations

1. **Supabase Schema Provisioning**:
   - Ensure both `supabase/schema.sql` and `supabase/migrations/002_family_profiles.sql` have been executed in your Supabase project to ensure all tables (`family_members`, `meal_logs.family_member_id`) are active.
2. **Local Notification Permissions on Mobile**:
   - On Android 13+ and iOS, user must grant notification permissions on first prompt to receive adaptive reminders and streak alerts. Desktop and Web gracefully suppress system notification daemon calls.
