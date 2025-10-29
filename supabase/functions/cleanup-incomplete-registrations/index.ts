// Cleanup Incomplete Registrations Edge Function
// Purges both user_profiles AND auth.users for incomplete registrations
// Should be scheduled to run every 15 minutes

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase Admin client (has auth admin privileges)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    console.log('[CLEANUP] Starting incomplete registration cleanup...')

    // Step 1: Call database function to get pending registrations and delete profiles
    const { data: cleanupResult, error: cleanupError } = await supabaseAdmin
      .rpc('cleanup_incomplete_registrations')

    if (cleanupError) {
      console.error('[CLEANUP] Database cleanup failed:', cleanupError)
      throw cleanupError
    }

    console.log('[CLEANUP] Database cleanup result:', cleanupResult)

    const deletedCount = cleanupResult.cleaned || 0
    const userIds = cleanupResult.user_ids || []

    // Step 2: Delete auth accounts for each cleaned user
    const authDeletionResults = []
    for (const userId of userIds) {
      try {
        console.log(`[CLEANUP] Deleting auth account: ${userId}`)
        const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(userId)
        
        if (authError) {
          console.error(`[CLEANUP] Failed to delete auth for ${userId}:`, authError)
          authDeletionResults.push({ userId, success: false, error: authError.message })
        } else {
          console.log(`[CLEANUP] ✅ Auth account deleted: ${userId}`)
          authDeletionResults.push({ userId, success: true })
        }
      } catch (error) {
        console.error(`[CLEANUP] Exception deleting auth for ${userId}:`, error)
        authDeletionResults.push({ userId, success: false, error: error.message })
      }
    }

    const successfulDeletions = authDeletionResults.filter(r => r.success).length
    const failedDeletions = authDeletionResults.filter(r => !r.success).length

    const result = {
      success: true,
      profiles_cleaned: deletedCount,
      auth_deleted: successfulDeletions,
      auth_failed: failedDeletions,
      details: authDeletionResults,
      message: `Cleaned ${deletedCount} profile(s) and ${successfulDeletions} auth account(s). ${failedDeletions} auth deletion(s) failed.`
    }

    console.log('[CLEANUP] Complete:', result)

    return new Response(
      JSON.stringify(result),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    console.error('[CLEANUP] Fatal error:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
        message: 'Cleanup failed'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    )
  }
})
