# Refactoring main.dart to Modular Structure

This plan details the process of refactoring the single 760+ line `lib/main.dart` into modular, domain-aligned files in the project structure we established.

## User Review Required

> [!NOTE]
> We will split `main.dart` into 7 separate files:
> 1. `lib/ui/core/theme.dart` (Theme configuration)
> 2. `lib/ui/features/splash/splash_screen.dart` (Initial loading splash screen)
> 3. `lib/ui/features/navigation/main_navigation_screen.dart` (Base navigation bar layout)
> 4. `lib/ui/features/dashboard/dashboard_screen.dart` (User daily metrics)
> 5. `lib/ui/features/meal_scan/scan_meal_screen.dart` (Camera scanner placeholder)
> 6. `lib/ui/features/chat/ai_coach_screen.dart` (Chatbot placeholder)
> 7. `lib/ui/features/weekly_report/weekly_report_screen.dart` (AI Weekly report display)
>
> `lib/main.dart` will be reduced to only containing the `main()` function and the root `NutriSenseApp` wrapper.

---

## Proposed Changes

### [Component] Core UI Configuration
#### [NEW] [theme.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/core/theme.dart)
Contains `buildLightTheme()` and `buildDarkTheme()` matching the branding colors from `Logo.svg`.

### [Component] Navigation & Splash Features
#### [NEW] [splash_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/splash/splash_screen.dart)
Contains `SplashScreen` widget, animations, and timer loading to navigate to `MainNavigationScreen`.

#### [NEW] [main_navigation_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/navigation/main_navigation_screen.dart)
Contains the core bottom navigation bar setup routing to the 4 main feature screens.

### [Component] Feature Views
#### [NEW] [dashboard_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/dashboard/dashboard_screen.dart)
Contains `DashboardScreen` widget and the `_buildMacroIndicator` private helper.

#### [NEW] [scan_meal_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/scan_meal_screen.dart)
Contains `ScanMealScreen` view.

#### [NEW] [ai_coach_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart)
Contains `AiCoachScreen` view and `_buildChatMessage` private helper.

#### [NEW] [weekly_report_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/weekly_report/weekly_report_screen.dart)
Contains `WeeklyReportScreen` view and `_buildReportHistoryItem` private helper.

### [Component] App Entry point
#### [MODIFY] [main.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/main.dart)
Cleans up the file to only contain `main()`, `NutriSenseApp` (stateful widget holding `ThemeMode`), and imports referencing the separated files.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` inside the `frontend` folder to guarantee imports are correctly resolved and there are no compile-time errors.
