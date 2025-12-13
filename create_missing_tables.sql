-- Create missing database tables for the Flutter app
-- Run this in your Supabase SQL editor

-- Create follows table
CREATE TABLE IF NOT EXISTS follows (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id)
);

-- Create curated_songs table
CREATE TABLE IF NOT EXISTS curated_songs (
    video_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    artist TEXT NOT NULL,
    youtube_url TEXT NOT NULL,
    thumbnail_url TEXT NOT NULL,
    description TEXT,
    type TEXT DEFAULT 'youtube',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create notifications table (if not exists)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    from_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Handle donations table - check if it exists and add missing columns
DO $$
BEGIN
    -- Check if donations table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'donations' AND table_schema = 'public') THEN
        -- Create donations table if it doesn't exist
        CREATE TABLE donations (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
            amount DECIMAL(10,2) NOT NULL,
            currency TEXT DEFAULT 'ZMW',
            payment_method TEXT NOT NULL,
            purpose TEXT NOT NULL,
            message TEXT,
            church_id UUID,
            church_name TEXT,
            status TEXT DEFAULT 'pending',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    ELSE
        -- Add missing columns if table exists but columns don't
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'donations' AND column_name = 'church_name') THEN
            ALTER TABLE donations ADD COLUMN church_name TEXT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'donations' AND column_name = 'church_id') THEN
            ALTER TABLE donations ADD COLUMN church_id UUID;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'donations' AND column_name = 'status') THEN
            ALTER TABLE donations ADD COLUMN status TEXT DEFAULT 'pending';
        END IF;
    END IF;
END $$;

-- Enable RLS on new tables
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE curated_songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE donations ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for follows table
CREATE POLICY "Users can view their own follow relationships" ON follows
    FOR SELECT USING (auth.uid() = follower_id OR auth.uid() = following_id);

CREATE POLICY "Users can create their own follow relationships" ON follows
    FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can delete their own follow relationships" ON follows
    FOR DELETE USING (auth.uid() = follower_id);

-- Create RLS policies for curated_songs table (public read, admin write)
CREATE POLICY "Anyone can view curated songs" ON curated_songs
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can manage curated songs" ON curated_songs
    FOR ALL USING (auth.role() = 'authenticated');

-- Create RLS policies for notifications table
CREATE POLICY "Users can view their own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "System can create notifications" ON notifications
    FOR INSERT WITH CHECK (true);

-- Create RLS policies for donations table
CREATE POLICY "Users can view their own donations" ON donations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own donations" ON donations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Pastors can view donations for their church" ON donations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.role = 'pastor'
            AND users.church_name = donations.church_name
        )
    );

-- Fix users table role constraint to allow 'Member'
-- First drop the existing constraint if it exists
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;

-- Add the corrected constraint
ALTER TABLE users ADD CONSTRAINT users_role_check
    CHECK (role IN ('Member', 'pastor', 'Pastor', 'Elder', 'Bishop', 'Apostle', 'Reverend', 'Minister', 'Evangelist', 'Church Administrator', 'Church Council Member', 'Deacon', 'Youth Leader', 'Worship Leader', 'Choir Director', 'Sunday School Teacher', 'Visitor'));

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON follows(following_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_donations_user_id ON donations(user_id);
CREATE INDEX IF NOT EXISTS idx_donations_church_name ON donations(church_name);
CREATE INDEX IF NOT EXISTS idx_curated_songs_created_at ON curated_songs(created_at DESC);