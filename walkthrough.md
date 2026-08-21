# Stats and Coaching Timezone Offset Fixes Walkthrough

We have successfully resolved the timezone grouping issue causing the Stats / AI Coaching page logs and 7-day consistency chart to not update when logging food/water:

## What Was Resolved

### 1. Daily Totals Timezone Mismatch Bug (Backend)
- **Problem**: When a user logged meals/water, the timestamps were stored in the database in UTC. The backend habit-score API (`/coaching/habit-score/{user_id}`) grouped meal calories and protein by parsing raw UTC strings directly (e.g. `logged_at[:10]`). 
- Pakistan is in timezone `UTC +05:00`. Meals logged in local time between 12:00 AM and 5:00 AM on August 21 were stored in the database with timestamps between 7:00 PM and 11:59 PM on August 20. 
- Because the backend was grouping by raw UTC string prefixes, it miscategorized all of today's morning logs under yesterday (`2026-08-20` UTC), showing today (`2026-08-21` UTC) as empty and failing to update the habit score or the consistency chart for today.
- **Solution** ([coaching.py](file:///d:/AI%20Hackathon/NutriSense/backend/app/api/v1/endpoints/coaching.py)):
  - Updated the `/habit-score/{user_id}` route to accept a dynamic `offset_minutes` query parameter representing the client's local timezone offset.
  - Parsed `logged_at` timestamps into `datetime` objects and shifted them to the user's local timezone offset using `datetime.timezone(datetime.timedelta(minutes=offset_minutes))`.
  - Grouped and calculated consistency metrics and calorie/protein accuracy by the **user's local day** (e.g., `'2026-08-21'`) rather than the UTC date.

### 2. Frontend Query Synchronization
- **Solution** ([coaching_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/predictive_coaching/coaching_screen.dart)):
  - Updated `_loadCoachingData()` to capture the client's timezone offset:
    ```dart
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    ```
  - Appended `?offset_minutes=$offsetMinutes` as a query parameter to the `habit-score` GET request.

---

## Verification Results

### Automated Verification
- Ran static analysis on the Flutter application:
  ```bash
  flutter analyze
  ```
  **Result**: `No issues found!` (Clean compilation, zero errors/warnings across all files).
- Ran unit tests:
  ```bash
  flutter test
  ```
  **Result**: `All tests passed!` (Successful compile and test execution).
