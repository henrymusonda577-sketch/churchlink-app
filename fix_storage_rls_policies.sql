-- Fix Supabase Storage RLS policies for video uploads
-- Note: This script should be run in Supabase SQL Editor
-- The storage.objects table is managed by Supabase, so we use the proper storage policy syntax

-- Enable RLS on storage.objects (this might already be enabled)
-- Note: In Supabase, storage RLS is handled differently

-- Create policies for the videos bucket
-- Allow authenticated users to upload to videos bucket
DROP POLICY IF EXISTS "videos_bucket_insert" ON storage.objects;
CREATE POLICY "videos_bucket_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'videos' AND auth.role() = 'authenticated'
);

-- Allow authenticated users to view videos
DROP POLICY IF EXISTS "videos_bucket_select" ON storage.objects;
CREATE POLICY "videos_bucket_select" ON storage.objects
FOR SELECT USING (
  bucket_id = 'videos' AND auth.role() = 'authenticated'
);

-- Allow users to update their own videos
DROP POLICY IF EXISTS "videos_bucket_update" ON storage.objects;
CREATE POLICY "videos_bucket_update" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'videos' AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own videos
DROP POLICY IF EXISTS "videos_bucket_delete" ON storage.objects;
CREATE POLICY "videos_bucket_delete" ON storage.objects
FOR DELETE USING (
  bucket_id = 'videos' AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Content videos bucket policies
DROP POLICY IF EXISTS "content_videos_bucket_insert" ON storage.objects;
CREATE POLICY "content_videos_bucket_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'content_videos' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "content_videos_bucket_select" ON storage.objects;
CREATE POLICY "content_videos_bucket_select" ON storage.objects
FOR SELECT USING (
  bucket_id = 'content_videos' AND auth.role() = 'authenticated'
);

-- Audio bucket policies
DROP POLICY IF EXISTS "audio_bucket_insert" ON storage.objects;
CREATE POLICY "audio_bucket_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'audio' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "audio_bucket_select" ON storage.objects;
CREATE POLICY "audio_bucket_select" ON storage.objects
FOR SELECT USING (
  bucket_id = 'audio' AND auth.role() = 'authenticated'
);
-- Posts bucket policies (used by create_post_screen.dart for story images)
DROP POLICY IF EXISTS "posts_bucket_insert" ON storage.objects;
CREATE POLICY "posts_bucket_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'posts' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "posts_bucket_select" ON storage.objects;
CREATE POLICY "posts_bucket_select" ON storage.objects
FOR SELECT USING (
  bucket_id = 'posts' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "posts_bucket_update" ON storage.objects;
CREATE POLICY "posts_bucket_update" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'posts' AND auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "posts_bucket_delete" ON storage.objects;
CREATE POLICY "posts_bucket_delete" ON storage.objects
FOR DELETE USING (
  bucket_id = 'posts' AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Profile pictures bucket policies

-- Profile pictures bucket policies
DROP POLICY IF EXISTS "profile_pictures_bucket_insert" ON storage.objects;
CREATE POLICY "profile_pictures_bucket_insert" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'profile_pictures' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "profile_pictures_bucket_select" ON storage.objects;
CREATE POLICY "profile_pictures_bucket_select" ON storage.objects
FOR SELECT USING (
  bucket_id = 'profile_pictures' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "profile_pictures_bucket_update" ON storage.objects;
CREATE POLICY "profile_pictures_bucket_update" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'profile_pictures' AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Alternative approach: Use Supabase's built-in storage policy functions
-- If the above doesn't work, try this simpler approach:

-- For videos bucket - allow all authenticated users
DROP POLICY IF EXISTS "Allow authenticated uploads to videos" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to videos" ON storage.objects
FOR ALL USING (
  bucket_id = 'videos' AND auth.role() = 'authenticated'
);

-- For content_videos bucket
DROP POLICY IF EXISTS "Allow authenticated uploads to content_videos" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to content_videos" ON storage.objects
FOR ALL USING (
  bucket_id = 'content_videos' AND auth.role() = 'authenticated'
);

-- For audio bucket
DROP POLICY IF EXISTS "Allow authenticated uploads to audio" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to audio" ON storage.objects
FOR ALL USING (
  bucket_id = 'audio' AND auth.role() = 'authenticated'
);

-- For profile_pictures bucket
DROP POLICY IF EXISTS "Allow authenticated uploads to profile_pictures" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to profile_pictures" ON storage.objects
FOR ALL USING (
   bucket_id = 'profile_pictures' AND auth.role() = 'authenticated'
);

-- Chat media bucket policies (for chat images, videos, voice notes)
DROP POLICY IF EXISTS "chat_media_bucket_insert" ON storage.objects;
CREATE POLICY "chat_media_bucket_insert" ON storage.objects
FOR INSERT WITH CHECK (
   bucket_id = 'chat-media' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "chat_media_bucket_select" ON storage.objects;
CREATE POLICY "chat_media_bucket_select" ON storage.objects
FOR SELECT USING (
   bucket_id = 'chat-media' AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "chat_media_bucket_update" ON storage.objects;
CREATE POLICY "chat_media_bucket_update" ON storage.objects
FOR UPDATE USING (
   bucket_id = 'chat-media' AND auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "chat_media_bucket_delete" ON storage.objects;
CREATE POLICY "chat_media_bucket_delete" ON storage.objects
FOR DELETE USING (
   bucket_id = 'chat-media' AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Alternative: Allow all authenticated users to chat-media bucket
DROP POLICY IF EXISTS "Allow authenticated uploads to chat-media" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to chat-media" ON storage.objects
FOR ALL USING (
   bucket_id = 'chat-media' AND auth.role() = 'authenticated'
);

-- Verify policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects';