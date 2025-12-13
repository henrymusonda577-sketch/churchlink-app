-- Add source column to posts table
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'home';