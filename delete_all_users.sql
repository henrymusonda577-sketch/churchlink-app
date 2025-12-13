-- DELETE ALL USERS FROM SUPABASE
-- This script will permanently delete ALL users and their associated data
-- WARNING: This action cannot be undone!

-- First, delete all related data (this happens automatically due to CASCADE constraints)
-- But to be explicit, let's clean up in order:

-- Delete all posts and related data
DELETE FROM public.posts;
DELETE FROM public.stories;

-- Delete all user badges
DELETE FROM public.user_badges;

-- Delete all chat messages and related data
DELETE FROM public.messages;
DELETE FROM public.message_reactions;
DELETE FROM public.group_message_reactions;
DELETE FROM public.chats;

-- Delete all notifications
DELETE FROM public.notifications;

-- Delete all events
DELETE FROM public.events;

-- Delete all calls
DELETE FROM public.calls;

-- Delete all donations and payouts
DELETE FROM public.donations;
DELETE FROM public.donation_splits;
DELETE FROM public.payout_history;

-- Delete all mobile money transactions
DELETE FROM public.mobile_money_transactions;

-- Delete all wallet subscriptions
DELETE FROM public.wallet_subscriptions;

-- Delete all church members and churches
DELETE FROM public.church_members;
DELETE FROM public.churches;

-- Finally, delete all users from the custom users table
-- (auth.users deletion must be done via Admin API, not SQL)
DELETE FROM public.users;

-- NOTE: To delete from auth.users, you must use the Supabase Admin API
-- This cannot be done with direct SQL. Use the Edge Function approach instead.

-- If you want to run this in Supabase SQL Editor, remove the auth.users part
-- and use the Edge Function I created for the complete deletion.