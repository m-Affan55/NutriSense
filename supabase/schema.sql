-- Supabase Schema for NutriSense AI

-- 1. Profiles Table (extends auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    avatar_url TEXT,
    preferred_language TEXT DEFAULT 'en' CHECK (preferred_language IN ('en', 'ur')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ
);
COMMENT ON TABLE public.profiles IS 'Stores basic user profile information extending Supabase auth.users';

-- 2. Health Profiles Table
CREATE TABLE public.health_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    age INT,
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    weight_kg NUMERIC(5,2),
    height_cm NUMERIC(5,2),
    goal TEXT CHECK (goal IN ('fat_loss', 'muscle_gain', 'maintenance')),
    activity_level TEXT CHECK (activity_level IN ('sedentary', 'lightly_active', 'moderately_active', 'very_active')),
    daily_budget_pkr INT,
    medical_conditions TEXT[],
    dietary_restrictions TEXT[],
    food_preferences TEXT[],
    daily_calorie_target INT,
    daily_protein_g INT,
    daily_carbs_g INT,
    daily_fat_g INT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ
);
COMMENT ON TABLE public.health_profiles IS 'Stores the onboarding medical, physiological, and goal data for the user';

-- 3. Meal Logs Table
CREATE TABLE public.meal_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    logged_at TIMESTAMPTZ DEFAULT now(),
    meal_type TEXT CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    food_items JSONB,
    total_calories INT,
    total_protein_g INT,
    total_carbs_g INT,
    total_fat_g INT,
    photo_url TEXT,
    ai_confidence_score NUMERIC(3,2) CHECK (ai_confidence_score >= 0 AND ai_confidence_score <= 1),
    notes TEXT
);
COMMENT ON TABLE public.meal_logs IS 'Records every meal the user eats along with AI confidence scores and macros';

-- 4. Water Logs Table
CREATE TABLE public.water_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    logged_at TIMESTAMPTZ DEFAULT now(),
    amount_ml INT
);
COMMENT ON TABLE public.water_logs IS 'Daily hydration tracking records';

-- 5. Chat History Table
CREATE TABLE public.chat_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT CHECK (role IN ('user', 'assistant')),
    content TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE public.chat_history IS 'Stores conversational history between the user and the AI coach';

-- Trigger: handle_updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_health_profiles_updated_at
    BEFORE UPDATE ON public.health_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Trigger: handle_new_user (Auto-create profile)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, avatar_url)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'avatar_url');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Row Level Security (RLS) Enable
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can manage their own profile" 
    ON public.profiles FOR ALL 
    USING (auth.uid() = id);

CREATE POLICY "Users can manage their own health profiles" 
    ON public.health_profiles FOR ALL 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own meal logs" 
    ON public.meal_logs FOR ALL 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own water logs" 
    ON public.water_logs FOR ALL 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own chat history" 
    ON public.chat_history FOR ALL 
    USING (auth.uid() = user_id);
