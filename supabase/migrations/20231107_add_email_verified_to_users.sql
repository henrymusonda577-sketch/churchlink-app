-- Add email_verified column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false;

-- Update existing users to be verified if they were created before this feature
-- This is optional and depends on your business logic
-- UPDATE users SET email_verified = true WHERE created_at < '2023-11-07 00:00:00+00';