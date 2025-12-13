-- Create user_badges table
CREATE TABLE IF NOT EXISTS user_badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    badge_type TEXT NOT NULL,
    badge_name TEXT NOT NULL,
    badge_description TEXT,
    earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on user_id for faster queries
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON user_badges(user_id);

-- Create index on badge_type for filtering
CREATE INDEX IF NOT EXISTS idx_user_badges_badge_type ON user_badges(badge_type);

-- Enable RLS
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

-- Create policy for users to read their own badges
CREATE POLICY "Users can view their own badges" ON user_badges
    FOR SELECT USING (auth.uid() = user_id);

-- Create policy for users to insert their own badges (though we'll handle this server-side)
CREATE POLICY "Users can insert their own badges" ON user_badges
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create policy for service role to manage all badges
CREATE POLICY "Service role can manage all badges" ON user_badges
    FOR ALL USING (auth.role() = 'service_role');