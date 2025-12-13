-- Drop unique constraint on email in users table to allow multiple users with same email (though Supabase auth prevents this)
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_email_key;