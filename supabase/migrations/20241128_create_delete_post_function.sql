-- Function to completely delete a post including associated files and related data
CREATE OR REPLACE FUNCTION delete_post_complete(post_id UUID)
RETURNS JSON AS $$
DECLARE
    post_record RECORD;
    file_path TEXT;
    bucket_name TEXT;
    file_name TEXT;
BEGIN
    -- Fetch the post record
    SELECT * INTO post_record
    FROM public.posts
    WHERE id = post_id;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Post not found');
    END IF;

    -- Delete image file if exists
    IF post_record.image_url IS NOT NULL THEN
        -- Extract bucket and file path from Supabase storage URL
        -- URL format: https://project.supabase.co/storage/v1/object/public/bucket/path/to/file
        file_path := substring(post_record.image_url FROM 'storage/v1/object/public/([^/]+)/(.*)');
        IF file_path IS NOT NULL THEN
            bucket_name := split_part(file_path, '/', 1);
            file_name := substr(file_path, length(bucket_name) + 2);
            -- Delete file from storage (this requires proper permissions)
            PERFORM storage.delete(bucket_name, file_name);
        END IF;
    END IF;

    -- Delete video file if exists
    IF post_record.video_url IS NOT NULL THEN
        file_path := substring(post_record.video_url FROM 'storage/v1/object/public/([^/]+)/(.*)');
        IF file_path IS NOT NULL THEN
            bucket_name := split_part(file_path, '/', 1);
            file_name := substr(file_path, length(bucket_name) + 2);
            -- Delete file from storage
            PERFORM storage.delete(bucket_name, file_name);
        END IF;
    END IF;

    -- Delete the post (this will cascade to related tables due to ON DELETE CASCADE)
    DELETE FROM public.posts WHERE id = post_id;

    RETURN json_build_object(
        'success', true,
        'message', 'Post deleted successfully. Remember to refresh or invalidate the frontend cache to update the feed.'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_post_complete(UUID) TO authenticated;