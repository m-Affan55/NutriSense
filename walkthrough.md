# NutriSense — Comprehensive Implementation Walkthrough

This document outlines all feature implementations, architectural additions, and verification steps across the NutriSense platform.

---

## 👨‍👩‍👧‍👦 1. Family Profiles (خاندانی پروفائلز)
* **Supabase Migration ([002_family_profiles.sql](file:///d:/AI%20Hackathon/NutriSense/supabase/migrations/002_family_profiles.sql))**:
  - `public.family_members` table with age, gender, relationships (`child`, `parent`, `spouse`, `sibling`, `other`), medical conditions, dietary restrictions, and custom macro targets.
  - `family_member_id` foreign key added to `public.meal_logs`.
* **State Management ([family_viewmodel.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/family_profiles/family_viewmodel.dart) & [family_member.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/data/models/family_member.dart))**:
  - Reactive singleton managing dependents with auto-calculation of child vs. elderly macro targets and zero-latency offline caching.
* **Family Management Screen ([family_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/family_profiles/family_view.dart))**:
  - Add/edit bottom-sheet modal with condition chips, relationship badges, and macro suggestions.
  - Edit & delete actions with confirmation dialogs.
* **1-Tap Dashboard Switcher Bar ([dashboard_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/dashboard/dashboard_screen.dart))**:
  - Top avatar pill bar (`[🧑 Me] [👧 Ayesha] [👴 Abu] [+ Family]`).
  - Dynamically switches calorie rings, macro targets, and filtered meal logs.
* **Per-Dependent Meal Logging ([manual_log_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/manual_log_screen.dart) & [scan_meal_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/scan_meal_screen.dart))**:
  - Allows assigning meals to any family member or the primary user.

---

## 🔔 2. Smarter Notification System
* **Adaptive Meal Timing Engine ([reminder_manager.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/reminder_manager.dart))**:
  - Learns the user's actual eating routine via exponential smoothing and schedules personalized reminder prompts.
* **Streak Milestone Celebrations & Evening Streak Saver ([reminder_manager.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/reminder_manager.dart))**:
  - Fires celebration notifications on 3, 5, 7, 10, 14, 30 days.
  - Evening Streak Saver scheduled daily at 8:30 PM to remind users before midnight.
* **AI Clinical Safety & Risk Alerts ([reminder_manager.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/reminder_manager.dart) & [ai_coach_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart))**:
  - Dispatches high-priority system alerts when Gemini detects dangerous metabolic patterns.
* **Ramadan Fasting Alarms ([reminder_manager.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/reminder_manager.dart))**:
  - Sehri countdown (30 min prior), Iftar sunset alert, and night hydration reminders.
* **Interactive Settings Hub ([settings_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart))**:
  - Dedicated toggles for adaptive reminders, streaks, clinical alerts, and Ramadan alarms.

---

## 📊 3. Backend Report Service & PDF Weekly Report
* **FastAPI Backend Service ([report_service.py](file:///d:/AI%20Hackathon/NutriSense/backend/app/services/report_service.py) & [reports.py](file:///d:/AI%20Hackathon/NutriSense/backend/app/api/v1/endpoints/reports.py))**:
  - Aggregates 7-day adherence, computes health score (0–100), and generates clinical narrative via Gemini.
  - Pure-Python zero-dependency PDF 1.4 binary stream generator serving `GET /api/v1/reports/weekly/pdf`.
* **Frontend Weekly Report Screen ([weekly_report_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/weekly_report/weekly_report_screen.dart))**:
  - Interactive 7-day macro charts, narrative review, and 1-tap download saving to device `Downloads` directory.

---

## 🌙 4. Ramadan Fasting Suite
* **Dynamic Ramadan Mode ([ramadan_controller.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/ramadan_controller.dart))**:
  - Automatic Hijri calculation + manual toggle in Settings.
  - Dynamic meal keys: *Sehri*, *Iftar*, *Post-Iftar Dinner*, and *Taraweeh Snack*.
  - Live Sehri & Iftar countdown clocks and specialized Ramadan hydration split tracker.
  - Fasting-specialized AI Coach quick prompt chips.

---

## 📱 5. Health Sync Dashboard (Cross-Platform)
* **Activity Telemetry ([health_service.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/health_service.dart) & [health_sync_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/health_sync/health_sync_view.dart))**:
  - Ingests daily steps, active burn, sleep duration, and heart rate.
  - Supports Android (Health Connect), iOS (Apple Health), and Windows/Web (simulated telemetry).

---

## 🛡️ 6. AI Coach (Gemini) Reliability & Safety Guard (Category 4)
* **Non-Contradictory Advice (Issue 14)**:
  - Added safety disclaimer enforcement logic to the Uvicorn FastAPI backend in [`coach.py`](file:///d:/AI%20Hackathon/NutriSense/backend/app/api/v1/endpoints/coach.py).
  - If the risk evaluator triggers a clinical escalation at `warning` or `critical` level, the backend automatically appends the disclaimer notice to the coach chat bubble, eliminating contradiction.
* **Conversational History Safety Context Persistence (Issue 15)**:
  - Increased active history window to last 20 messages in [`ai_coach_screen.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart).
  - Built a frontend **Safety History Context Scanner** that inspects older conversation histories that get truncated/discarded for any clinical triggers (e.g. glucose readings <70 mg/dL or >=250 mg/dL, or symptoms like dizziness/fainting/unconsciousness/breathlessness).
  - Compiles the extracted triggers and prepends them as a system reminder prompt header directly inside the current message payload, ensuring context is never lost across long chats.

---

## 🎙️ 7. Voice Assistant Integration & Optimization (Category 5)
* **Concurrent Voice Request Guard (Issue 17)**:
  - Added an active request typing guard `if (_isTyping) return;` at the beginning of `_startListening()` in [`ai_coach_screen.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart).
  - This prevents the assistant from listening and recording new user utterances while the coach is still processing or speaking, blocking duplicate queries or voice-loop state confusion.
* **Safe Desktop Fallback try-catch (Issue 18)**:
  - Wrapped native status check and request permissions calls in [`ai_coach_screen.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart) in a platform-safe `try-catch` block.
  - On unsupported desktop platforms (like Windows/Linux), catches the expected platform errors and bypasses permission dialogs gracefully to continue speech initialization instead of crashing the app.
* **Utterance Interruption sync (Issue 19)**:
  - Audited and verified that [`TtsService.stop()`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/tts_service.dart) increments the monotonic token `_utterance++` to invalidate slow/in-flight network syntheses, stops the local `AudioPlayer`, and stops `FlutterTts`. This prevents playback overlaps and cuts off older utterances cleanly.

---

## 🌐 8. Web-Compatibility & Vercel Readiness
* **Conditional Desktop Setup (Deep Linking & Registry)**:
  - Created [`platform_setup.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/platform_setup.dart), [`platform_setup_stub.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/platform_setup_stub.dart), and [`platform_setup_windows.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/platform_setup_windows.dart).
  - Quarantined Windows-only dependencies (`win32_registry` and `sqflite_common_ffi`) so they are conditionally imported only on non-web compilation targets, eliminating all web build-time FFI errors.
* **Safe Platform Detections**:
  - Removed `dart:io` references and replaced `Platform` checks with `defaultTargetPlatform` (from `flutter/foundation.dart`) inside [`health_service.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/health_service.dart), [`reminder_manager.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/reminder_manager.dart), [`tts_service.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/tts_service.dart), and [`onboarding_view.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/onboarding/onboarding_view.dart).
* **Multi-Platform Image Scanning**:
  - Replaced native `File` checks in [`scan_meal_screen.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/scan_meal_screen.dart) with web-safe `XFile` and `MultipartFile.fromBytes` image upload buffers. Utilizes `Image.network` for web previews (using Blob URLs) and `Image.file` for mobile preview support.
* **Web-Safe File Handlers**:
  - Replaced `dart:io` imports with `universal_io` inside [`settings_view.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart) and [`weekly_report_screen.dart`](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/weekly_report/weekly_report_screen.dart), making file storage compilation fully compatible with browser platforms.

---

## 🧪 9. Verification Results

- **Flutter Static Analysis**:
  ```bash
  cd frontend && flutter analyze
  ```
  **Output**: `No issues found!` (0 errors, 0 warnings).

- **Automated Test Suite**:
  ```bash
  cd frontend && flutter test
  ```
  **Output**: `All tests passed!`.
