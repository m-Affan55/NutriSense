# NutriSense — Current Success & Future Roadmap

This document outlines the current state of NutriSense (what has been successfully implemented) and details the high-priority future features to be implemented next.

---

## 🏆 Current Success (Completed Features)

### 1. Core Platform & User Profiles
* **Conversational Onboarding**: Capture parameters (age, weight, height, budget, medical conditions, diet restrictions, fitness goals).
* **Personalized Diet Plan & Targets**: Calculates and saves daily targets for calories, protein, carbs, and fats.
* **Urdu & English Localization**: Cross-screen translation support (dashboard, weekly report, settings, manual loggers).

### 2. Meal & Hydration Tracking
* **AI Image Scan-to-Log (Pakistan-Optimised)**: Instant photo scanning using Gemini Vision.
  Automatically identifies both international and Pakistani foods (Daal, Biryani, Bhindi, 
  Nihari, Paratha, etc.) with portion size calibration for South Asian serving conventions 
  (katori, roti, naan). Adjusts macro calculations for ghee/oil-based cooking methods 
  (tarka). Displays food names in Urdu or English based on the user's selected language. 
  When recognition confidence is low, a non-blocking correction button appears — the user 
  never has to take extra steps for any food type.
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

### 6. AI Agentic Safety Pipeline
* **Multi-Step Coach Architecture**: The AI Coach no longer makes a single LLM call. 
  Every response goes through a 3-step pipeline: (1) Retrieval of user health profile 
  and 7-day meal history from Supabase (Pragmatic RAG), (2) Coach reply generation 
  with full medical context, (3) Independent Risk Evaluator pass that checks the 
  response against the user's medical conditions.
* **Wellness Risk Detection**: When the Risk Evaluator detects a medically concerning 
  pattern (e.g. consistent high-carb intake for a diabetic user, or high-sodium meals 
  for a hypertensive user), a non-alarmist escalation alert is surfaced inline in the 
  chat. The AI never diagnoses — it only recommends professional consultation.
* **Affordable Doctor & Clinic Finder**: When an escalation alert is shown, a 
  "Find Affordable Care" button appears. Users can choose government hospital or 
  private clinic preference and see a list of nearby options with distance, contact 
  information, and one-tap calling or directions.

### 7. Advanced Tracking & Offline Sync
* **Offline Mode & Background Sync**: Users can now log meals and view their dashboards completely offline using SQLite. A background `SyncService` gracefully pushes all cached logs up to Supabase the moment an internet connection is reestablished, ensuring zero data loss.
* **Health API Sync**: Integrated Apple Health & Google Fit (via Health Connect) to auto-ingest daily steps and active energy burn, overlaying this physical activity alongside food tracking on the Dashboard.

### 8. Predictive Coaching & Habit Score
* **Habit Score Engine**: Computes a dynamic 30-day "Habit Score" based on daily adherence to calorie and protein targets, visualized via a responsive UI gauge and 7-Day Consistency chart.
* **Proactive Food Swaps**: Gemini analyzes the user's recent meals and cross-references their medical profile to recommend healthier, personalized food swaps (e.g., swapping a high-carb item for a high-protein equivalent), complete with clear rationales.

### 9. Barcode Scanner & Allergy Alerts
* **Mobile Barcode Scanning**: Integrated `mobile_scanner` to allow users to scan pre-packaged foods instantly.
* **Nutrition API & Allergy Cross-check**: Connects to OpenFoodFacts on the backend to retrieve ingredients and allergens. Passes the ingredients through the Gemini Risk Evaluator to automatically cross-check against the user's specific dietary restrictions and medical conditions, surfacing critical warnings instantly.

---

## 🚀 What to Implement Next (Prioritized Backlog)

The following backlog is prioritized by product value and developmental sequence:

### Priority 1: Smart Grocery List Generator (Medium)
* **Objective**: Convert weekly meal plans into organized, categorized shopping lists.
* **Action Items**:
  1. Connect the existing `grocery_list` Flutter screen stub to a new backend endpoint.
  2. Use Gemini to extract ingredients from logged meals and group by category.
  3. Design interactive checklists where items can be marked off.
