-- Add metadata fields to calls table
ALTER TABLE calls ADD COLUMN IF NOT EXISTS caller_id UUID REFERENCES auth.users(id);
ALTER TABLE calls ADD COLUMN IF NOT EXISTS caller_name TEXT;
ALTER TABLE calls ADD COLUMN IF NOT EXISTS call_type TEXT CHECK (call_type IN ('audio', 'video'));
ALTER TABLE calls ADD COLUMN IF NOT EXISTS participants UUID[];
ALTER TABLE calls ADD COLUMN IF NOT EXISTS group_id TEXT;
ALTER TABLE calls ADD COLUMN IF NOT EXISTS accepted_by UUID REFERENCES auth.users(id);
ALTER TABLE calls ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE calls ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ringing' CHECK (status IN ('ringing', 'accepted', 'declined', 'ended'));

-- Update RLS policies to be more specific
DROP POLICY IF EXISTS "Users can view calls they participate in" ON calls;
CREATE POLICY "Users can view calls they participate in" ON calls
    FOR SELECT USING (auth.uid() = ANY(participants) OR auth.uid() = caller_id);

DROP POLICY IF EXISTS "Users can update calls they participate in" ON calls;
CREATE POLICY "Users can update calls they participate in" ON calls
    FOR UPDATE USING (auth.uid() = ANY(participants) OR auth.uid() = caller_id);

DROP POLICY IF EXISTS "Users can delete calls they participate in" ON calls;
CREATE POLICY "Users can delete calls they participate in" ON calls
    FOR DELETE USING (auth.uid() = ANY(participants) OR auth.uid() = caller_id);