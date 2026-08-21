# NutriSense Flutter Frontend

The frontend for NutriSense is built with Flutter (Material 3 + Custom Pakistani Natural / Islamic Radial Theme), supporting **Android**, **iOS**, **Windows Desktop**, and **Web**.

---

## 📱 Feature Architecture & Directory Structure

```text
frontend/lib/
├── core/
│   ├── api_client.dart            # HTTP Client with backend endpoint helpers
│   ├── health_service.dart        # Health Connect / Apple Health sync service
│   ├── offline_cache.dart         # SQLite local cache with UUID v4 idempotency keys
│   ├── sync_service.dart          # Background syncing engine to Supabase
│   ├── ramadan_controller.dart    # Hijri & local prayer-time Ramadan controller
│   └── reminder_manager.dart      # Adaptive notification & streak engine
├── data/
│   └── models/
│       ├── family_member.dart     # Family dependent model with smart target calculator
│       └── ...                    # Data contracts and serialization models
├── shared/
│   └── widgets/
│       ├── custom_toast.dart      # Unified toast notification service
│       └── islamic_decorations.dart # Ramadan background wrapper & moon/star visuals
└── ui/
    ├── core/theme.dart            # Natural Emerald Green & Islamic Gold radial themes
    └── features/
        ├── auth/                  # Supabase login, signup, password reset & OAuth
        ├── dashboard/             # Top family pill switcher, calorie rings, macro bars, meals
        ├── chat/                  # AI Coach with 3-step clinical safety & care locator
        ├── meal_scan/             # Gemini vision plate scan, barcode scan, manual logger
        ├── weekly_report/         # Interactive macro charts, AI review & PDF downloader
        ├── family_profiles/       # Multi-dependent CRUD & target configurator
        ├── health_sync/           # Cross-platform health metrics dashboard
        ├── grocery_list/          # AI smart grocery list generator
        └── settings/              # Language toggle, theme picker, smart alert switches
```

---

## 🚀 Running the Frontend

1. Ensure dependencies are resolved:
   ```bash
   flutter pub get
   ```
2. Configure `.env` in `frontend/`:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   BACKEND_URL=http://localhost:8000/api/v1
   ```
3. Run on your target platform:
   ```bash
   flutter run -d windows    # Windows Desktop
   flutter run -d chrome     # Web browser
   flutter run -d <device>   # Android/iOS Physical or Emulator
   ```

---

## 🧪 Verification & Quality Checks

```bash
flutter analyze
flutter test
```
