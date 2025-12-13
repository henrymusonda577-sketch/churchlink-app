-- Create chats table for individual conversations
CREATE TABLE IF NOT EXISTS chats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chat_id TEXT NOT NULL UNIQUE, -- Unique identifier for the chat (e.g., 'user1_user2')
    participants UUID[] NOT NULL, -- Array of user IDs
    last_message TEXT,
    last_message_type TEXT DEFAULT 'text',
    last_message_sender_id UUID REFERENCES auth.users(id),
    last_message_timestamp TIMESTAMPTZ DEFAULT NOW(),
    unread_counts JSONB DEFAULT '{}', -- JSON object with user_id as key and count as value
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create messages table for individual chat messages
CREATE TABLE IF NOT EXISTS messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chat_id TEXT NOT NULL REFERENCES chats(chat_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    recipient_id UUID NOT NULL REFERENCES auth.users(id),
    message TEXT,
    message_type TEXT DEFAULT 'text',
    media_url TEXT,
    media_path TEXT,
    voice_duration INTEGER,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMPTZ,
    deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    pinned BOOLEAN DEFAULT FALSE,
    pinned_at TIMESTAMPTZ
);

-- Create groups table for group chats
CREATE TABLE IF NOT EXISTS groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id TEXT NOT NULL UNIQUE,
    group_name TEXT,
    group_type TEXT DEFAULT 'church', -- 'church', 'community', etc.
    created_by UUID REFERENCES auth.users(id),
    participants UUID[] DEFAULT '{}',
    last_message TEXT,
    last_message_sender_id UUID REFERENCES auth.users(id),
    last_message_timestamp TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create group_messages table for group chat messages
CREATE TABLE IF NOT EXISTS group_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(group_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    message TEXT,
    message_type TEXT DEFAULT 'text',
    media_url TEXT,
    media_path TEXT,
    voice_duration INTEGER,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMPTZ,
    deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    pinned BOOLEAN DEFAULT FALSE,
    pinned_at TIMESTAMPTZ
);

-- Create typing_indicators table for real-time typing status
CREATE TABLE IF NOT EXISTS typing_indicators (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chat_id TEXT, -- Can be individual chat_id or group_id
    user_id UUID NOT NULL REFERENCES auth.users(id),
    is_typing BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(chat_id, user_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chats_participants ON chats USING GIN (participants);
CREATE INDEX IF NOT EXISTS idx_chats_last_message_timestamp ON chats (last_message_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages (chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages (sender_id);
CREATE INDEX IF NOT EXISTS idx_group_messages_group_id ON group_messages (group_id);
CREATE INDEX IF NOT EXISTS idx_group_messages_timestamp ON group_messages (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_group_messages_sender_id ON group_messages (sender_id);
CREATE INDEX IF NOT EXISTS idx_typing_indicators_chat_id ON typing_indicators (chat_id);
CREATE INDEX IF NOT EXISTS idx_typing_indicators_user_id ON typing_indicators (user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;

-- RLS Policies for chats
CREATE POLICY "Users can view chats they participate in" ON chats
    FOR SELECT USING (auth.uid() = ANY(participants));

CREATE POLICY "Users can insert chats they participate in" ON chats
    FOR INSERT WITH CHECK (auth.uid() = ANY(participants));

CREATE POLICY "Users can update chats they participate in" ON chats
    FOR UPDATE USING (auth.uid() = ANY(participants));

-- RLS Policies for messages
CREATE POLICY "Users can view messages in chats they participate in" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chats
            WHERE chats.chat_id = messages.chat_id
            AND auth.uid() = ANY(chats.participants)
        )
    );

CREATE POLICY "Users can insert messages in chats they participate in" ON messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM chats
            WHERE chats.chat_id = messages.chat_id
            AND auth.uid() = ANY(chats.participants)
        )
    );

CREATE POLICY "Users can update their own messages" ON messages
    FOR UPDATE USING (auth.uid() = sender_id);

-- RLS Policies for groups
CREATE POLICY "Users can view groups they participate in" ON groups
    FOR SELECT USING (auth.uid() = ANY(participants));

CREATE POLICY "Users can insert groups they create" ON groups
    FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update groups they participate in" ON groups
    FOR UPDATE USING (auth.uid() = ANY(participants));

-- RLS Policies for group_messages
CREATE POLICY "Users can view messages in groups they participate in" ON group_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM groups
            WHERE groups.group_id = group_messages.group_id
            AND auth.uid() = ANY(groups.participants)
        )
    );

CREATE POLICY "Users can insert messages in groups they participate in" ON group_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM groups
            WHERE groups.group_id = group_messages.group_id
            AND auth.uid() = ANY(groups.participants)
        )
    );

CREATE POLICY "Users can update their own group messages" ON group_messages
    FOR UPDATE USING (auth.uid() = sender_id);

-- RLS Policies for typing_indicators
CREATE POLICY "Users can view typing indicators in their chats" ON typing_indicators
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chats
            WHERE chats.chat_id = typing_indicators.chat_id
            AND auth.uid() = ANY(chats.participants)
        ) OR
        EXISTS (
            SELECT 1 FROM groups
            WHERE groups.group_id = typing_indicators.chat_id
            AND auth.uid() = ANY(groups.participants)
        )
    );

CREATE POLICY "Users can manage their own typing indicators" ON typing_indicators
    FOR ALL USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_chats_updated_at BEFORE UPDATE ON chats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to update chat last_message when new message is inserted
CREATE OR REPLACE FUNCTION update_chat_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chats
    SET last_message = NEW.message,
        last_message_type = NEW.message_type,
        last_message_sender_id = NEW.sender_id,
        last_message_timestamp = NEW.timestamp,
        unread_counts = jsonb_set(
            COALESCE(unread_counts, '{}'),
            array[NEW.recipient_id::text],
            (COALESCE(unread_counts->>NEW.recipient_id::text, '0')::int + 1)::text::jsonb
        )
    WHERE chat_id = NEW.chat_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updating chat last_message
CREATE TRIGGER trigger_update_chat_last_message
    AFTER INSERT ON messages
    FOR EACH ROW EXECUTE FUNCTION update_chat_last_message();

-- Create function to update group last_message when new group message is inserted
CREATE OR REPLACE FUNCTION update_group_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE groups
    SET last_message = NEW.message,
        last_message_sender_id = NEW.sender_id,
        last_message_timestamp = NEW.timestamp
    WHERE group_id = NEW.group_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updating group last_message
CREATE TRIGGER trigger_update_group_last_message
    AFTER INSERT ON group_messages
    FOR EACH ROW EXECUTE FUNCTION update_group_last_message();
