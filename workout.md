# Walkthrough: AI Personalized Workout Plan & Smart Reminders

## Overview
We have implemented the **AI-Powered Personalized Workout Recommendation & Execution System** in NutriSense. The system generates clinical-grade, customized 7-day workout plans tailored to the user's specific health goals (Fat Loss, Muscle Gain, Maintenance), physical biometrics, medical conditions (Diabetes, Hypertension, Joint Pain), and Ramadan fasting status.

---

## Changes Made

### 1. Backend AI & Clinical Workout Engine

#### [NEW] [`workout.py` (Schema)](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/schemas/workout.py)
* Defines `Exercise`, `WorkoutDay`, `WorkoutPlanResponse`, and `WorkoutPlanRequest` Pydantic models with strict validation.

#### [NEW] [`workout_service.py`](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/workout_service.py)
* **Clinical Prompting Engine:** Constructs medical and goal-specific instructions for `gemini_pool` (`gemini-3.6-flash`).
  * **Diabetes / Glucose Control:** Recommends post-meal aerobic/resistance combinations to stimulate GLUT4 glucose transporters and blunt postprandial blood sugar spikes.
  * **Hypertension / High Blood Pressure:** Dynamic continuous circuits, strictly forbidding Valsalva maneuvers (breath-holding under strain) and heavy static isometrics.
  * **Joint Pain / Knee Issues:** Low-impact, non-compressive movements (resistance bands, bodyweight, glute bridges) avoiding heavy plyometrics.
  * **Muscle Building (Hypertrophy):** Progressive overload with 8–12 rep hypertrophy ranges.
  * **Fat Loss:** High-density metabolic conditioning & Zone 2 cardio.
  * **Ramadan Fasting:** Recommends sessions 30–45 mins before Iftar (light cardio/mobility) or 2 hours post-Iftar (resistance training).
* **Deterministic Fallback Generator:** Instantly provides a tailored fallback plan if AI or network is unavailable, ensuring 100% offline uptime.

#### [NEW] [`workout.py` (API Endpoint)](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/workout.py)
* `GET /api/v1/workout/plan/{user_id}`: Retrieves or generates the user's workout plan.
* `POST /api/v1/workout/generate`: Regenerates a fresh workout routine when user profile goals change.

#### [MODIFY] [`router.py`](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/router.py)
* Mounted `/workout` sub-router to `/api/v1`.

---

### 2. Flutter Frontend & Smart Notifications

#### [NEW] [`workout_service.dart`](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/workout_service.dart)
* Client-side service managing API communication, local `SharedPreferences` caching, and exercise completion toggles.

#### [NEW] [`workout_screen.dart`](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/workout/workout_screen.dart)
* **7-Day Horizontal Day Selector (Mon–Sun):** Interactive selector showing active workout vs rest days. Automatically defaults to today's day of the week.
* **Workout Overview Card:** Displays workout title, focus area, total duration in minutes, and estimated calories burned.
* **Clinical Medical Safety Banner:** Highlights condition-specific guidelines (e.g. glucose management, hydration, breathing cues).
* **Interactive Exercise Cards:**
  * Displays sets $\times$ reps, rest periods, and target muscles.
  * Tap checkbox to mark exercises completed in real-time.
  * Expandable form cues and medical precaution tips.
* **Rest & Recovery View:** Dedicated rest day screen featuring 3 recovery pillars:
  1. 💧 *Hydration & Electrolytes*
  2. 🧘 *Light Active Mobility & Stretching*
  3. 😴 *Deep Sleep & Muscle Synthesis*
* **AI Plan Regeneration:** Action button to regenerate the plan anytime.

#### [MODIFY] [`main_navigation_screen.dart`](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/navigation/main_navigation_screen.dart)
* Added Tab 4: `Workout` (`Icons.fitness_center`), preserving all existing navigation indices (`Home: 0`, `Meals: 1`, `Coach: 2`, `Stats: 3`).

#### [MODIFY] [`reminder_manager.dart`](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/reminder_manager.dart)
* **Smart Non-Daily Workout Notifications:**
  * Schedules weekly alarms using **IDs 301–307** (`301` for Mon ... `307` for Sun).
  * **Intelligently skips rest days:** Rest days cancel their respective alarm ID so notifications only fire on active workout days.
  * Respects user preference timing (e.g. default 5:30 PM, or Ramadan post-Iftar 9:30 PM).

---

## Verification Results

### Backend Verification (`backend/test_workout_engine.py`)
```
==================================================
  RUNNING CLINICAL WORKOUT ENGINE & API TESTS     
==================================================

[TEST 1] Testing Diabetic + Fat Loss Plan...
  [OK] Successfully generated Diabetic Fat-Loss plan: Clinical Metabolic & Glucose Management Protocol
  [OK] Weekly frequency: 4 Days Active Training, 1 Day Low-Impact Cardio/Mobility, 2 Days Rest & Recovery
  [OK] Sample medical note: ['Perform workouts 30 to 60 minutes post-meal to blunt postprandial blood glucose spikes.']

[TEST 2] Testing Hypertension + Muscle Gain Plan...
  [OK] Successfully generated Hypertensive Muscle Gain plan: Hypertension-Safe Hypertrophy & Muscle Gain Protocol

[TEST 3] Testing Joint Pain / Arthritis Plan...
  [OK] Successfully generated Joint-Safe plan: Low-Impact Joint-Friendly Health & Maintenance Plan

[TEST 4] Testing Deterministic Clinical Fallback...
  [OK] Fallback plan generated with 7 days and verified rest days

[TEST 5] Testing FastAPI Workout Router Endpoints...
  [OK] GET /api/v1/workout/plan/{user_id} returned 200 OK with full 7-day schedule
  [OK] POST /api/v1/workout/generate returned 200 OK

==================================================
  ALL WORKOUT BACKEND TESTS PASSED (100% SUCCESS) 
==================================================
```
