# Project Structure Design for NutriSense

This plan details the folder structure and architecture for the NutriSense project (Frontend: Flutter, Backend: FastAPI) and addresses whether any existing files should be deleted.

## User Review Required

> [!NOTE]
> - **Frontend (Flutter)** is currently missing a `lib/` directory entirely (which contains `lib/main.dart`). We will create it.
> - **No files need to be deleted** from either the frontend or backend. The existing boilerplate files are standard configuration files (`pubspec.yaml`, `requirements.txt`, config templates) that we will build upon.

---

## Proposed Project Structure

### 1. Frontend (Flutter) Structure
We will adopt the **layered MVVM (Model-View-ViewModel)** architectural pattern. This keeps data-fetching and business logic decoupled from the UI.

```text
frontend/
├── android/
├── ios/
├── web/
├── windows/ (and other desktop folders)
├── test/
│   └── widget_test.dart
├── pubspec.yaml
├── analysis_options.yaml
└── lib/                        # [NEW] Main Dart application folder
    ├── main.dart               # [NEW] Entry point (initializes services, runs MyApp)
    ├── data/                   # Data layer: interfaces with APIs and storage
    │   ├── models/             # Serialization/deserialization classes
    │   ├── repositories/       # Single sources of truth that combine services
    │   └── services/           # HTTP clients, Supabase client wrappers
    ├── domain/                 # Domain layer (business rules, models)
    │   └── models/             # Clean domain data classes
    └── ui/                     # Presentation layer (MVVM)
        ├── core/               # Shared widgets, themes, styling, and typography
        │   ├── theme.dart
        │   └── constants.dart
        └── features/           # Feature-sliced folders containing Views & ViewModels
            ├── onboarding/     # Conversational profile builder
            │   ├── views/
            │   └── view_models/
            ├── dashboard/      # Daily nutrition metrics (calories, water)
            │   ├── views/
            │   └── view_models/
            ├── meal_scan/      # Camera interface & food recognition UI
            │   ├── views/
            │   └── view_models/
            ├── chat/           # Personal AI nutrition coach chat interface
            │   ├── views/
            │   └── view_models/
            └── weekly_report/  # AI-generated narrative progress reports
                ├── views/
                └── view_models/
```

### 2. Backend (FastAPI) Structure
We will structure the backend using a clean, scalable FastAPI folder setup.

```text
backend/
├── app/
│   ├── api/                    # API endpoints
│   │   ├── deps.py             # Common dependency injections (DB, Auth)
│   │   └── v1/
│   │       ├── endpoints/
│   │       │   ├── auth.py         # Sign-up & Login
│   │       │   ├── profile.py      # Onboarding info
│   │       │   ├── meals.py        # Log & recognize meals
│   │       │   ├── coach.py        # AI nutritional chat
│   │       │   └── reports.py      # AI weekly summary reports
│   │       └── api.py              # Main router assembly
│   ├── core/                   # Project configurations and security
│   │   ├── config.py           # Settings and credentials (modified)
│   │   ├── security.py         # Password hashing, JWT generation
│   │   └── database.py         # SQLAlchemy connection helper
│   ├── models/                 # SQLAlchemy DB models (Supabase connection)
│   │   ├── user.py
│   │   ├── profile.py
│   │   ├── meal.py
│   │   └── chat.py
│   ├── schemas/                # Pydantic schemas (Request/Response validation)
│   │   ├── user.py
│   │   ├── profile.py
│   │   ├── meal.py
│   │   └── chat.py
│   ├── crud/                   # DB queries (Create, Read, Update, Delete)
│   │   ├── crud_user.py
│   │   ├── crud_meal.py
│   │   └── ...
│   ├── services/               # AI & External services
│   │   ├── gemini_service.py   # Call Gemini API for vision & chat
│   │   └── supabase_service.py # Direct Supabase queries if needed
│   └── main.py                 # FastAPI application startup & settings
├── requirements.txt            # Python dependencies (modified if needed)
└── .env                        # Environment variables (credentials, API keys)
```

---

## Deletions & Cleanup

* **Should we delete anything?** No.
* All template/config files (`requirements.txt`, `backend/app/main.py`, `backend/app/core/config.py`, `frontend/pubspec.yaml`, platform configurations) are essential files to build on. We will modify them to suit the new structure, but no deletions are necessary.

---

## Next Steps / Execution Plan

1. **Backend Initialization**: Create all sub-folders and mock files under `backend/app`.
2. **Frontend Initialization**: Create the `lib/` directory and configure the base directories and `lib/main.dart` with a simple container placeholder.
3. **Verify**: Ensure the backend starts up, and the frontend builds.
