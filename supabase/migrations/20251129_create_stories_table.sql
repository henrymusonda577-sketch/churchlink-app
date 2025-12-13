-- Create stories table
CREATE TABLE IF NOT EXISTS public.stories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT,
    image_url TEXT,
    video_url TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on user_id for better performance
CREATE INDEX IF NOT EXISTS idx_stories_user_id ON public.stories(user_id);

-- Create index on expires_at for efficient cleanup
CREATE INDEX IF NOT EXISTS idx_stories_expires_at ON public.stories(expires_at);

-- Enable RLS
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view all stories (for home feed)
CREATE POLICY "Stories are viewable by everyone" ON public.stories
    FOR SELECT USING (true);

-- Users can insert their own stories
CREATE POLICY "Users can create their own stories" ON public.stories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own stories
CREATE POLICY "Users can update their own stories" ON public.stories
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own stories
CREATE POLICY "Users can delete their own stories" ON public.stories
    FOR DELETE USING (auth.uid() = user_id);

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_stories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function
CREATE TRIGGER trigger_update_stories_updated_at
    BEFORE UPDATE ON public.stories
    FOR EACH ROW
    EXECUTE FUNCTION update_stories_updated_at();