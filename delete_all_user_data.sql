-- DELETE ALL USER DATA FROM PUBLIC TABLES
-- This will delete all user-generated content but keep the users in auth.users
-- Run this in Supabase SQL Editor

-- Delete in reverse dependency order to avoid foreign key violations

-- Delete story views first
DELETE FROM public.story_views;

-- Delete post interactions
DELETE FROM public.post_likes;
DELETE FROM public.post_comments;

-- Delete posts and stories
DELETE FROM public.stories;
DELETE FROM public.posts;

-- Delete user badges
DELETE FROM public.user_badges;

-- Delete message reactions
DELETE FROM public.message_reactions;
DELETE FROM public.group_message_reactions;

-- Delete messages and chats
DELETE FROM public.messages;
DELETE FROM public.group_messages;
DELETE FROM public.chats;
DELETE FROM public.groups;

-- Delete typing indicators
DELETE FROM public.typing_indicators;

-- Delete notifications
DELETE FROM public.scheduled_notifications;
DELETE FROM public.notification_subscriptions;
DELETE FROM public.notification_preferences;
DELETE FROM public.notifications;

-- Delete events
DELETE FROM public.events;

-- Finally delete from users table
DELETE FROM public.users;

-- NOTE: This deletes all user DATA but keeps the users in auth.users
-- If you want to delete the auth.users entries too, use the Edge Function approach