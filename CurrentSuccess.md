# NutriSense — Current Success & Future Roadmap

This document outlines the current state of NutriSense (what has been successfully implemented) and details the high-priority future features to be implemented next.

---

## 🏆 Current Success (Completed Features)

### 1. Core Platform & User Profiles
* **Conversational Onboarding**: Capture parameters (age, weight, height, budget, medical conditions, diet restrictions, fitness goals).
* **Personalized Diet Plan & Targets**: Calculates and saves daily targets for calories, protein, carbs, and fats.
* **Urdu & English Localization**: Cross-screen translation support (dashboard, weekly report, settings, manual loggers).

### 2. Meal & Hydration Tracking
* **AI Image Scan-to-Log**: Instant photo scanning utilizing high-performance, structured Gemini AI models to identify foods, estimate sizes, and log macros.
* **Manual Meal Logger**: Localized manual logging form with verification controls.
* **Advanced Hydration Selector**: Custom bottom sheet offering standard cup/bottle selections and dynamic custom milliliter entries.

### 3. Data Analytics & Interactive Visualization
* **AI Weekly Report**: Instant narrative summary detailing calorie and macro intake trends over the last 7 days.
* **Interactive Macro Trend Charts**: Clickable custom-painted weekly calorie and macro bar chart detailing goal-target comparisons and selection drawers.

### 4. Account Security & Recovery
* **Supabase Authentication**: Secure login, signup, and signout flows.
* **Google Social OAuth**: "Continue with Google" sign-in support.
* **Password Recovery**: Complete recovery loop via Forgot Password and Update Password screens.
* **Profile Settings Theme Alignment**: Cohesive dark-mode radial styling matching the login experience.

### 5. Utilities & Privacy Controls
* **Local Push Reminders**: Cross-platform system notifications scheduling daily meal logging and hydration alerts.
* **Beautiful PDF Export**: Dark-accented Multi-Page PDF receipt outlining targets, logged meals, and hydration data.
* **Account Deletion**: Cascading user erasure via Supabase database constraints.

---

## 🚀 What to Implement Next (Prioritized Backlog)

The following backlog is prioritized by product value and developmental sequence:

### Priority 1: Barcode Scanner (High)
* **Objective**: Enable logging for pre-packaged foods by scanning barcodes.
* **Action Items**:
  1. Integrate the `mobile_scanner` package.
  2. Connect scans to USDA FoodData Central or Nutritionix APIs on the backend.
  3. Show a search fallback if barcode lookup fails.

### Priority 2: Allergy & Medical Safety Alerts (High)
* **Objective**: Flag scanned ingredients that conflict with allergies or medical restrictions defined during onboarding.
* **Action Items**:
  1. Pass the user's restrictions profile list (e.g. Celiac, IBS, Nut Allergy) to the Gemini scanner prompt.
  2. Return warning flags and explain the hazard in the scan result screen.
  3. Style safety callouts on the dashboard if logged items pose a hazard.

### Priority 3: Offline Mode & Background Sync (Medium)
* **Objective**: Log meals and view dashboards without internet connection.
* **Action Items**:
  1. Store logs locally using SQLite or Hive database caching.
  2. Implement background sync service to push cached logs to Supabase upon internet restoration.

### Priority 4: Smart Grocery List Generator (Medium)
* **Objective**: Convert active weekly meal plans into organized, categorized shopping lists.
* **Action Items**:
  1. Implement AI menu-to-ingredients conversion.
  2. Design interactive checklists where ingredients can be marked off.

### Priority 5: Apple Health & Google Fit Sync (Medium)
* **Objective**: Auto-ingest steps, sleep duration, and active energy burn.
* **Action Items**:
  1. Integrate the `health` package for iOS/Android fitness API authorization.
  2. Overlay physical activity metrics alongside food tracking.

### Priority 6: Predictive Coaching & Habit Score (Low)
* **Objective**: Forecast habit warnings and supply macro-equivalent food swaps.
* **Action Items**:
  1. Compute a cumulative "Habit Score" based on consistency.
  2. Recommend healthy food swaps (e.g. burger to chicken wrap) based on scanned meals.
