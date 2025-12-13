-- Add the missing columns to the churches table
ALTER TABLE churches ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS pastor_id UUID REFERENCES auth.users(id);