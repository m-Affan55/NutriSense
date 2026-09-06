-- Migration: 004_family_water_logs.sql
-- Description: Adds family_member_id to water_logs for per-dependent hydration tracking

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'water_logs' 
        AND column_name = 'family_member_id'
    ) THEN
        ALTER TABLE public.water_logs
        ADD COLUMN family_member_id UUID REFERENCES public.family_members(id) ON DELETE CASCADE;
    END IF;
END $$;

COMMENT ON COLUMN public.water_logs.family_member_id IS 'References the specific family member this water was logged for (NULL = primary account user)';
