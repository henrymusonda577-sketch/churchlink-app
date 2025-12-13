-- Add referrer_id column to users table for referral tracking
ALTER TABLE users ADD COLUMN IF NOT EXISTS referrer_id UUID REFERENCES users(id);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS users_referrer_id_idx ON users(referrer_id);

-- Add comment for documentation
COMMENT ON COLUMN users.referrer_id IS 'ID of the user who referred this user during signup';