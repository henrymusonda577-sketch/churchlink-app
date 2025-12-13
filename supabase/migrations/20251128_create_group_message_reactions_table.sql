-- Create group_message_reactions table for storing reactions to group messages
CREATE TABLE IF NOT EXISTS group_message_reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES group_messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL DEFAULT 'love', -- For now, only 'love' is supported
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id, reaction_type) -- Prevent duplicate reactions
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_group_message_reactions_message_id ON group_message_reactions (message_id);
CREATE INDEX IF NOT EXISTS idx_group_message_reactions_user_id ON group_message_reactions (user_id);
CREATE INDEX IF NOT EXISTS idx_group_message_reactions_created_at ON group_message_reactions (created_at DESC);

-- Enable RLS
ALTER TABLE group_message_reactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies - Simplified for now
CREATE POLICY "Users can view their own reactions" ON group_message_reactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can add their own reactions" ON group_message_reactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove their own reactions" ON group_message_reactions
    FOR DELETE USING (auth.uid() = user_id);