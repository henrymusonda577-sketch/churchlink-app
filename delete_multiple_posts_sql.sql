-- SQL Script to delete multiple posts
-- Replace the UUIDs in the array with the posts you want to delete

DO $$
DECLARE
    post_ids TEXT[] := ARRAY[
        '7e2aa546-c741-4e12-8e5d-a1774d57f6fd',
        '87c605a3-975b-46d4-ab4d-7f6d4c72ac41',
        '2098bbd6-980c-4322-864f-94230f40f6e0',
        '6de8b307-5b81-491e-8e67-3187904a2326',
        'b49ec64a-c6e7-48bf-bb45-015636003c9d',
        '07d1d02a-340f-40ca-82d9-d3f0d0dd33db'
    ];
    post_record RECORD;
    image_path TEXT;
    video_path TEXT;
    current_id TEXT;
    valid_uuid UUID;
BEGIN
    FOREACH current_id IN ARRAY post_ids
    LOOP
        BEGIN
            -- Try to cast to UUID to validate
            valid_uuid := current_id::UUID;

            -- Fetch the post record
            SELECT * INTO post_record
            FROM public.posts
            WHERE id = valid_uuid;

            IF NOT FOUND THEN
                RAISE NOTICE 'Post % not found, skipping', current_id;
                CONTINUE;
            END IF;

            -- Store file paths for manual deletion
            image_path := post_record.image_url;
            video_path := post_record.video_url;

            -- Display file paths that need to be deleted manually from Storage
            IF image_path IS NOT NULL THEN
                RAISE NOTICE 'Image file to delete for post %: %', current_id, image_path;
            END IF;

            IF video_path IS NOT NULL THEN
                RAISE NOTICE 'Video file to delete for post %: %', current_id, video_path;
            END IF;

            -- Delete the post (this will cascade to related tables)
            DELETE FROM public.posts WHERE id = valid_uuid;

            RAISE NOTICE 'Post % deleted successfully', current_id;

        EXCEPTION
            WHEN invalid_text_representation THEN
                RAISE NOTICE 'Invalid UUID format: %, skipping', current_id;
                CONTINUE;
            WHEN OTHERS THEN
                RAISE NOTICE 'Error processing post %: %, skipping', current_id, SQLERRM;
                CONTINUE;
        END;
    END LOOP;

    RAISE NOTICE 'All posts processed. Remember to manually delete the listed files from Supabase Storage and refresh the frontend cache.';

END $$;