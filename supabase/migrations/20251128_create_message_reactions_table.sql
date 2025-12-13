-- Create message_reactions table for storing reactions to messages
CREATE TABLE IF NOT EXISTS message_reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL DEFAULT 'love', -- For now, only 'love' is supported
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id, reaction_type) -- Prevent duplicate reactions
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id ON message_reactions (message_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_user_id ON message_reactions (user_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_created_at ON message_reactions (created_at DESC);

-- Enable RLS
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view reactions on messages they can see" ON message_reactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM messages m
            JOIN chats c ON c.chat_id = m.chat_id
            WHERE m.id = message_reactions.message_id
            AND auth.uid() = ANY(c.participants)
        )
    );

CREATE POLICY "Users can add reactions to messages they can see" ON message_reactions
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM messages m
            JOIN chats c ON c.chat_id = m.chat_id
            WHERE m.id = message_reactions.message_id
            AND auth.uid() = ANY(c.participants)
        )
    );

CREATE POLICY "Users can remove their own reactions" ON message_reactions
    FOR DELETE USING (auth.uid() = user_id);