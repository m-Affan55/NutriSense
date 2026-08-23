-- Migration: 002_family_profiles.sql
-- Description: Creates family_members table and links meal_logs to family members for per-dependent nutrition tracking

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

COMMENT ON TABLE public.family_members IS 'Stores dependents and family profiles managed by the main user';

-- 2. Add family_member_id to meal_logs (nullable, NULL means logged for the primary user)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'meal_logs' 
        AND column_name = 'family_member_id'
    ) THEN
        ALTER TABLE public.meal_logs
        ADD COLUMN family_member_id UUID REFERENCES public.family_members(id) ON DELETE CASCADE;
    END IF;
END $$;

COMMENT ON COLUMN public.meal_logs.family_member_id IS 'References the specific family member this meal was logged for (NULL = logged for primary account user)';

-- 3. Row Level Security (RLS)
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own family members"
    ON public.family_members
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 4. Trigger: handle_updated_at for family_members
CREATE TRIGGER update_family_members_updated_at
    BEFORE UPDATE ON public.family_members
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
