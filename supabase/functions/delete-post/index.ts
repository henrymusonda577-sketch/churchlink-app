import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

interface Post {
  id: string
  user_id: string
  content: string
  post_type: string
  image_url?: string
  video_url?: string
  verse_reference?: string
  tags?: string
  likes: string[]
  comments: any[]
  shares: number
  created_at: string
  updated_at: string
}

Deno.serve(async (req) => {
  if (req.method !== 'DELETE') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  try {
    const url = new URL(req.url)
    const postId = url.searchParams.get('post_id')

    if (!postId) {
      return new Response(JSON.stringify({ error: 'post_id parameter is required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Fetch the post record
    const { data: post, error: fetchError } = await supabase
      .from('posts')
      .select('*')
      .eq('id', postId)
      .single()

    if (fetchError || !post) {
      return new Response(JSON.stringify({ error: 'Post not found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Collect file paths to delete
    const filesToDelete: string[] = []

    if (post.image_url) {
      // Extract path from Supabase storage URL
      // URL format: https://project.supabase.co/storage/v1/object/public/bucket/path
      const imageUrl = new URL(post.image_url)
      const pathParts = imageUrl.pathname.split('/storage/v1/object/public/')
      if (pathParts.length > 1) {
        const bucketAndPath = pathParts[1]
        const [bucket, ...pathParts2] = bucketAndPath.split('/')
        const filePath = pathParts2.join('/')
        filesToDelete.push(`${bucket}/${filePath}`)
      }
    }

    if (post.video_url) {
      const videoUrl = new URL(post.video_url)
      const pathParts = videoUrl.pathname.split('/storage/v1/object/public/')
      if (pathParts.length > 1) {
        const bucketAndPath = pathParts[1]
        const [bucket, ...pathParts2] = bucketAndPath.split('/')
        const filePath = pathParts2.join('/')
        filesToDelete.push(`${bucket}/${filePath}`)
      }
    }

    // Delete files from storage
    for (const filePath of filesToDelete) {
      try {
        const [bucket, ...pathParts] = filePath.split('/')
        const fileName = pathParts.join('/')
        await supabase.storage.from(bucket).remove([fileName])
      } catch (storageError) {
        console.error(`Failed to delete file ${filePath}:`, storageError)
        // Continue with deletion even if file deletion fails
      }
    }

    // Delete the post (this will cascade to related tables)
    const { error: deleteError } = await supabase
      .from('posts')
      .delete()
      .eq('id', postId)

    if (deleteError) {
      return new Response(JSON.stringify({ error: 'Failed to delete post' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Post deleted successfully. Remember to refresh or invalidate the frontend cache to update the feed.'
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})