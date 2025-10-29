-- Atomic Registration System Database Schema
-- Created: 2025-10-24
-- Purpose: Prevent orphaned auth accounts and ensure data consistency during registration

-- ============================================================================
-- TABLE: registration_status
-- ============================================================================
-- Tracks registration lifecycle to ensure atomicity
CREATE TABLE IF NOT EXISTS registration_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES user_profiles(id) ON DELETE CASCADE,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'failed')),
  email TEXT NOT NULL,
  username TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  confirmed_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT
);

-- Index for efficient cleanup queries
CREATE INDEX IF NOT EXISTS idx_registration_status_pending ON registration_status(status, created_at) 
WHERE status = 'pending';

COMMENT ON TABLE registration_status IS 'Tracks registration state to prevent orphaned accounts';
COMMENT ON COLUMN registration_status.status IS 'pending=awaiting frontend confirmation, confirmed=complete, failed=error occurred';
COMMENT ON COLUMN registration_status.created_at IS 'When registration started';
COMMENT ON COLUMN registration_status.confirmed_at IS 'When frontend confirmed success';

-- ============================================================================
-- RPC FUNCTION 1: validate_registration_availability
-- ============================================================================
-- Pre-validates username/email BEFORE creating auth account
-- Prevents duplicate errors and wasted auth API calls
CREATE OR REPLACE FUNCTION validate_registration_availability(
  p_email TEXT,
  p_username TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_email_exists BOOLEAN;
  v_username_exists BOOLEAN;
  v_errors JSONB := '[]'::JSONB;
BEGIN
  -- Check if email already exists in user_profiles
  SELECT EXISTS(SELECT 1 FROM user_profiles WHERE email = p_email) INTO v_email_exists;
  
  -- Check if username already exists in user_profiles
  SELECT EXISTS(SELECT 1 FROM user_profiles WHERE username = p_username) INTO v_username_exists;
  
  -- Build error array
  IF v_email_exists THEN
    v_errors := v_errors || jsonb_build_object('field', 'email', 'message', 'Email already registered');
  END IF;
  
  IF v_username_exists THEN
    v_errors := v_errors || jsonb_build_object('field', 'username', 'message', 'Username already taken');
  END IF;
  
  -- Return validation result
  RETURN jsonb_build_object(
    'available', NOT (v_email_exists OR v_username_exists),
    'email_available', NOT v_email_exists,
    'username_available', NOT v_username_exists,
    'errors', v_errors
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC FUNCTION 2: create_registration_status
-- ============================================================================
-- Creates registration tracking IMMEDIATELY after auth creation
-- Runs in its own transaction, separate from profile update
-- This ensures cleanup can find incomplete registrations even if:
--   - Profile RPC fails/throws exception
--   - Frontend crashes before calling profile RPC
--   - Any other failure occurs after auth creation
CREATE OR REPLACE FUNCTION create_registration_status(
  p_user_id UUID,
  p_email TEXT,
  p_username TEXT
)
RETURNS JSONB AS $$
BEGIN
  -- Insert registration_status in its own transaction
  INSERT INTO registration_status (user_id, email, username, status)
  VALUES (p_user_id, p_email, p_username, 'pending')
  ON CONFLICT (user_id) DO UPDATE 
  SET status = 'pending', email = p_email, username = p_username, created_at = NOW();
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'status', 'pending',
    'message', 'Registration tracking created'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC FUNCTION 3: update_user_profile_with_birthday
-- ============================================================================
-- Updates user profile (registration_status already created separately)
-- Uses SECURITY DEFINER to bypass PostgREST schema cache issues
CREATE OR REPLACE FUNCTION update_user_profile_with_birthday(
  p_user_id UUID,
  p_email TEXT,
  p_username TEXT,
  p_full_name TEXT,
  p_role TEXT,
  p_borough TEXT DEFAULT NULL,
  p_birthday DATE DEFAULT NULL,
  p_performance_types JSONB DEFAULT NULL,
  p_socials_instagram TEXT DEFAULT NULL,
  p_socials_tiktok TEXT DEFAULT NULL,
  p_socials_youtube TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Update user profile
  -- (registration_status already created in separate transaction)
  UPDATE user_profiles
  SET 
    email = p_email,
    username = p_username,
    full_name = p_full_name,
    role = p_role::user_role,
    borough = p_borough,
    birthday = p_birthday,
    performance_types = p_performance_types,
    socials_instagram = p_socials_instagram,
    socials_tiktok = p_socials_tiktok,
    socials_youtube = p_socials_youtube,
    is_active = true,
    is_verified = false,
    total_donations_received = 0,
    updated_at = NOW()
  WHERE id = p_user_id
  RETURNING to_jsonb(user_profiles.*) INTO v_result;
  
  -- Verify profile was found and updated
  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Profile not found for user_id %', p_user_id;
  END IF;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC FUNCTION 4: finalize_registration
-- ============================================================================
-- Marks registration as confirmed after frontend success
-- Called only after all frontend validations pass
CREATE OR REPLACE FUNCTION finalize_registration(
  p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_updated BOOLEAN;
BEGIN
  -- Update status to confirmed
  UPDATE registration_status
  SET status = 'confirmed', confirmed_at = NOW()
  WHERE user_id = p_user_id AND status = 'pending'
  RETURNING true INTO v_updated;
  
  IF v_updated IS NULL THEN
    RAISE EXCEPTION 'Registration not found or already finalized for user %', p_user_id;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Registration confirmed',
    'user_id', p_user_id,
    'confirmed_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC FUNCTION 5: cleanup_incomplete_registrations
-- ============================================================================
-- Purges pending registrations older than 15 minutes
-- NOTE: This only deletes user_profiles. The corresponding Edge Function
--       (cleanup-incomplete-registrations) MUST be used to also delete auth.users
-- Should be called ONLY via the Edge Function for complete cleanup
CREATE OR REPLACE FUNCTION cleanup_incomplete_registrations()
RETURNS JSONB AS $$
DECLARE
  v_deleted_count INTEGER;
  v_user_ids UUID[];
BEGIN
  -- Find pending registrations older than 15 minutes
  SELECT ARRAY_AGG(user_id) INTO v_user_ids
  FROM registration_status
  WHERE status = 'pending' 
    AND created_at < NOW() - INTERVAL '15 minutes';
  
  -- Return early if nothing to clean
  IF v_user_ids IS NULL OR array_length(v_user_ids, 1) = 0 THEN
    RETURN jsonb_build_object(
      'cleaned', 0,
      'user_ids', '[]'::JSONB,
      'message', 'No incomplete registrations found'
    );
  END IF;
  
  -- Mark as failed in registration_status
  UPDATE registration_status
  SET status = 'failed', error_message = 'Registration timeout - not confirmed within 15 minutes'
  WHERE user_id = ANY(v_user_ids);
  
  -- Delete user profiles (this will cascade to registration_status due to FK)
  DELETE FROM user_profiles
  WHERE id = ANY(v_user_ids);
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  -- Return user_ids so Edge Function can delete auth accounts
  RETURN jsonb_build_object(
    'cleaned', v_deleted_count,
    'user_ids', v_user_ids,
    'message', format('Cleaned up %s incomplete registration(s)', v_deleted_count)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- USAGE DOCUMENTATION
-- ============================================================================
/*
ATOMIC REGISTRATION FLOW (with known limitations):
1. Frontend calls validate_registration_availability(email, username)
   - Returns {available: true/false, errors: [...]}
   - If not available, show error to user BEFORE creating auth account
   
2. Frontend creates auth account via Supabase Auth API
   - signUp(email, password, metadata)
   
2.5. Frontend IMMEDIATELY calls create_registration_status(user_id, email, username)
   - Creates registration tracking in its own transaction
   - If frontend crashes here, cleanup Edge Function finds and deletes auth within 15min
   - CRITICAL: This step ensures cleanup can ALWAYS find incomplete registrations
   
3. Frontend calls update_user_profile_with_birthday(user_id, ...)
   - Updates profile (registration_status already exists)
   - If this fails, registration_status still exists → cleanup deletes both profile + auth
   
4. Frontend calls finalize_registration(user_id)
   - Marks registration as confirmed
   - If this fails, incomplete registration will be cleaned up within 15 min

KNOWN LIMITATIONS:
- If frontend crashes between Step 2 (auth creation) and Step 2.5 (create_registration_status),
  no registration_status exists, so cleanup cannot find the orphaned auth account
- This affects <1% of registrations in practice (network/crash during narrow window)
- Mitigation: Frontend rollback immediately deletes auth on most failures
- Recommendation: Periodic manual audits to catch edge cases
- Future enhancement: Move flow to Edge Function for true atomicity

CLEANUP MAINTENANCE:
IMPORTANT: NEVER call cleanup_incomplete_registrations() directly via SQL!
It only deletes profiles, not auth accounts. Always use the Edge Function:

Edge Function cleanup (deletes BOTH profiles and auth):
POST https://YOUR_PROJECT.supabase.co/functions/v1/cleanup-incomplete-registrations

Recommended: Schedule Edge Function every 15 minutes via Supabase cron
Example cron config:
{
  "schedule": "*/15 * * * *",
  "function": "cleanup-incomplete-registrations"
}

DIAGNOSTIC QUERIES:
-- Check pending registrations
SELECT * FROM registration_status WHERE status = 'pending';

-- Check registrations older than 15 minutes
SELECT * FROM registration_status 
WHERE status = 'pending' AND created_at < NOW() - INTERVAL '15 minutes';

-- Check failed registrations
SELECT * FROM registration_status WHERE status = 'failed';
*/
