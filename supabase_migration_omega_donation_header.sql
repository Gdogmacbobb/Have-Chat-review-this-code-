-- OMEGA DIAGNOSTICS: Unified Donation Header View + RPC
-- Purpose: Fix 'Failed to load performer information' by centralizing schema logic server-side
-- Run this in your Supabase SQL Editor

-- 1. Create unified VIEW that joins videos + user_profiles with correct column names
CREATE OR REPLACE VIEW public.v_donation_header AS
SELECT
  v.id AS video_id,
  v.performer_id,
  COALESCE(NULLIF(u.full_name, ''), '@' || u.username) AS display_name,
  '@' || u.username AS handle,
  u.profile_image_url AS avatar_url,
  TRIM(BOTH ' ' FROM 
    COALESCE(NULLIF(v.location_name, ''), NULLIF(u.frequent_performance_spots, '')) ||
    CASE WHEN NULLIF(v.borough, '') IS NOT NULL THEN ', ' || v.borough ELSE '' END
  ) AS location_line,
  v.thumbnail_url AS thumb_any
FROM public.videos v
JOIN public.user_profiles u ON u.id = v.performer_id;

-- 2. Create RPC function to fetch single joined record
CREATE OR REPLACE FUNCTION public.donation_header(_video_id uuid, _performer_id uuid)
RETURNS TABLE(
  video_id uuid,
  performer_id uuid,
  display_name text,
  handle text,
  avatar_url text,
  location_line text,
  thumb_any text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT 
    video_id, 
    performer_id, 
    display_name, 
    handle, 
    avatar_url, 
    location_line, 
    thumb_any
  FROM public.v_donation_header
  WHERE video_id = _video_id 
    AND performer_id = _performer_id
  LIMIT 1;
$$;

-- 3. Enable RLS and create policies for public read access
ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
      AND tablename = 'videos' 
      AND policyname = 'videos_public_read'
  ) THEN
    CREATE POLICY videos_public_read ON public.videos 
      FOR SELECT 
      USING (true);  -- Allow public read access to all videos
  END IF;
END $$;

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
      AND tablename = 'user_profiles' 
      AND policyname = 'user_profiles_public_read'
  ) THEN
    CREATE POLICY user_profiles_public_read ON public.user_profiles 
      FOR SELECT 
      USING (true);  -- Allow public read access to user profiles
  END IF;
END $$;

-- 4. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON public.v_donation_header TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.donation_header(uuid, uuid) TO anon, authenticated;

-- Verification: Test the RPC with a known video ID
-- SELECT * FROM donation_header('9392b257-1c26-47b2-b68e-5f2199e1c190'::uuid, '657e9f74-82d3-460a-b3c4-4179d6b880c1'::uuid);
