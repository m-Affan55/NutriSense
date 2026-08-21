# Ramadan Mode Implementation (Sehri & Iftar Fasting Cycle)

**Ramadan Mode** is now fully adapted to the Islamic fasting cycle according to **Sehri (Suhoor)** and **Iftar**, synchronizing throughout the entire app.

---

## 🌙 Key Capabilities Implemented

### 1. Intelligent Fasting & Timings Engine ([ramadan_controller.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/ramadan_controller.dart))
- **Accurate Fasting Calculation**: Determines whether current local time is in the **Fasting Window (روزہ جاری ہے)** or the **Eating & Hydration Window (کھانے اور ہائیڈریشن کا وقت)**.
- **Live Countdown Timer**: Calculates exact hours and minutes remaining until Iftar (when fasting) or Sehri ends (during the evening eating window).
- **Fasting Timeline Progress**: Computes the elapsed duration of today's fast as a percentage (0.0 to 1.0) with gold gradient progress visualization.
- **Ramadan Meal Mapping**: Seamlessly adapts database meal types to Islamic meals while preserving database schema compatibility:
  - `Breakfast` ➔ **Sehri / Suhoor (سحری)**
  - `Dinner` ➔ **Iftar (افطار)**
  - `Lunch` ➔ **Post-Iftar Dinner (افطار کے بعد کا کھانا)**
  - `Snack` ➔ **Taraweeh / Midnight Snack (تراویح اسنیک)**

### 2. Interactive Ramadan Dashboard Schedule Card ([dashboard_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/dashboard/dashboard_screen.dart))
- **Live Fasting Status & Countdown**: Displays real-time status with golden lunar accents (e.g. `⏳ Fasting in progress • 3h 15m until Iftar` / `⏳ روزہ جاری ہے • افطار میں 3 گھنٹے 15 منٹ باقی`).
- **Sehri & Iftar Time Badges**:
  - 🌙 **Sehri End (سحری ختم)**: `04:30 AM` with instant tap-to-edit.
  - 🌅 **Iftar Time (افطار کا وقت)**: `06:45 PM` with instant tap-to-edit.
- **Fast Hydration Quick-Log Chips**:
  - `+500ml Iftar (افطار)`
  - `+250ml Taraweeh (تراویح)`
  - `+500ml Sehri (سحری)`
- **Ramadan Hydration Selector**: The water logging modal provides dedicated Ramadan hydration presets to help users hit their 2.5L target between Iftar and Sehri.

### 3. Customizable Timings & Alarms in Settings ([settings_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart))
- In-app `showTimePicker()` dialogs to configure local **Sehri Time** and **Iftar Time**.
- **Ramadan Reminders Toggle**: Automatically enables customized alarms and notifications.

### 4. Smart Ramadan Reminders ([reminder_manager.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/reminder_manager.dart))
- **Sehri Alert**: Triggers 30 minutes before Sehri ends (*"⏰ 30 minutes left for Sehri! Drink water & complete your meal"*).
- **Iftar Alert**: Triggers at Iftar time (*"🌟 Iftar Mubarak! Time to break your fast with dates, water & fruit"*).
- **Night Hydration Reminders**: Scheduled at 9:15 PM (Post-Iftar / Taraweeh) and 11:30 PM (Pre-Sleep).
- **Suppresses daytime meal notifications** during fasting hours.

### 5. Ramadan-Aware AI Nutrition Coach ([ai_coach_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart))
- Initial greeting dynamically switches to a Ramadan-specific welcome in English and Urdu Nastaleeq.
- Horizontal Quick Suggestion Chips for:
  - `🌙 Best Sehri foods for energy` / `سحری کے بہترین کھانے`
  - `💧 How to avoid thirst while fasting?` / `روزے میں پیاس سے بچاؤ`
  - `🍲 Healthy Iftar meal ideas` / `صحت مند افطار کے طریقے`
  - `⚡ Workout timing in Ramadan` / `روزے میں ورزش کا وقت`

### 6. Meal Logging Integration ([manual_log_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/manual_log_screen.dart) & [scan_meal_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/scan_meal_screen.dart))
- Meal category selectors automatically switch to **Sehri**, **Iftar**, **Post-Iftar Dinner**, and **Taraweeh Snack**.

---

## 🧪 Verification

- **Static Analysis**:
  ```bash
  flutter analyze
  ```
  **Result**: `No issues found!` (0 errors, 0 warnings).

- **Automated Tests**:
  ```bash
  flutter test
  ```
  **Result**: `All tests passed!`.
