-- DELETE ALL USER DATA FROM PUBLIC TABLES
-- This will delete all user-generated content but keep the users in auth.users
-- Run this in Supabase SQL Editor

-- Delete in reverse dependency order to avoid foreign key violations

-- Delete posts and stories (main goal)
DELETE FROM public.stories;
DELETE FROM public.posts;

-- Delete from users table
DELETE FROM public.users;

-- NOTE: This deletes all posts and user data from public tables but keeps the users in auth.users
-- If you want to delete the auth.users entries too, use the Edge Function approach
-- Other tables like messages, notifications, etc. are not deleted here to avoid errors if they don't exist