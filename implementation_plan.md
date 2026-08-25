# Implementation Plan: Ramadan Mode & System Robustness

This document outlines the design and implementation specifications for both the **Ramadan Mode Transformation Suite** and the **System Robustness & Safety Enhancements** (covering Categories 1, 2, 3, and 11).

---

## Part 1: Ramadan Mode (Completed)

Transforms the application into a midnight-blue celestial theme with golden accents, an interactive fasting countdown tracker, Ramadan-adjusted meal categories, and fasting-sensitive AI coaching prompts.

### Proposed Changes (Completed)
* **Core Controller (`ramadan_controller.dart`)**: Singleton managing active state, local timezone event calculations (Sehri/Iftar), and `SharedPreferences` persistence.
* **Vector Shaders & Painters (`islamic_decorations.dart`)**: Render moon, stars, lanterns, and arabesque geometric patterns dynamically using Flutter's custom painter canvas.
* **Dashboard adaptation**: Switches meal slots to *Sehri*, *Iftar*, *Post-Iftar*, and *Taraweeh Snack*, displaying real-time countdown clocks.
* **Ramadan AI Prompt Tuning**: Adapts context instructions to guide users on balanced fasting nutrition and safe hydration.

---

## Part 2: System Robustness & Safety (Completed)

Enhances the backend/frontend logic for Network Failures (Category 1), Input Validation (Category 2), Safety/Clinical Escalation (Category 3), and Settings Bound Rules (Category 11).

### Proposed Changes (Completed)

### 🤖 1. API Resilience & Key Rotation
#### [MODIFY] [gemini_pool.py](file:///d:/AI%20Hackathon/NutriSense/backend/app/services/gemini_pool.py)
* **Stateful Daily Quotas**: Added a `_quota_status` mapping. API keys that return `429 Rate Limit Exceeded` are statefully disabled (`False`) for that specific model for the rest of the day.
* **Daily Reset**: Checks date on every request and resets keys back to `True` when a new day starts.
* **Optimized Cascade Sequence**: Prioritizes `"gemini-3.5-flash-lite"` first (delivering responses in ~1.8s) to bypass the daily 20 RPD cap on `3.7-flash` and `3.6-flash`.
* **Instant Outage Skipping**: If a key returns a `504/503/timeout` error, the pool instantly breaks the loop for that model and proceeds to the next model family, avoiding connection hangs.
* **Backend Timeout**: Reduced to **30 seconds** (`timeout=30_000`) for standard request boundaries.

#### [MODIFY] [ai_coach_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart) & [manual_log_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/manual_log_screen.dart)
* **Frontend Timeout**: Increased to **60–90 seconds** to tolerate multi-model and multi-key failover cycles on the backend.

---

### 🛡️ 2. Clinical Safety & Clinic Locator Fallback
#### [MODIFY] [risk_evaluator.py](file:///d:/AI%20Hackathon/NutriSense/backend/app/services/risk_evaluator.py)
* **Hypoglycemia Detection**: Integrated re-check keyword scanner and a float-matching regex patterns to detect blood sugar levels under `70 mg/dL` (e.g., *"sugar level: 55"*), triggering immediate clinical alerts.
* **Outage Safety net**: Falls back to warning alerts for diabetic profiles if the API is entirely down.

#### [MODIFY] [ai_coach_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart)
* **Blocking Dialog**: Overlays the screen with a persistent, non-dismissible safety alert if metabolic risk is critical, containing a direct clinical finder shortcut.

#### [MODIFY] [clinic_finder_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/clinic_finder_screen.dart)
* **Online/Offline Maps Intent**: Captures location or API search errors and renders a warning card with an interactive button to launch a local browser search (`hospital near me`) using Google Maps deep-links.

---

### ✏️ 3. Input Validation & Toast Sanitization
#### [MODIFY] [settings_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart)
* **Strict Range Checks**: Enforces input validations for Age (1–120), Weight (10–400 kg), Height (50–280 cm), and Budget (0–1,000,000 PKR).
* **Sanitized Alerts**: Intercepts raw backend database exception messages (`e.toString()`) and replaces them with clean, localized, user-friendly toast alerts.

---

## Verification Plan

### Automated Tests
* Run Flutter static check:
  ```bash
  flutter analyze
  ```
  *(Result: No issues found!)*
* Run Flutter unit tests:
  ```bash
  flutter test
  ```
  *(Result: All tests passed!)*

### Manual Verification
* Run latency speed tests for the GeminiPool rotation, verifying it drops to under 2 seconds.
* Enter invalid age bounds in settings to verify validation blocks save requests.
* Submit high-risk sugar readings in the chat and confirm the critical warning popup appears.
