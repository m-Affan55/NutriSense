# NutriSense - AI-Powered Metabolic Health and Precision Nutrition Platform

## The Problem

South Asia, and Pakistan in particular, is undergoing an unprecedented metabolic health crisis. Pakistan currently has the third-highest prevalence of Type 2 Diabetes globally, with over 33 million adults affected and tens of millions more living with undiagnosed pre-diabetes, severe hypertension, cardiovascular disease, and metabolic syndrome. 

Standard international nutrition and fitness applications fail within this demographic because:
1. Regional Dietary Mismatch: Global food databases fail to accurately calculate South Asian composite dishes (such as Biryani, Nihari, Haleem, Daal, and Karahi) or account for variable cooking mediums like hydrogenated ghee and oil-heavy tarka.
2. Clinical Disconnection: Mainstream apps follow naive calorie-in, calorie-out paradigms that ignore clinical realities, such as dangerous post-prandial glycemic spikes or fatal hypoglycemic episodes.
3. Cultural and Structural Incompatibility: Existing tools do not support joint-family dietary management (where a single caregiver cooks for multiple dependents with conflicting medical requirements), circadian fasting during Ramadan, realistic local economic budgeting in Pakistani Rupees (PKR), or localized Urdu language accessibility.

## Who It Affects

1. Chronic Disease Patients: Individuals diagnosed with or at high risk for Type 2 Diabetes, Hypertension, Cardiovascular Disease, Dyslipidemia, and Obesity who need culturally congruent dietary guidance without clinical contradictions.
2. Household Caregivers and Families: Homemakers and family heads in multi-generational households who prepare unified family meals while managing distinct health profiles (e.g., diabetic elders, hypertensive adults, and growing children).
3. Fasting Demographics: Millions of individuals observing Ramadan or voluntary intermittent fasts who require inverted meal schedules, nocturnal hydration pacing, and specialized pre-dawn glycemic stability.
4. General Population Seeking Preventative Care: Health-conscious individuals seeking accurate tracking of South Asian cuisine, condition-aware physical exercise routines, and structured grocery budgeting.

## The Solution

NutriSense is an enterprise-grade, clinical-first digital health platform that bridges the gap between South Asian culinary culture and evidence-based metabolic medicine. 

By combining localized multimodal computer vision, a three-tier agentic clinical safety architecture, condition-specific exercise programming, multi-profile family health management, an automated Ramadan circadian engine, and an offline-first resilient edge architecture, NutriSense delivers personalized, medically safe, and culturally authentic health optimization across mobile, desktop, and web platforms.

---

## Comprehensive Feature Architecture

### Primary Core Features

#### 1. Clinical AI Health and Nutrition Coach with Multi-Tier Safety Architecture
The AI Health Coach serves as an interactive clinical companion capable of guiding users through daily meal choices, symptoms, and dietary adjustments. It operates on a multi-stage architecture to ensure medical safety:
- Contextual Retrieval-Augmented Generation (RAG): Every coaching request aggregates the user's complete clinical profile (age, gender, biometric targets, chronic conditions, and dietary restrictions), current daily meal logs, and 7-day intake history before query processing.
- Independent Post-Inference Risk Evaluator: To prevent AI hallucinations or unsafe advice, an independent clinical safety evaluator agent analyzes both the user input and the coach response. If a potential conflict is identified (e.g., high sodium advice for a hypertensive patient), the system automatically flags the response and appends explicit clinical safety disclaimers.
- Heuristic Hypoglycemia and Acute Distress Fast-Scanner: A dedicated sub-system scans user inputs using deterministic pattern matching for acute clinical emergencies, such as blood glucose levels below 70 mg/dL or severe symptoms (dizziness, chest pain, fainting). When triggered, it bypasses standard conversational replies to immediately present high-priority clinical intervention dialogs.
- Emergency Care Locator: Integrated hospital and clinical facility locator utilizing device geolocation with automatic offline fallback to Google Maps search deep-links for instant emergency facility discovery.
- Multilingual Neural Voice Pipeline: Full bidirectional voice communication supporting English and Urdu via edge-deployed neural voice synthesis, featuring automated Markdown stripping, custom audio caching, and on-device fallback handlers.

#### 2. Condition-Tailored Clinical Workout and Movement Engine
Physical activity recommendations are tightly coupled with the user's diagnosed medical conditions rather than generic fitness archetypes:
- Diabetic and Glycemic Stabilization Splits: Formulates exercise routines centered on post-prandial glucose disposal, combining low-impact steady-state cardiovascular exercise with insulin-sensitizing compound resistance training.
- Hypertensive Cardiovascular Safety Splits: Strictly eliminates heavy isometric strain and Valsalva-inducing lifts, prioritizing Zone-2 aerobic training, controlled breathing cadence, and progressive vascular adaptation.
- Joint-Safe and Arthritic Movement Splits: Replaces high-impact ballistic movements with zero-impact isometric, chair-assisted, and mobility-enhancing protocols to protect compromised joints.
- Deterministic Offline Fallback Library: If network connectivity or AI generation fails, the system automatically falls back to an internal, clinically validated workout database to guarantee uninterrupted physical training schedules.
- Complete Dual-Language Exercise Library: Every movement, set, repetition range, rest period, and clinical rationale is rendered natively in both English and standard Urdu script.

#### 3. Multimodal South Asian Food Scanner and Precision Tracker
NutriSense replaces generic western food databases with a vision and text tracking engine tailored to the complexities of South Asian culinary preparation:
- Composite Regional Dish Recognition: Image recognition models calibrated specifically to recognize complex mixed dishes (Biryani, Nihari, Haleem, Pulao, Daal, Karahi, Salan) and estimate the hidden caloric density of ghee, cooking oil, and tarka.
- Cultural Metric Portion Quantification: Supports culturally accurate serving metrics, including katoris, rotis, naans, and tolas, translating traditional kitchen measures into standard grams, calories, and macronutrients.
- Interactive Non-Blocking Correction Workflow: Allows users to modify detected ingredients, adjust portion sizes, and alter preparation styles with real-time recalculation of total calories, protein, carbohydrates, fats, and glycemic impact.
- Barcode Scanner with Clinical Cross-Referencing: Integrated camera scanner utilizing the OpenFoodFacts database, cross-checking scanned packaged food ingredients against the user's medical conditions and allergen profiles.
- Natural Language and Manual Logging: Robust free-text meal logging equipped with input sanitization and prompt injection protection.

#### 4. Multi-Dependent Family Health and Caregiver Profile Suite
Recognizing that South Asian households cook in shared pots and share health management responsibilities, NutriSense provides single-device multi-profile management:
- Centralized Household Caregiver Architecture: Enables a single user to create, monitor, and manage separate health profiles for multiple dependents, including elderly parents, spouses, and children.
- Automated Pediatric and Geriatric Macro Engines: Independently computes caloric and nutrient requirements for each family member based on age, physiological status, and medical constraints (e.g., elevated micronutrient and protein targets for youth versus tight glycemic targets for diabetic elders).
- Single-Tap Dashboard Switching: A top-level avatar interface allows instant switching between profiles, dynamically updating all caloric intake rings, macronutrient breakdown charts, meal logs, and water metrics across the entire application.

---

### Secondary and Supporting Platform Features

#### 5. Circadian Ramadan Fasting Suite
NutriSense features an automated Ramadan mode that reconfigures the platform around the physiological demands of daylight fasting:
- Dynamic Meal Slot Inversion: Automatically transitions standard Breakfast, Lunch, and Dinner categories into Sehri, Iftar, Post-Iftar Dinner, and Taraweeh Snack windows.
- Dual Solar Countdown Clocks: Real-time countdown timers for Sehri closure and Iftar opening synchronized with local astronomical calculations for the user's geographic timezone.
- Segmented Nocturnal Hydration Pacing: Calculates optimal water intake and distributes hydration reminders across non-fasting night windows to prevent dehydration and kidney strain.
- Fasting Health Rules and Alarm Triggers: Suppresses daytime eating notifications, schedules automated 30-minute pre-Sehri wake-up alarms, and tunes AI coaching recommendations to prioritize sustained energy release.

#### 6. Clinical Weekly Health Intelligence and Binary PDF Report Generator
Provides structured longitudinal progress tracking suitable for clinical review:
- 7-Day Adherence Analytics: Aggregates caloric compliance, macro distribution ratios, fluid intake consistency, and workout completion rates into actionable trend visualizations.
- Zero-Dependency Pure Python Binary PDF Generator: A backend streaming engine generating PDF 1.4 clinical summaries that compile weekly nutritional history, medical flags, and AI observations into a clean format designed for consulting physicians and dietitians.

#### 7. Universal Cross-Platform Health and Activity Sync
Collects device telemetry to maintain a complete picture of total daily energy expenditure:
- Google Health Connect and Apple HealthKit Integration: Native integration with Android Health Connect (Android 14+ built-in and Android 9-13 standalone client) and Apple HealthKit on iOS.
- Passive Telemetry Fetch Architecture: Operates strictly as a read consumer for steps, active calories burned, sleep duration, and resting heart rate, avoiding battery-draining continuous background pedometer services.
- Universal Manual Telemetry Adjuster: Provides fallback logging and persistent trend analytics for Windows Desktop and Web environments where native OS health sensors are unavailable.

#### 8. Offline-First SQLite Architecture with Idempotent Cloud Sync
Built for real-world resilience in environments with intermittent internet connectivity:
- Local SQLite Cache: Local database storing meal entries, water intake, and profile states directly on the user device.
- UUID v4 Idempotency Engine: All locally generated logs are assigned unique UUID v4 identifiers, preventing duplicate records and race conditions when syncing with the cloud database upon network restoration.

#### 9. Intelligent Grocery Planner and Economic Optimization
Assists users in translating nutritional targets into actionable, budget-conscious market purchases:
- Nutritional Gap-Based Shopping Lists: Automatically creates categorized grocery lists based on upcoming meal requirements and logged nutritional deficits.
- Local Economic Budgeting: Integrates PKR budgeting constraints to recommend high-yield, affordable protein and nutrient sources available in local Pakistani markets.
- Healthier Ingredient Swapping Engine: Proactively suggests practical culinary substitutions (such as replacing hydrogenated cooking vanaspati with mustard or olive oil, or substituting high-glycemic refined grains with whole-grain alternatives).

#### 10. Adaptive Notifications and Habit Engine
Encourages long-term user retention and compliance through context-aware reminders:
- Exponential Moving Average (EMA) Reminder Scheduling: Learns the user's actual eating times over time and delivers meal logging prompts aligned with their personal daily routine.
- Streak Protection Alerts: Sends evening reminder notifications before midnight if logging remains incomplete.
- Milestone Celebration System: Dispatches motivational alerts upon achieving consistent multi-day logging streaks.

---

## Technical Stack and Architecture

```text
NutriSense/
|-- backend/
|   |-- app/
|   |   |-- api/v1/
|   |   |   |-- endpoints/     # FastAPI route controllers (health_profile, meals, coach, reports, workout)
|   |   |   `-- router.py      # Consolidated v1 API router
|   |   |-- core/              # Configuration, Security, JWT validation, LRU caches
|   |   |-- db/                # Supabase PostgreSQL client bindings
|   |   |-- schemas/           # Pydantic data schemas and validation models
|   |   |-- services/          # GeminiPool, WorkoutService, ReportService (PDF), TTSService
|   |   `-- main.py            # Application entry point, middleware, and CORS configuration
|   |-- tests/                 # Unit, integration, and security regression suites
|   |-- Dockerfile             # Container configuration for production deployment
|   `-- requirements.txt       # Python backend dependencies
|-- frontend/
|   |-- lib/
|   |   |-- core/              # HealthService, OfflineCache, ReminderManager, SyncService, RamadanController
|   |   |-- data/models/       # Data contracts and serialization models
|   |   |-- shared/widgets/    # Reusable UI components, Islamic decorations, custom toasts
|   |   |-- ui/features/       # Feature modules: Auth, Dashboard, Chat, MealScan, Family, HealthSync, Workout
|   |   `-- main.dart          # Flutter client application entry point
|   |-- android/               # Android native configuration and Health Connect manifests
|   |-- ios/Runner/            # iOS native configuration and HealthKit permissions
|   |-- web/                   # Web application artifacts and manifest
|   `-- pubspec.yaml           # Flutter client dependencies
`-- supabase/
    |-- migrations/            # SQL migration scripts
    `-- schema.sql             # Complete PostgreSQL database schema with Row Level Security
```

### Core Technologies
- Frontend Client: Flutter 3.x (Dart), supporting Android, iOS, Windows Desktop, and Web (CanvasKit / HTML5).
- Backend Services: FastAPI (Python 3.11+), Uvicorn ASGI, Pydantic data validation.
- Database and Authentication: Supabase PostgreSQL with Row Level Security (RLS) and JWT auth verification.
- Multimodal AI and LLM: Google Gemini API (Flash and Vision models) managed via an automated key-pooling and failover architecture.
- Speech Processing: Edge-TTS neural voice synthesis, on-device Speech-to-Text, and AudioPlayers audio engine.
- Local Storage and Cache: SQLite (sqflite / sqflite_common_ffi) with SharedPreferences.

---

## Installation and Setup

### 1. Database Setup (Supabase)
1. Create a project at [supabase.com](https://supabase.com).
2. Open the SQL Editor in your Supabase dashboard.
3. Execute the SQL scripts located in `supabase/schema.sql` and `supabase/migrations/002_family_profiles.sql` to initialize all database tables (`profiles`, `health_profiles`, `family_members`, `meal_logs`, `water_logs`, `chat_history`, `risk_flags`) along with Row Level Security policies.

### 2. Backend Setup (FastAPI)

#### Windows Automated Setup:
```cmd
setup_backend.bat
run_backend.bat
```

#### Manual Setup:
```bash
cd backend
python -m venv venv

# Activate the virtual environment
.\venv\Scripts\activate      # Windows
# source venv/bin/activate   # macOS / Linux

pip install -r requirements.txt
```

Create a `.env` file in the `backend/` directory:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
GEMINI_API_KEY=your-primary-gemini-api-key
GEMINI_API_KEY_2=your-secondary-gemini-key
GEMINI_API_KEY_3=your-tertiary-gemini-key
```

Run the backend development server:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
Interactive Swagger API documentation will be available at `http://localhost:8000/docs`.

### 3. Frontend Setup (Flutter)

#### Windows Automated Setup:
```cmd
run_frontend.bat
```

#### Manual Setup:
```bash
cd frontend
flutter pub get
```

Create a `.env` file in the `frontend/` directory:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
BACKEND_URL=http://127.0.0.1:8000/api/v1
```

Launch the application on your desired target:
```bash
flutter run -d chrome     # Web browser
flutter run -d android    # Android device or emulator
flutter run -d windows    # Windows desktop
flutter run -d ios        # iOS simulator (macOS required)
```

---

## Quality Assurance and Verification

The platform codebase undergoes automated testing to ensure clinical safety, cryptographic validity, and zero-error static analysis:

```bash
# 1. Frontend Static Analysis (Zero errors, zero warnings)
cd frontend && flutter analyze

# 2. Frontend Widget and Unit Test Suite
cd frontend && flutter test

# 3. Backend Clinical Workout Engine Verification
cd backend && .\venv\Scripts\python.exe test_workout_engine.py

# 4. Backend JWT Authentication and LRU Security Cache Tests
cd backend && .\venv\Scripts\python.exe test_jwt_cache.py

# 5. Backend Input Validation and Adversarial QA Tests
cd backend && .\venv\Scripts\python.exe test_category2_fixes.py
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
