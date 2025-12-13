-- Fix story_views foreign key to reference public.users instead of auth.users
-- This allows proper joins in client queries

-- First drop the existing foreign key constraint
ALTER TABLE public.story_views DROP CONSTRAINT IF EXISTS story_views_user_id_fkey;

-- Add the correct foreign key constraint to public.users
ALTER TABLE public.story_views ADD CONSTRAINT story_views_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Update the RLS policy to work with the corrected relationship
DROP POLICY IF EXISTS "Users can view story views for their own stories" ON public.story_views;
CREATE POLICY "Users can view story views for their own stories" ON public.story_views
    FOR SELECT USING (auth.uid() = (SELECT user_id FROM public.stories WHERE id = story_id));

-- The insert and delete policies remain the same
DROP POLICY IF EXISTS "Users can insert their own story views" ON public.story_views;
CREATE POLICY "Users can insert their own story views" ON public.story_views
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own story views" ON public.story_views;
CREATE POLICY "Users can delete their own story views" ON public.story_views
    FOR DELETE USING (auth.uid() = user_id);