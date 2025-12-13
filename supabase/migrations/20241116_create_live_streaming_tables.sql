-- Create live_streams table
CREATE TABLE IF NOT EXISTS live_streams (
    id TEXT PRIMARY KEY,
    broadcaster_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    broadcaster_name TEXT NOT NULL,
    audience TEXT NOT NULL CHECK (audience IN ('everyone', 'church_members')),
    church_id UUID REFERENCES churches(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'ended', 'paused')),
    viewer_count INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    stream_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create stream_viewers table
CREATE TABLE IF NOT EXISTS stream_viewers (
    id SERIAL PRIMARY KEY,
    stream_id TEXT NOT NULL REFERENCES live_streams(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    viewer_name TEXT NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    UNIQUE(stream_id, viewer_id)
);

-- Create stream_chat table
CREATE TABLE IF NOT EXISTS stream_chat (
    id SERIAL PRIMARY KEY,
    stream_id TEXT NOT NULL REFERENCES live_streams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    message TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_live_streams_status ON live_streams(status);
CREATE INDEX IF NOT EXISTS idx_live_streams_broadcaster ON live_streams(broadcaster_id);
CREATE INDEX IF NOT EXISTS idx_live_streams_church ON live_streams(church_id);
CREATE INDEX IF NOT EXISTS idx_stream_viewers_stream ON stream_viewers(stream_id);
CREATE INDEX IF NOT EXISTS idx_stream_viewers_viewer ON stream_viewers(viewer_id);
CREATE INDEX IF NOT EXISTS idx_stream_chat_stream ON stream_chat(stream_id);
CREATE INDEX IF NOT EXISTS idx_stream_chat_timestamp ON stream_chat(timestamp);

-- Enable RLS
ALTER TABLE live_streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_viewers ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_chat ENABLE ROW LEVEL SECURITY;

-- RLS Policies for live_streams
CREATE POLICY "Anyone can view active live streams" ON live_streams
    FOR SELECT USING (status = 'active');

CREATE POLICY "Users can create their own live streams" ON live_streams
    FOR INSERT WITH CHECK (auth.uid() = broadcaster_id);

CREATE POLICY "Broadcasters can update their own streams" ON live_streams
    FOR UPDATE USING (auth.uid() = broadcaster_id);

-- RLS Policies for stream_viewers
CREATE POLICY "Viewers can view stream viewers" ON stream_viewers
    FOR SELECT USING (true);

CREATE POLICY "Users can join streams as viewers" ON stream_viewers
    FOR INSERT WITH CHECK (auth.uid() = viewer_id);

CREATE POLICY "Users can leave streams" ON stream_viewers
    FOR DELETE USING (auth.uid() = viewer_id);

-- RLS Policies for stream_chat
CREATE POLICY "Anyone can view stream chat messages" ON stream_chat
    FOR SELECT USING (true);

CREATE POLICY "Users can send chat messages" ON stream_chat
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update updated_at
CREATE TRIGGER update_live_streams_updated_at
    BEFORE UPDATE ON live_streams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();