# NutriSense — AI-Powered Nutrition App

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.109-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Google Gemini](https://img.shields.io/badge/Google_Gemini-Vision_%26_Flash-8E75B2?style=for-the-badge&logo=google&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL_%26_Auth-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production_Ready-brightgreen?style=for-the-badge)

</div>

NutriSense is a full-stack, AI-powered metabolic health and precision nutrition platform purpose-built for the **Pakistani & South Asian demographic** while adhering to international clinical standards. 

It uniquely solves chronic regional health challenges (Type-2 Diabetes, Hypertension, CVD, Ghee/Tarka-heavy composite cooking) through **multimodal AI vision plate scanning**, a **3-step RAG clinical evaluator**, a **condition-tailored AI workout engine**, an **intelligent Ramadan fasting suite**, **multi-profile family management**, **offline SQLite sync with UUID v4 idempotency**, and **full bilingual English + Urdu Nastaleeq typography**.

---

## 🌟 Key Modules & Architecture

### 1. 🤖 AI Clinical Safety & Multi-Model Pooling Engine
* **3-Step Clinical Architecture**: Retrieval (RAG: Profile & 7-Day History) $\to$ Contextual Coaching $\to$ Independent Risk Evaluator.
* **Hypoglycemia Fast-Detection**: Instant regex and heuristic scanner detecting acute low blood sugar readings (`<70 mg/dL`) or distress symptoms, triggering immediate blocking safety dialogs.
* **Non-Contradictory Safety Disclaimers**: Automatically attaches clinical warning blocks when risk levels trigger (`warning`/`critical`), eliminating conflicting advice.
* **Resilient Multi-Key Gemini Pool**: Auto-cycles across multiple Gemini models (`gemini-2.5-flash-lite`, `gemini-2.5-flash`, `gemini-3.6-flash`, `gemini-3.7-flash`) across multiple API keys with stateful rate-limit tracking (60s rolling cooldowns) and instant sub-2-second response latency.
* **Care Locator**: Direct GPS hospital finder with automatic offline fallback to Google Maps deep-links (`hospital near me`).

---

### 2. 🏋️‍♂️ Personalized Clinical Workout Engine
* **Condition-Aware Exercise Splits**: Dynamically creates 7-day personalized workout schedules tailored to specific clinical conditions:
  * **Diabetic / High Blood Sugar**: Focuses on post-prandial glucose-blunting cardio and insulin-sensitizing resistance routines.
  * **Hypertension / High BP**: Strictly excludes heavy Valsalva maneuvers; emphasizes steady-state Zone 2 aerobic training.
  * **Joint Pain / Arthritis**: Replaces high-impact movements with zero-impact isometric, water-friendly, and chair-assisted exercises.
* **Deterministic Fallback Engine**: Fully offline, clinically safe fallback routine if AI services are unreachable.
* **Bilingual Translation**: Complete localization in English and native Urdu Arabic script.

---

### 3. 📸 Multimodal Plate & Barcode Scanner
* **Gemini Vision Plate Recognition**: Calibrated for South Asian portion conventions (*katori, roti, naan, tola*) and cooking oil/ghee *tarka* calculations for composite curries (*Biryani, Nihari, Haleem, Daal, Karahi*).
* **Live Non-Blocking Correction Flow**: Dynamic UI portion modifiers allowing instant re-calculation of calories and macros.
* **Barcode Scanner**: `mobile_scanner` + OpenFoodFacts integration with automatic allergen and medical cross-referencing.
* **Manual AI Logger**: Natural language meal logging with strict input timeouts and prompt injection protection.

---

### 4. 🌙 Native Ramadan Fasting Suite
* **Dynamic Meal Slot Transformation**: Automatically re-maps standard meal slots to *Sehri*, *Iftar*, *Post-Iftar Dinner*, and *Taraweeh Snack*.
* **Live Countdown Clocks**: Real-time dual countdown clocks for Sehri and Iftar for local timezones (`Asia/Karachi`).
* **Split Hydration Pacing**: Divides total daily fluid intake across non-fasting night windows (Iftar, Post-Taraweeh, and Pre-Sehri).
* **Fasting Health Rules**: Suppresses daytime eating notifications, schedules 30-min pre-Sehri alarms, and tunes AI coaching for fasting physiology.

---

### 5. 👨‍👩‍👧‍👦 Family Profiles (خاندانی پروفائلز)
* **Single-Device Dependent Manager**: Manage nutrition for children, elderly diabetic parents, and spouses on one account.
* **Intelligent Macro Calculator**: Automatically customizes daily calorie and macro goals per dependent (e.g. growth development for children vs. low-glycemic targets for seniors).
* **1-Tap Dashboard Switcher**: Top avatar pill bar (`[🧑 Me] [👧 Ayesha] [👴 Abu] [+ Family]`) filtering calorie rings, macro targets, and meal histories dynamically.

---

### 6. 📊 Clinical Weekly PDF & Analytics Report
* **7-Day Adherence Analytics (`/api/v1/reports/weekly`)**: Evaluates calorie adherence, macro distributions, and AI narrative reviews.
* **Zero-Dependency PDF Stream Generator (`/api/v1/reports/weekly/pdf`)**: Pure-Python binary PDF 1.4 generator creating downloadable clinical reports formatted directly for local doctors and physicians.

---

### 7. 🔔 Adaptive Notifications & Habit Tracking
* **Exponential Moving Average Reminders**: Learns user eating routines and delivers timely meal prompts.
* **Evening Streak Saver (8:30 PM)**: Automated reminder before midnight to protect logging streaks.
* **Milestone Celebrations**: Dispatches celebratory alerts on 3, 5, 7, 10, 14, and 30-day streaks.

---

### 8. 📴 Offline-First SQLite Sync & Cross-Platform Sync
* **Idempotent Dual-Write Cache**: Local SQLite storage (`nutrisense_offline.db`) storing meal/water logs with UUID v4 idempotency keys preventing duplicate entries upon network reconnection.
* **Cross-Platform Health Telemetry**: Synchronizes steps, active calories, heart rate, and sleep across Android (Health Connect), iOS (Apple Health), and Web/Desktop.

---

## 📂 Project Structure

```text
NutriSense/
├── backend/
│   ├── app/
│   │   ├── api/v1/
│   │   │   ├── endpoints/     # FastAPI routers (health_profile, meals, profile, coach, coaching, reports, workout)
│   │   │   └── router.py      # Consolidated v1 API router
│   │   ├── core/              # Config, Security (JWT + LRU cache), Logging
│   │   ├── db/                # Supabase Admin & Client connectors
│   │   ├── schemas/           # Pydantic schemas (meal, workout)
│   │   ├── services/          # GeminiPool, WorkoutService, GeminiService, ReportService (PDF), BarcodeService
│   │   └── main.py            # FastAPI entry point with CORS regex mapping
│   ├── tests/                 # Unit & regression test suites
│   ├── test_workout_engine.py # Clinical workout engine tests
│   ├── test_jwt_cache.py      # JWT security & LRU cache tests
│   ├── test_category2_fixes.py# Input validation & adversarial QA tests
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   │   ├── core/              # HealthService, OfflineCache, ReminderManager, SyncService, RamadanController, TTS
│   │   ├── data/models/       # FamilyMember model
│   │   ├── shared/widgets/    # IslamicDecorations, CustomToast, AnimatedRings
│   │   ├── ui/features/       # Auth, Dashboard, MealScan, AICoach, FamilyProfiles, HealthSync, WeeklyReport, Workout, Settings
│   │   └── main.dart          # Flutter entry point
│   ├── ios/Runner/            # Complete iOS Info.plist with Camera/Mic/Health permissions
│   ├── android/               # Android Manifest & launcher icon configuration
│   ├── web/                   # Web build artifacts & PWA configuration
│   ├── pubspec.yaml
│   └── vercel-build.sh        # CI/CD Flutter Web build script
├── supabase/
│   ├── migrations/            # 001_initial_schema.sql, 002_family_profiles.sql
│   └── schema.sql             # Consolidated PostgreSQL schema with RLS
├── run_backend.bat            # 1-Click Windows backend launcher
├── run_frontend.bat           # 1-Click Windows frontend launcher
└── setup_backend.bat          # 1-Click Python venv & dependency installer
```

---

## 🚀 Quick Start Guide

### 1. Database Setup (Supabase)
1. Create a project at [supabase.com](https://supabase.com).
2. Open the **SQL Editor** in your Supabase dashboard.
3. Run [`supabase/schema.sql`](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/supabase/schema.sql) and [`supabase/migrations/002_family_profiles.sql`](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/supabase/migrations/002_family_profiles.sql) to initialize tables (`profiles`, `health_profiles`, `family_members`, `meal_logs`, `water_logs`, `chat_history`, `risk_flags`) with Row Level Security (RLS).

---

### 2. Backend Setup (FastAPI)

#### Windows (Automated):
```cmd
setup_backend.bat
run_backend.bat
```

#### Manual:
```bash
cd backend
python -m venv venv

# Activate venv:
.\venv\Scripts\activate      # Windows
# source venv/bin/activate   # macOS / Linux

pip install -r requirements.txt
```

Create a `.env` file in `backend/`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
GEMINI_API_KEY=your-gemini-api-key
GEMINI_API_KEY_2=your-second-gemini-key (optional for key pool)
GEMINI_API_KEY_3=your-third-gemini-key (optional for key pool)
```

Run the backend server:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
Interactive API Documentation: `http://localhost:8000/docs`

---

### 3. Frontend Setup (Flutter)

#### Windows (Automated):
```cmd
run_frontend.bat
```

#### Manual:
```bash
cd frontend
flutter pub get
```

Create a `.env` file in `frontend/`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
BACKEND_URL=http://127.0.0.1:8000/api/v1
```

Run on your target platform:
```bash
flutter run -d chrome    # Web (CanvasKit)
flutter run -d android   # Android Emulator / Device
flutter run -d windows   # Windows Desktop
flutter run -d ios       # iOS Simulator (macOS only)
```

---

## 🧪 Quality Assurance & Test Verification

All modules have undergone adversarial QA testing with 100% passing results:

```bash
# 1. Frontend Static Analysis (0 errors, 0 warnings)
cd frontend && flutter analyze

# 2. Frontend Widget & Unit Tests
cd frontend && flutter test

# 3. Backend Workout Engine Tests (Diabetic, Hypertensive, Joint-Safe, Fallback)
cd backend && .\venv\Scripts\python.exe test_workout_engine.py

# 4. Backend JWT Authentication & Security LRU Cache Tests
cd backend && .\venv\Scripts\python.exe test_jwt_cache.py

# 5. Backend Input Validation & Adversarial QA Tests
cd backend && .\venv\Scripts\python.exe test_category2_fixes.py
```

---

## 🏆 Bano Qabil Hackathon Highlights
- **Impact & Demographics**: Tackles Pakistan's national metabolic crisis with localized nutrition intelligence, PKR budgeting, joint-family workflows, and bilingual Urdu Nastaleeq typography.
- **Agentic AI**: 3-step clinical evaluator with multi-key Gemini pooling and hypoglycemia fail-safe fast detection.
- **Production Resilience**: Offline-first SQLite syncing, deterministic fallback engines, and zero-lint codebase.

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
