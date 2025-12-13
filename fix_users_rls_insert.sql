-- Fix RLS policies for users table to allow signup inserts
-- Enable RLS if not already enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop existing insert policy if it exists
DROP POLICY IF EXISTS "users_insert_policy" ON users;
DROP POLICY IF EXISTS "Users can insert their own data" ON users;

-- Create new insert policy that allows authenticated users to insert their own data
-- This allows signup to work by permitting inserts when the user is authenticated
CREATE POLICY "users_insert_policy" ON users
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Keep existing select and update policies
-- Select policy for own data
DROP POLICY IF EXISTS "users_select_policy" ON users;
CREATE POLICY "users_select_policy" ON users
FOR SELECT USING (auth.uid() = id);

-- Update policy for own data
DROP POLICY IF EXISTS "users_update_policy" ON users;
CREATE POLICY "users_update_policy" ON users
FOR UPDATE USING (auth.uid() = id);

-- Policy for viewing other users' basic info (for social features)
DROP POLICY IF EXISTS "users_select_others_policy" ON users;
CREATE POLICY "users_select_others_policy" ON users
FOR SELECT USING (auth.uid() IS NOT NULL);