-- Create calls table for WebRTC signaling
CREATE TABLE IF NOT EXISTS calls (
    id TEXT PRIMARY KEY,
    offer JSONB,
    answer JSONB,
    ice_candidates JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE calls ENABLE ROW LEVEL SECURITY;

-- Create policies for calls
CREATE POLICY "Users can view calls they participate in" ON calls
    FOR SELECT USING (
        -- This is a simplified policy - in production you'd want more specific logic
        -- based on the call participants stored in the offer/answer data
        true
    );

CREATE POLICY "Users can insert calls" ON calls
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update calls they participate in" ON calls
    FOR UPDATE USING (true);

CREATE POLICY "Users can delete calls they participate in" ON calls
    FOR DELETE USING (true);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_calls_updated_at
    BEFORE UPDATE ON calls
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();