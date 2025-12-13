-- Enable RLS on users table (if not already enabled)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view their own data" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;
DROP POLICY IF EXISTS "Users can insert their own data" ON users;
DROP POLICY IF EXISTS "Users can view other users basic info" ON users;

-- Policy: Allow authenticated users to insert their own user data (for signup)
CREATE POLICY "Users can insert their own data" ON users
FOR INSERT WITH CHECK (auth.uid() = id);

-- Policy: Allow users to view their own data
CREATE POLICY "Users can view their own data" ON users
FOR SELECT USING (auth.uid() = id);

-- Policy: Allow users to update their own data
CREATE POLICY "Users can update their own data" ON users
FOR UPDATE USING (auth.uid() = id);

-- Policy: Allow users to view other users' basic public information (name, profile_picture, etc.)
-- This is needed for features like following, messaging, etc.
CREATE POLICY "Users can view other users basic info" ON users
FOR SELECT USING (
  auth.uid() IS NOT NULL AND
  auth.uid() != id
);

-- Optional: If you want to allow public read access to user profiles (remove auth.uid() IS NOT NULL)
-- CREATE POLICY "Public can view user profiles" ON users
-- FOR SELECT USING (true);
