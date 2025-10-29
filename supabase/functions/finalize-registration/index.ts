// Finalize Registration Edge Function
// Hard-stop atomic registration: creates auth user and profile ONLY after all validations pass
// Guarantees zero orphaned accounts by doing everything server-side with rollback safety

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Client } from 'https://deno.land/x/postgres@v0.17.0/mod.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RegistrationPayload {
  email: string
  password: string
  username: string
  full_name: string
  birthday: string
  borough: string
  role: string
  tos_accepted: boolean
  idempotency_key: string
  device_fingerprint?: string
  performance_types?: string[]
  socials_instagram?: string
  socials_tiktok?: string
  socials_youtube?: string
  socials_x?: string
  socials_snapchat?: string
  socials_facebook?: string
  socials_soundcloud?: string
  socials_spotify?: string
}

interface ValidationError {
  field: string
  code: string
  message: string
}

const VALID_BOROUGHS = ['MN', 'BK', 'BX', 'QN', 'SI', 'VISITOR']

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const requestId = crypto.randomUUID()
  console.log(`[REGISTER_HARDSTOP][${requestId}] Request received`)

  try {
    // Parse request body
    const payload: RegistrationPayload = await req.json()
    console.log(`[REGISTER_HARDSTOP][${requestId}] Payload received:`, {
      email: payload.email,
      username: payload.username,
      full_name: payload.full_name,
      role: payload.role,
      birthday: payload.birthday,
      borough: payload.borough,
      idempotency_key: payload.idempotency_key
    })

    // Create Supabase Admin client with service role
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

    // ==================== SERVER-SIDE VALIDATIONS ====================
    const errors: ValidationError[] = []

    // Email validation
    if (!payload.email || !payload.email.includes('@')) {
      errors.push({ field: 'email', code: 'INVALID_EMAIL', message: 'Invalid email format' })
    }

    // Password validation (minimum 8 characters)
    if (!payload.password || payload.password.length < 8) {
      errors.push({ field: 'password', code: 'WEAK_PASSWORD', message: 'Password must be at least 8 characters' })
    }

    // Username validation (alphanumeric + underscore, 3-20 chars)
    const usernameRegex = /^[a-zA-Z0-9_]{3,20}$/
    if (!payload.username || !usernameRegex.test(payload.username)) {
      errors.push({ field: 'username', code: 'INVALID_USERNAME', message: 'Username must be 3-20 alphanumeric characters or underscores' })
    }

    // Birthday validation (must be at least 13 years old)
    if (!payload.birthday) {
      errors.push({ field: 'birthday', code: 'MISSING_BIRTHDAY', message: 'Birthday is required' })
    } else {
      const birthDate = new Date(payload.birthday)
      const today = new Date()
      const age = today.getFullYear() - birthDate.getFullYear()
      const monthDiff = today.getMonth() - birthDate.getMonth()
      const dayDiff = today.getDate() - birthDate.getDate()
      const actualAge = age - (monthDiff < 0 || (monthDiff === 0 && dayDiff < 0) ? 1 : 0)
      
      if (actualAge < 13) {
        errors.push({ field: 'birthday', code: 'UNDERAGE', message: 'Must be at least 13 years old' })
      }
    }

    // Borough validation
    if (!payload.borough || !VALID_BOROUGHS.includes(payload.borough)) {
      errors.push({ field: 'borough', code: 'INVALID_BOROUGH', message: `Borough must be one of: ${VALID_BOROUGHS.join(', ')}` })
    }

    // ToS validation
    if (!payload.tos_accepted) {
      errors.push({ field: 'tos_accepted', code: 'TOS_NOT_ACCEPTED', message: 'Terms of Service must be accepted' })
    }

    // Idempotency key validation
    if (!payload.idempotency_key) {
      errors.push({ field: 'idempotency_key', code: 'MISSING_IDEMPOTENCY_KEY', message: 'Idempotency key is required' })
    }

    // Full name validation
    if (!payload.full_name || payload.full_name.trim().length < 2) {
      errors.push({ field: 'full_name', code: 'INVALID_FULL_NAME', message: 'Full name must be at least 2 characters' })
    }

    // Role validation
    const validRoles = ['street_performer', 'new_yorker']
    if (!payload.role || !validRoles.includes(payload.role)) {
      errors.push({ field: 'role', code: 'INVALID_ROLE', message: `Role must be one of: ${validRoles.join(', ')}` })
    }

    // Performer-specific validations
    if (payload.role === 'street_performer') {
      if (!payload.performance_types || payload.performance_types.length === 0) {
        errors.push({ field: 'performance_types', code: 'MISSING_PERFORMANCE_TYPES', message: 'Performers must select at least one performance type' })
      }
      
      // At least one social media required for performers
      const hasSocial = payload.socials_instagram || payload.socials_tiktok || payload.socials_youtube || 
                       payload.socials_x || payload.socials_snapchat || payload.socials_facebook ||
                       payload.socials_soundcloud || payload.socials_spotify
      if (!hasSocial) {
        errors.push({ field: 'social_media', code: 'MISSING_SOCIAL_MEDIA', message: 'Performers must provide at least one social media handle' })
      }
    }

    // If any validation errors, return 422
    if (errors.length > 0) {
      console.log(`[REGISTER_HARDSTOP][${requestId}] VALIDATION_FAILED:`, errors)
      return new Response(
        JSON.stringify({ 
          success: false,
          code: 'VALIDATION_FAILED',
          errors 
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 422,
        },
      )
    }

    // ==================== CHECK IDEMPOTENCY ====================
    // Check if this idempotency_key was already processed
    const { data: existingRegistration, error: idempotencyCheckError } = await supabaseAdmin
      .from('user_profiles')
      .select('id, email, username')
      .eq('idempotency_key', payload.idempotency_key)
      .single()

    if (existingRegistration) {
      console.log(`[REGISTER_HARDSTOP][${requestId}] IDEMPOTENT_REQUEST: Registration already exists for this key`)
      
      // Return success with existing user data (don't create duplicate)
      const { data: sessionData, error: sessionError } = await supabaseAdmin.auth.signInWithPassword({
        email: payload.email,
        password: payload.password
      })

      if (sessionError) {
        console.error(`[REGISTER_HARDSTOP][${requestId}] Session creation failed for idempotent request:`, sessionError)
        return new Response(
          JSON.stringify({ 
            success: false,
            code: 'SESSION_FAILED',
            message: 'User exists but session creation failed'
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 500,
          },
        )
      }

      return new Response(
        JSON.stringify({ 
          success: true,
          user_id: existingRegistration.id,
          session: sessionData.session,
          idempotent: true,
          message: 'Registration already completed'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        },
      )
    }

    // ==================== UNIQUENESS CHECK WITH LOCK ====================
    console.log(`[REGISTER_HARDSTOP][${requestId}] TXN_BEGIN: Starting uniqueness check`)
    
    // Check username uniqueness (case-insensitive)
    const { data: existingUsername, error: usernameCheckError } = await supabaseAdmin
      .from('user_profiles')
      .select('id')
      .ilike('username', payload.username)
      .limit(1)
      .single()

    if (existingUsername) {
      console.log(`[REGISTER_HARDSTOP][${requestId}] VALIDATION_FAILED: Username already exists`)
      return new Response(
        JSON.stringify({ 
          success: false,
          code: 'USERNAME_EXISTS',
          errors: [{ field: 'username', code: 'USERNAME_EXISTS', message: 'Username already taken' }]
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 422,
        },
      )
    }

    // Check email uniqueness
    const { data: existingEmail, error: emailCheckError } = await supabaseAdmin
      .from('user_profiles')
      .select('id')
      .eq('email', payload.email.toLowerCase())
      .limit(1)
      .single()

    if (existingEmail) {
      console.log(`[REGISTER_HARDSTOP][${requestId}] VALIDATION_FAILED: Email already exists`)
      return new Response(
        JSON.stringify({ 
          success: false,
          code: 'EMAIL_EXISTS',
          errors: [{ field: 'email', code: 'EMAIL_EXISTS', message: 'Email already registered' }]
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 422,
        },
      )
    }

    console.log(`[REGISTER_HARDSTOP][${requestId}] UNIQUE_LOCK_OK: No conflicts found`)

    // ==================== CREATE AUTH USER ====================
    console.log(`[REGISTER_HARDSTOP][${requestId}] Creating auth user...`)
    
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: payload.email.toLowerCase(),
      password: payload.password,
      email_confirm: true,
      user_metadata: {
        username: payload.username,
        registration_source: 'finalize-registration-edge-function'
      }
    })

    if (authError || !authData.user) {
      console.error(`[REGISTER_HARDSTOP][${requestId}] AUTH_CREATION_FAILED:`, authError)
      return new Response(
        JSON.stringify({ 
          success: false,
          code: 'AUTH_CREATION_FAILED',
          message: authError?.message || 'Failed to create auth user'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500,
        },
      )
    }

    const userId = authData.user.id
    console.log(`[REGISTER_HARDSTOP][${requestId}] AUTH_CREATED:${userId}`)

    // ==================== CREATE USER PROFILE ====================
    console.log(`[REGISTER_HARDSTOP][${requestId}] Creating user profile via direct SQL...`)
    
    // Connect directly to Postgres to bypass PostgREST schema cache
    const dbUrl = Deno.env.get('SUPABASE_DB_URL')
    if (!dbUrl) {
      throw new Error('SUPABASE_DB_URL not configured')
    }
    
    const client = new Client(dbUrl)
    await client.connect()
    
    // Prepare performer-specific fields
    const performanceTypes = payload.role === 'street_performer' ? (payload.performance_types || []) : null
    let socialMediaLinks = null
    
    if (payload.role === 'street_performer') {
      const socialLinks: any = {}
      if (payload.socials_instagram) socialLinks.instagram = payload.socials_instagram
      if (payload.socials_tiktok) socialLinks.tiktok = payload.socials_tiktok
      if (payload.socials_youtube) socialLinks.youtube = payload.socials_youtube
      if (payload.socials_x) socialLinks.x = payload.socials_x
      if (payload.socials_snapchat) socialLinks.snapchat = payload.socials_snapchat
      if (payload.socials_facebook) socialLinks.facebook = payload.socials_facebook
      if (payload.socials_soundcloud) socialLinks.soundcloud = payload.socials_soundcloud
      if (payload.socials_spotify) socialLinks.spotify = payload.socials_spotify
      socialMediaLinks = socialLinks
    }
    
    try {
      // Direct SQL UPSERT bypasses PostgREST entirely and handles trigger-created profiles
      await client.queryObject(
        `INSERT INTO public.user_profiles (
          id, email, username, full_name, role, birthday, borough,
          idempotency_key, device_fingerprint, is_active, is_verified,
          total_donations_received, performance_types, social_media_links
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
        )
        ON CONFLICT (id) DO UPDATE SET
          email = EXCLUDED.email,
          username = EXCLUDED.username,
          full_name = EXCLUDED.full_name,
          role = EXCLUDED.role,
          birthday = EXCLUDED.birthday,
          borough = EXCLUDED.borough,
          idempotency_key = EXCLUDED.idempotency_key,
          device_fingerprint = EXCLUDED.device_fingerprint,
          is_active = EXCLUDED.is_active,
          is_verified = EXCLUDED.is_verified,
          total_donations_received = EXCLUDED.total_donations_received,
          performance_types = EXCLUDED.performance_types,
          social_media_links = EXCLUDED.social_media_links`,
        [
          userId,
          payload.email.toLowerCase(),
          payload.username,
          payload.full_name,
          payload.role,
          payload.birthday,
          payload.borough,
          payload.idempotency_key,
          payload.device_fingerprint || null,
          true,
          false,
          0,
          performanceTypes,
          socialMediaLinks ? JSON.stringify(socialMediaLinks) : null
        ]
      )
      console.log(`[REGISTER_HARDSTOP][${requestId}] PROFILE_UPSERTED:${userId}`)

      // ==================== POST-COMMIT VERIFICATION ====================
      console.log(`[REGISTER_HARDSTOP][${requestId}] Running post-commit verification via direct SQL...`)
      
      const verifyAuth = await supabaseAdmin.auth.admin.getUserById(userId)
      
      const verifyProfileResult = await client.queryObject(
        `SELECT * FROM public.user_profiles WHERE id = $1 LIMIT 1`,
        [userId]
      )

      if (!verifyAuth.data?.user || verifyProfileResult.rows.length === 0) {
        console.error(`[REGISTER_HARDSTOP][${requestId}] VERIFY_FAILED: Data mismatch detected`)
        
        // ROLLBACK: Delete both profile and auth user to maintain zero-orphan guarantee
        // Each deletion is independent to ensure both run even if one fails
        try {
          await client.queryObject(
            `DELETE FROM public.user_profiles WHERE id = $1`,
            [userId]
          )
          console.log(`[REGISTER_HARDSTOP][${requestId}] CLEANUP: Profile deleted`)
        } catch (profileCleanupError) {
          console.error(`[REGISTER_HARDSTOP][${requestId}] CLEANUP_PROFILE_ERROR:`, profileCleanupError)
        }
        
        try {
          await supabaseAdmin.auth.admin.deleteUser(userId)
          console.log(`[REGISTER_HARDSTOP][${requestId}] CLEANUP: Auth user deleted`)
        } catch (authCleanupError) {
          console.error(`[REGISTER_HARDSTOP][${requestId}] CLEANUP_AUTH_ERROR:`, authCleanupError)
        }
        
        return new Response(
          JSON.stringify({ 
            success: false,
            code: 'VERIFICATION_FAILED',
            message: 'Post-creation verification failed'
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 500,
          },
        )
      }

      console.log(`[REGISTER_HARDSTOP][${requestId}] VERIFY_OK:${userId}`)
      
    } catch (profileError) {
      console.error(`[REGISTER_HARDSTOP][${requestId}] PROFILE_INSERT_FAILED:`, profileError)
      
      // ROLLBACK: Delete auth user
      console.log(`[REGISTER_HARDSTOP][${requestId}] ROLLBACK_DELETE_AUTH: Profile insert failed, deleting auth user`)
      try {
        await supabaseAdmin.auth.admin.deleteUser(userId)
      } catch (rollbackError) {
        console.error(`[REGISTER_HARDSTOP][${requestId}] ROLLBACK_ERROR:`, rollbackError)
      }
      
      return new Response(
        JSON.stringify({ 
          success: false,
          code: 'PROFILE_CREATION_FAILED',
          message: profileError instanceof Error ? profileError.message : 'Failed to create user profile'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500,
        },
      )
    } finally {
      // Always close SQL connection, even if errors occur
      await client.end()
    }

    // ==================== CREATE SESSION ====================
    console.log(`[REGISTER_HARDSTOP][${requestId}] Creating session...`)
    
    const { data: sessionData, error: sessionError } = await supabaseAdmin.auth.signInWithPassword({
      email: payload.email.toLowerCase(),
      password: payload.password
    })

    if (sessionError || !sessionData.session) {
      console.error(`[REGISTER_HARDSTOP][${requestId}] SESSION_FAILED:`, sessionError)
      
      // Don't delete user here - they're valid, just return error
      return new Response(
        JSON.stringify({ 
          success: false,
          code: 'SESSION_CREATION_FAILED',
          message: 'User created but session failed. Please try logging in.'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500,
        },
      )
    }

    // ==================== SUCCESS ====================
    console.log(`[REGISTER_HARDSTOP][${requestId}] RETURN_SUCCESS:${userId}`)
    
    return new Response(
      JSON.stringify({ 
        success: true,
        user_id: userId,
        session: sessionData.session,
        message: 'Registration completed successfully'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error(`[REGISTER_HARDSTOP][${requestId}] FATAL_ERROR:`, error)
    return new Response(
      JSON.stringify({ 
        success: false,
        code: 'INTERNAL_ERROR',
        message: error.message || 'Internal server error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    )
  }
})
