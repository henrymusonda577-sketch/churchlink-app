-- Create story_views table for tracking who viewed stories
CREATE TABLE IF NOT EXISTS public.story_views (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    story_id UUID NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(story_id, user_id)
);

-- Enable RLS
ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;

-- RLS Policies for story_views
CREATE POLICY "Users can view story views for their own stories" ON public.story_views
    FOR SELECT USING (auth.uid() = (SELECT user_id FROM public.stories WHERE id = story_id));

CREATE POLICY "Users can insert their own story views" ON public.story_views
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own story views" ON public.story_views
    FOR DELETE USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS story_views_story_id_idx ON public.story_views(story_id);
CREATE INDEX IF NOT EXISTS story_views_user_id_idx ON public.story_views(user_id);
CREATE INDEX IF NOT EXISTS story_views_created_at_idx ON public.story_views(created_at DESC);