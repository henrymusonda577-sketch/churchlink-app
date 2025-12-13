-- Create church_members table
CREATE TABLE church_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    church_id UUID REFERENCES churches(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'member' CHECK (role IN ('pastor', 'elder', 'deacon', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(church_id, user_id)
);

-- Enable RLS
ALTER TABLE church_members ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view members of their church" ON church_members
    FOR SELECT USING (
        church_members.user_id = auth.uid() OR
        auth.uid() IN (
            SELECT pastor_id FROM churches WHERE id = church_members.church_id
        )
    );

CREATE POLICY "Pastors can manage church members" ON church_members
    FOR ALL USING (
        auth.uid() IN (
            SELECT pastor_id FROM churches WHERE id = church_members.church_id
        )
    );

-- Create index
CREATE INDEX idx_church_members_church_id ON church_members(church_id);
CREATE INDEX idx_church_members_user_id ON church_members(user_id);