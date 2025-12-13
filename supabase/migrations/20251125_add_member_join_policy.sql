-- Drop existing policy if exists
DROP POLICY IF EXISTS "Users can join churches" ON church_members;

-- Add policy allowing users to manage their own church membership
CREATE POLICY "Users can manage their church membership" ON church_members
    FOR ALL USING (auth.uid() = user_id);