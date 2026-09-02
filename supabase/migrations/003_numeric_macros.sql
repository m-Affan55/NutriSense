-- Migration 003: Change meal_logs macro columns from INT to NUMERIC
-- Allows accurate decimal nutrition tracking (e.g. 1.5g fat, 22.4g protein) from barcode scans and AI estimates

ALTER TABLE public.meal_logs
  ALTER COLUMN total_calories TYPE NUMERIC USING total_calories::NUMERIC,
  ALTER COLUMN total_protein_g TYPE NUMERIC USING total_protein_g::NUMERIC,
  ALTER COLUMN total_carbs_g TYPE NUMERIC USING total_carbs_g::NUMERIC,
  ALTER COLUMN total_fat_g TYPE NUMERIC USING total_fat_g::NUMERIC;
