# Family Profiles (👨‍👩‍👧‍👦 خاندانی پروفائلز) Implementation

We have implemented **Family Profiles** allowing primary caregivers to manage customized nutrition, macro targets, and meal logging for children, elderly parents (e.g. with diabetes/hypertension), and spouses.

---

## 🗄️ Supabase Tables & Schema Setup

To enable Family Profiles in your Supabase project, execute the migration SQL located in [002_family_profiles.sql](file:///d:/AI%20Hackathon/NutriSense/supabase/migrations/002_family_profiles.sql) in the **Supabase SQL Editor**:

```sql
-- 1. Create family_members table
CREATE TABLE IF NOT EXISTS public.family_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    relationship TEXT NOT NULL CHECK (relationship IN ('child', 'parent', 'spouse', 'sibling', 'other')),
    age INT,
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    daily_calorie_target INT DEFAULT 1800,
    daily_protein_g INT DEFAULT 100,
    daily_carbs_g INT DEFAULT 200,
    daily_fat_g INT DEFAULT 50,
    medical_conditions TEXT[] DEFAULT '{}',
    dietary_restrictions TEXT[] DEFAULT '{}',
    avatar_color TEXT DEFAULT '#00E676',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Add family_member_id to meal_logs (nullable, NULL = primary account user)
ALTER TABLE public.meal_logs
ADD COLUMN IF NOT EXISTS family_member_id UUID REFERENCES public.family_members(id) ON DELETE CASCADE;

-- 3. Row Level Security (RLS)
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own family members"
    ON public.family_members
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 4. Trigger for updated_at
CREATE TRIGGER update_family_members_updated_at
    BEFORE UPDATE ON public.family_members
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
```

---

## 📱 Features & Implementation Details

### 1. 👨‍👩‍👧 Family Management Hub ([family_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/family_profiles/family_view.dart))
- **Interactive Add/Edit Modal**:
  - Name, Relationship (`child`, `parent`, `spouse`, `sibling`, `other`), Age, Gender.
  - Medical condition tags (`Diabetes`, `Hypertension`, `High Cholesterol`, etc.)
  - Dietary restrictions (`Halal`, `Vegetarian`, `No Sugar`, `Peanut Allergy`, etc.)
  - **Intelligent Macro Calculator**: Automatically calculates age/gender/condition-appropriate daily calories, protein, carbs, and fat with manual edit override.
  - Edit & Delete options with confirmation dialogs.

### 2. ⚡ 1-Tap Dashboard Switcher Bar ([dashboard_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/dashboard/dashboard_screen.dart))
- Horizontal scrollable pill bar rendered directly at the top of the dashboard:
  - `[🧑 Me (Self)] [👧 Ayesha] [👴 Abu] [+ Family]`
- Tapping any member instantly adapts the dashboard:
  - Updates the **Calorie Ring** and **Macro Targets** to that dependent's target.
  - Dynamically filters **Today's Meals** to only show meals logged for that family member.

### 3. 🍲 Per-Dependent Meal Logging ([manual_log_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/manual_log_screen.dart) & [scan_meal_screen.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/meal_scan/scan_meal_screen.dart))
- When logging a meal manually or confirming an AI camera scan, a **"Logging for Family Member"** dropdown allows attributing the meal to any family member or the primary account.
- Saves `family_member_id` to Supabase `meal_logs` and local SQLite offline cache.

### 4. ⚙️ Settings Integration ([settings_view.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart))
- Dedicated **Family Profiles** navigation tile in Settings with live count badge.
- Fully localized in English and Urdu Nastaleeq.

---

## 🧪 Verification Results

- `flutter analyze`: **`No issues found!`** (0 errors, 0 warnings).
- `flutter test`: **`All tests passed!`**.
