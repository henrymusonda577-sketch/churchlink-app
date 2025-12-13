-- SQL Script to completely delete a post
-- Replace 'your-post-id-here' with the actual post ID

DO $$
DECLARE
    post_record RECORD;
    image_path TEXT;
    video_path TEXT;
    post_id UUID := 'your-post-id-here'; -- Replace with actual post ID
BEGIN
    -- Fetch the post record
    SELECT * INTO post_record
    FROM public.posts
    WHERE id = post_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Post not found';
        RETURN;
    END IF;

    -- Store file paths for manual deletion
    image_path := post_record.image_url;
    video_path := post_record.video_url;

    -- Display file paths that need to be deleted manually from Storage
    IF image_path IS NOT NULL THEN
        RAISE NOTICE 'Image file to delete: %', image_path;
    END IF;

    IF video_path IS NOT NULL THEN
        RAISE NOTICE 'Video file to delete: %', video_path;
    END IF;

    -- Delete the post (this will cascade to related tables)
    DELETE FROM public.posts WHERE id = post_id;

    RAISE NOTICE 'Post deleted successfully. Remember to manually delete the files from Supabase Storage and refresh the frontend cache.';

END $$;