-- Check current RLS status and policies
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'users' AND schemaname = 'public';

-- Check existing policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'users';

-- Grant permissions to roles (required for RLS to work)
GRANT INSERT ON users TO anon;
GRANT SELECT, UPDATE ON users TO authenticated;

-- If RLS is not enabled, enable it
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Users can view their own data" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;
DROP POLICY IF EXISTS "Users can insert their own data" ON users;
DROP POLICY IF EXISTS "Users can view other users basic info" ON users;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON users;
DROP POLICY IF EXISTS "Enable read access for own data" ON users;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON users;
DROP POLICY IF EXISTS "users_insert_policy" ON users;
DROP POLICY IF EXISTS "users_select_policy" ON users;
DROP POLICY IF EXISTS "users_update_policy" ON users;
DROP POLICY IF EXISTS "users_select_others_policy" ON users;

-- Create new policies with proper auth context
-- Allow authenticated users to insert their own data
CREATE POLICY "users_insert_policy" ON users
FOR INSERT WITH CHECK (auth.uid() = id);

-- Allow users to select their own data
CREATE POLICY "users_select_policy" ON users
FOR SELECT USING (auth.uid() = id);

-- Allow users to update their own data
CREATE POLICY "users_update_policy" ON users
FOR UPDATE USING (auth.uid() = id);

-- Allow authenticated users to view other users' basic info for social features
CREATE POLICY "users_select_others_policy" ON users
FOR SELECT USING (auth.uid() IS NOT NULL);

-- Verify policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'users';
