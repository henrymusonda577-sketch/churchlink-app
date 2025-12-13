-- Fix RLS policies for posts to allow likes, comments, and shares
-- This allows authenticated users to update posts for social interactions

-- Drop the restrictive policy
DROP POLICY IF EXISTS "Users can update their own posts" ON public.posts;

-- Create a policy for users to update their own posts
CREATE POLICY "Users can update their own posts" ON public.posts
    FOR UPDATE USING (auth.uid() = user_id);

-- Create a policy for authenticated users to update posts for social interactions
CREATE POLICY "Users can update posts for likes/comments/shares" ON public.posts
    FOR UPDATE USING (auth.uid() IS NOT NULL);