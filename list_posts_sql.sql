-- Query to list all posts with their IDs and basic info
-- Run this first to find the post UUID you want to delete

SELECT
    id,
    content,
    post_type,
    user_id,
    created_at,
    image_url,
    video_url
FROM public.posts
ORDER BY created_at DESC
LIMIT 50; -- Adjust limit as needed