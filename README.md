# NutriSense — AI Nutrition Coach

A Vision-Powered Personal Nutritionist.

## Overview
NutriSense transforms daily health management by shifting from a passive calorie tracker to a proactive, intelligent nutrition platform. Instead of manual food logging, users snap a photo of their meal, allowing the AI to understand food composition, calculate macronutrients, and deliver context-aware, proactive coaching in real time.

---

## Complete Feature Matrix

### Core Features
*   **Conversational Onboarding:** Chat-style profile capture gathering age, weight, height, gender, goal (fat loss, muscle gain, maintenance), activity level, medical/dietary restrictions (IBS, diabetes, hypertension, halal/vegetarian), budget, and food preferences.
*   **Personalized Diet Plan:** Tailored daily breakdown covering breakfast, lunch, dinner, snacks, water intake, total calories, macronutrients (protein, carbs, fats), and micronutrients.
*   **Meal Photo Recognition:** Core centerpiece feature — instant plate scanning to detect food items, calculate macros/calories, and log meals automatically.
*   **Barcode Scanner:** Rapid lookup and verification for packaged foods and beverages via USDA FoodData Central and Nutritionix.
*   **AI Nutrition Chat:** Specialized conversational assistant capable of answering contextual queries (e.g., *"I want to gain 5kg"*, *"I only have eggs and bread"*, *"I'm fasting"*) adapted to user health profiles.
*   **Daily Progress Dashboard:** Unified daily tracking of calories, macros, hydration, weight trends, steps, sleep, and completed workouts.
*   **AI Weekly Report:** Dynamic narrative weekly summaries that highlight behavioral trends (e.g., *"Sugar intake up 18% vs last week"*) beyond static charts.
*   **Allergy & Medical Safety Alerts:** Real-time safety engine that flags scanned ingredients conflicting with health conditions or allergies defined during onboarding.
*   **Offline Mode + Background Sync:** Offline-first caching via local storage to log meals and view dashboards without internet, auto-syncing to Supabase upon reconnection.
*   **Data Export & Account Deletion:** Direct in-app privacy controls to download health records or erase user accounts.

### Recommended Differentiators
*   **Predictive Coaching:** Forecasts behavioral patterns (e.g., *"You usually exceed targets on Fridays; here are 3 dinner alternatives"*) to correct habits before they occur.
*   **Habit Score:** Composite metric assessing nutrition balance, hydration consistency, protein goals, and routine adherence.
*   **Food Swap AI:** Recommends macro-equivalent, lower-calorie substitutes for scanned indulgent foods (e.g., burger to chicken wrap).
*   **Apple Health / Google Fit Sync:** Automated background ingestion of steps, active calories, sleep duration, and exercise logs.
*   **Smart Grocery List Generator:** Converts active meal plans into organized, categorized shopping lists.
*   **Push Notification Engine:** Actionable alerts via Firebase Cloud Messaging for water reminders, habit nudges, and predictive coaching warnings.
*   **In-App Onboarding Tutorial:** Step-by-step first-launch walkthrough highlighting core scanning and tracking capabilities.
*   **Subscription Tiers (Free / Pro):** Tiered access model distinguishing core tracking from premium predictive coaching and advanced menu analysis.

### Stretch Features
*   **Nutrition Vision:** Instant estimation and macro breakdown of multi-item buffets and large spreads from a single photograph.
*   **Restaurant Menu Helper:** Real-time camera analysis of physical dining menus highlighting target-aligned dishes.
*   **Dining Out Mode:** Fast-food and restaurant chain meal recommendations customized to remaining daily macros.
*   **Budget Diet Mode:** Full weekly meal plan optimization constrained to strict spending budgets (e.g., 1500 PKR).
*   **Ramadan Mode:** Dynamic diet timing and hydration schedules optimized for Suhoor and Iftar fasts.
*   **Voice Input:** Voice-driven logging and query prompts for hands-free interactions.
*   **Urdu / Roman-Urdu Support:** Multi-language UI and AI translation localization.
*   **Family / Dependent Profiles:** Multi-profile management to oversee nutrition for family members from a single account.
*   **Dietitian / Doctor Export Report:** One-touch medical-grade PDF report export for consultations.
*   **Dark Mode:** Full dark theme UI support.
*   **Referral / Invite-a-Friend Loop:** Social accountability loops for paired tracking.

---

## Technology Stack

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend** | Flutter (Android / iOS) | Single-codebase mobile UI with Riverpod state management |
| **Backend** | FastAPI (Python) | High-performance asynchronous AI orchestration and business logic |
| **Database** | Supabase (PostgreSQL) | Relational persistence with Row-Level Security (RLS) policies |
| **Authentication** | Supabase Auth | JWT-based auth supporting email, OTP, and social logins |
| **Storage** | Supabase Storage | Cloud object storage for meal uploads and profile images |
| **Realtime** | Supabase Realtime | Live dashboard syncing across connected clients |
| **Core AI & Vision** | Google Gemini / OpenAI | Multimodal plate scanning, text reasoning, and coaching synthesis |
| **Food Databases** | USDA FoodData Central / Nutritionix | Nutritional verification and standardized macro indexing |
| **Data Visualization** | `fl_chart` | Smooth cross-platform nutritional charts and trends |
| **Notifications** | Firebase Cloud Messaging (FCM) | Automated push notifications and predictive reminders |
| **Deployment** | Python Virtualenv, Railway / Localhost, Supabase Cloud | Direct backend hosting, managed database, and mobile APK builds |

---

## Project Structure

```text
ai-nutrition-coach/
├── frontend/                         # Flutter Mobile Client
│   ├── lib/
│   │   ├── main.dart                 # Entry point (initializes app & runs NutriSenseApp)
│   │   ├── data/                     # Data layer: API clients, repositories, Supabase
│   │   │   ├── models/               # API & serialization models
│   │   │   ├── repositories/         # Repo implementations (caching, offline sync)
│   │   │   └── services/             # Remote API services (Supabase client wrappers)
│   │   ├── domain/                   # Domain layer: pure business rules
│   │   │   └── models/               # Clean domain data entities
│   │   ├── shared/                   # Reusable assets shared across layers
│   │   │   ├── services/             # Local database, logging, shared utility services
│   │   │   └── widgets/              # Reusable UI widgets (custom buttons, cards)
│   │   └── ui/                       # Presentation layer (MVVM)
│   │       ├── core/                 # Shared UI elements, global themes, constants
│   │       └── features/             # Feature-sliced folders containing Views & ViewModels
│   │           ├── onboarding/       # Conversational profile builder
│   │           ├── auth/             # Authentication screens
│   │           ├── dashboard/        # Daily nutrition metrics & progress tracking
│   │           ├── meal_scan/        # Meal photo scanning & food recognition UI
│   │           ├── diet_plan/        # Customized diet and hydration scheduler
│   │           ├── coach_chat/       # Personal AI nutrition coach conversation
│   │           ├── weekly_report/    # AI-generated weekly behavioral trends
│   │           ├── predictive_coaching/ # Habit forecasting and alerts
│   │           ├── grocery_list/     # Smart grocery shopping organizer
│   │           ├── health_sync/      # Apple Health & Google Fit integrations
│   │           ├── family_profiles/  # Multi-profile dependent configuration
│   │           ├── subscription/     # Subscription tiers & paywall
│   │           ├── settings/         # App settings & privacy controls
│   │           └── notifications/    # Push notifications handler
│   ├── assets/                       # Static images, icons, and logo assets
│   └── pubspec.yaml
│
├── backend/                          # FastAPI AI Microservice
│   ├── app/
│   │   ├── main.py                   # Server entrypoint
│   │   ├── api/v1/                   # Modular API routers (vision, chat, coaching, reports)
│   │   ├── core/                     # Environment configuration and JWT security validators
│   │   ├── services/                 # AI Vision, LLM prompt runners, and macro lookup services
│   │   ├── models/                   # Pydantic schemas and serialization models
│   │   └── db/                       # Supabase client connector
│   ├── requirements.txt
│   └── .env.example
│
├── supabase/
│   ├── migrations/                   # SQL migration scripts & RLS policies
│   └── schema.sql                    # Base PostgreSQL schema
│
├── docs/                             # Project proposal and architecture documentation
├── README.md
└── .gitignore
