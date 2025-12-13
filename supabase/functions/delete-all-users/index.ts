import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with service role key for admin operations
    const supabaseAdmin = createClient(
      'https://dsdbbqdcreyevjwysvzq.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzZGJicWRjcmV5ZXZqd3lzdnpxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI3OTIzOCwiZXhwIjoyMDc1ODU1MjM4fQ.HEUHw32Kk81eIC-CbwLCNxnKlCQWwsWdo_JEtKPF_y8',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Get all users from auth.users
    const { data: users, error: listError } = await supabaseAdmin.auth.admin.listUsers()

    if (listError) {
      console.error('Error listing users:', listError)
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Failed to list users',
          error: listError.message
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (!users || users.users.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No users found to delete',
          deletedCount: 0
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`Found ${users.users.length} users to delete`)

    let deletedCount = 0
    let errors = []

    // Delete each user individually (Supabase doesn't have bulk delete for auth users)
    for (const user of users.users) {
      try {
        console.log(`Deleting user: ${user.id} (${user.email})`)

        // Delete user from auth.users - this will cascade delete all related data
        const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id)

        if (deleteError) {
          console.error(`Error deleting user ${user.id}:`, deleteError)
          errors.push({
            userId: user.id,
            email: user.email,
            error: deleteError.message
          })
        } else {
          deletedCount++
          console.log(`Successfully deleted user: ${user.id}`)
        }
      } catch (err) {
        console.error(`Exception deleting user ${user.id}:`, err)
        errors.push({
          userId: user.id,
          email: user.email,
          error: err.message
        })
      }
    }

    const message = errors.length === 0
      ? `Successfully deleted all ${deletedCount} users`
      : `Deleted ${deletedCount} users with ${errors.length} errors`

    return new Response(
      JSON.stringify({
        success: errors.length === 0,
        message,
        deletedCount,
        errors: errors.length > 0 ? errors : undefined
      }),
      {
        status: errors.length === 0 ? 200 : 207, // 207 = Multi-Status (partial success)
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (err) {
    console.error('Unexpected error:', err)
    return new Response(
      JSON.stringify({
        success: false,
        message: 'Unexpected error occurred',
        error: err.message
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})