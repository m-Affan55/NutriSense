# Ramadan Mode Background Visuals (Lanterns, Moon & Stars)

We have added custom-crafted golden Islamic background visuals to the **Ramadan Mode Theme**:

## What Was Added

### 1. Vector Islamic Visuals Painter (`islamic_decorations.dart`)
Created [islamic_decorations.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/shared/widgets/islamic_decorations.dart) containing:
- **Glowing Golden Lanterns (Fanous)**:
  - 3 ornate hanging lanterns at staggered depths and cord lengths.
  - Multi-tiered golden domes with crescent finials, hanging rings, and bead accents.
  - Glass bodies with internal warm candle glow (`#FFFFFF` -> `#FFEA79` -> `#FFA000`), arched lattice panes, and bottom finials.
  - Soft ambient candle radiance radiating into the midnight blue atmosphere.
- **Luminous Golden Crescent Moon (Hilal)**:
  - Metallic golden gradient (`#FFF7C2` -> `#FFD166` -> `#F59E0B` -> `#D97706`) with crisp highlight rim stroke.
  - Soft ambient golden halo glow illuminating the upper-right night sky.
- **Twinkling Celestial Stars & Shimmer**:
  - 4-point sparkle stars scattered with radial shimmer and halo glow.
  - Celestial cyan and warm golden bokeh orbs layered into the background.

### 2. Full-Screen Non-Intrusive Wrapper (`RamadanBackgroundWrapper`)
- Wraps the screen with a `Stack` that renders the custom painter beneath UI controls with `IgnorePointer`, ensuring all taps and scrolls pass through with 60 FPS performance.
- Seamlessly falls back to standard background when Ramadan Mode is disabled.

### 3. Integrated Across Screens
- [dashboard_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/dashboard/dashboard_screen.dart) (Home Screen)
- [settings_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart) (Settings & Ramadan Toggle)
- [ai_coach_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart) (AI Nutrition Coach)
- [grocery_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/grocery_list/grocery_view.dart) (Smart Grocery List)
- [coaching_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/predictive_coaching/coaching_screen.dart) (AI Coaching & Habit Stats)

---

## Verification Results

### Automated Verification
- Ran static analysis:
  ```bash
  flutter analyze
  ```
  **Result**: `No issues found!` (0 warnings, 0 errors).
- Ran unit tests:
  ```bash
  flutter test
  ```
  **Result**: `All tests passed!`.
