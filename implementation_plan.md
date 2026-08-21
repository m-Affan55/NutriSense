# Implementation Plan: Ramadan Mode

Add a comprehensive, beautiful **Ramadan Mode** across the entire NutriSense application. When enabled, the whole app transforms into a celestial midnight-blue aesthetic with elegant Islamic visuals (glowing crescent moon, stars, lanterns, and subtle geometric arabesque patterns), an interactive Suhoor & Iftar fasting tracker, specialized meal categories (Suhoor/Iftar), non-fasting hydration guidance, and AI-powered fasting nutrition coaching.

---

## User Review Required

> [!IMPORTANT]
> **Ramadan Mode Scope & Global Theme Shift**:
> - Switching to Ramadan Mode changes the app palette from dark-green (`#0D0F14` / `#00E676`) to luxurious **Midnight Navy Blue (`#080E1E` / `#101C36`)** accented with **Celestial Cyan (`#00D2FF`)** and **Islamic Lantern Gold (`#FFD166` / `#F5C518`)**.
> - All screens (Dashboard, Settings, AI Coach, Grocery List, Navigation Bar, Loggers) dynamically adopt the Ramadan theme.
> - The feature is toggleable at any time from **Settings** or directly via a quick-toggle badge on the Dashboard, persisting across restarts via `SharedPreferences`.

---

## Proposed Changes

### Core State & Theming

#### [NEW] [ramadan_controller.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/ramadan_controller.dart)
- Singleton `RamadanController` extending `ChangeNotifier`.
- Manages `isRamadanMode`, `suhoorTime` (default 04:30 AM), `iftarTime` (default 06:45 PM), and city/timezone calculations.
- Persists user preferences to `SharedPreferences`.
- Provides reactive fasting countdown calculations (`timeUntilNextEvent`, `isCurrentlyFasting`).

#### [MODIFY] [theme.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/core/theme.dart)
- Define `RamadanColors`:
  - `bgMidnight`: `Color(0xFF070B16)`
  - `surfaceMidnight`: `Color(0xFF0F172A)`
  - `surfaceCard`: `Color(0xFF16233B)`
  - `primaryCyan`: `Color(0xFF00D2FF)`
  - `accentGold`: `Color(0xFFFFD166)`
  - `textWhite`: `Color(0xFFF8FAFC)`
  - `textMuted`: `Color(0xFF94A3B8)`
- Add `buildRamadanTheme()` configured with custom typography, dark navy surfaces, glowing cyan primary, and golden accents with fallback to Nastaleeq Urdu.

#### [MODIFY] [main.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/main.dart)
- Wrap `MaterialApp` with `ListenableBuilder` listening to `RamadanController.instance`.
- Dynamically apply `buildRamadanTheme()` when Ramadan mode is active.

---

### Islamic Visual Assets & UI Components

#### [NEW] [islamic_decorations.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/shared/widgets/islamic_decorations.dart)
- Vector-rendered Islamic visuals using Flutter `CustomPainter`:
  - `CrescentMoonPainter`: Glowing celestial crescent moon and shimmering star.
  - `IslamicLanternPainter`: Traditional decorative Islamic lantern (Fanous) with warm golden glow.
  - `ArabesquePatternPainter`: Subtle, elegant geometric Islamic star lattice pattern for card headers.
  - `RamadanFastingCard`: Interactive card showing:
    - Current fasting status (Fasting vs. Eating Window).
    - Countdown timer until next Suhoor or Iftar.
    - Suhoor and Iftar time chips with quick edit dialog.
  - `RamadanBanner`: "Ramadan Mubarak / رمضان مبارک" celebratory header banner with Urdu/English greetings.

---

### Feature Screen Updates

#### [MODIFY] [dashboard_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/dashboard/dashboard_screen.dart)
- Detect Ramadan mode and render:
  - Ramadan Mubarak Header with celestial crescent & lantern animation.
  - Interactive `RamadanFastingCard` with countdown to Iftar / Suhoor.
  - Specialized Ramadan Meal Categories ("Suhoor / سحری", "Iftar / افطار", "Dinner / رات کا کھانا", "Hydration Window").
  - Fasting hydration tracker highlighting non-fasting drinking goals.
  - Midnight blue radial gradient background with golden calorie ring shaders.

#### [MODIFY] [settings_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart)
- Add "🌙 Ramadan Mode / رمضان موڈ" section with:
  - Instant Switch toggle (persisted to storage).
  - Suhoor & Iftar time pickers.
  - Full English & Urdu translations.

#### [MODIFY] [main_navigation_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/navigation/main_navigation_screen.dart)
- Tint glassmorphism bottom bar to deep starry blue (`#0F172A`) with golden/cyan glowing active indicators and crescent scanner button.

#### [MODIFY] [ai_coach_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart)
- Ramadan theme styling with midnight blue chat bubbles.
- Add Ramadan Quick-Prompts:
  - 🌙 *Best Suhoor meals for lasting energy*
  - 🍲 *Healthy Iftar balance to avoid bloating*
  - 💧 *Fasting hydration schedule (2.5L)*
  - ⚡ *When to exercise during Ramadan*

#### [MODIFY] [grocery_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/grocery_list/grocery_view.dart)
- Add "Ramadan Essentials / رمضان کے ضروری لوازمات" aisle (Dates, Almonds, Lentils, Oats, Yogurt, Electrolytes) and Ramadan midnight theme.

#### [MODIFY] [manual_log_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/manual_log_screen.dart)
- Include "Suhoor" and "Iftar" in meal type selections when Ramadan mode is active.

---

### Backend Nutrition AI Adaptations

#### [MODIFY] [gemini_service.py](file:///d:/AI%20Hackathon/NutriSense/backend/app/services/gemini_service.py) & [coach.py](file:///d:/AI%20Hackathon/NutriSense/backend/app/api/v1/endpoints/coach.py)
- Incorporate Ramadan fasting awareness into Gemini coaching prompt recommendations when requested by users.

---

## Verification Plan

### Automated Tests
- Run Flutter static analysis:
  ```bash
  flutter analyze
  ```
- Run Flutter test suite:
  ```bash
  flutter test
  ```

### Manual Verification
- Toggle Ramadan Mode on/off in Settings.
- Verify global theme transformation across all 4 navigation tabs (Home, Scanner, Coach, Stats) and sub-screens (Settings, Grocery List).
- Verify Suhoor and Iftar countdown live timer.
- Verify Ramadan quick prompts in AI Coach.
- Verify Urdu and English language switching in Ramadan Mode.
