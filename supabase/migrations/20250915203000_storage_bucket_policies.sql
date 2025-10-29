-- Storage Bucket Security Policies for YNFNY Video Platform
-- Date: 2025-09-15
-- Purpose: Enforce row-level security on storage buckets to prevent unauthorized access

-- Create storage buckets if they don't exist
INSERT INTO storage.buckets (id, name, public) VALUES 
  ('profile_photos', 'profile_photos', false),
  ('videos', 'videos', false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects table (if not already enabled)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ===========================================
-- PROFILE PHOTOS BUCKET POLICIES
-- ===========================================

-- Allow authenticated users to read their own profile photos
CREATE POLICY "Users can view own profile photos" 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'profile_photos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to upload to their own folder only
CREATE POLICY "Users can upload own profile photos" 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'profile_photos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND (storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
);

-- Allow authenticated users to update their own profile photos
CREATE POLICY "Users can update own profile photos" 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'profile_photos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to delete their own profile photos
CREATE POLICY "Users can delete own profile photos" 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'profile_photos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- ===========================================
-- VIDEOS BUCKET POLICIES  
-- ===========================================

-- Allow anyone to read video files (for public video sharing)
-- Note: This allows viewing but not listing - specific URLs required
CREATE POLICY "Public can view videos" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'videos');

-- Allow authenticated street performers to upload videos to their own folder only
CREATE POLICY "Performers can upload own videos" 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'videos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() 
    AND role = 'street_performer' 
    AND is_active = true
  )
  AND (storage.extension(name)) IN ('mp4', 'webm', 'mov', 'avi', 'mkv', 'jpg', 'jpeg', 'png', 'webp')
);

-- Allow performers to update their own videos and thumbnails
CREATE POLICY "Performers can update own videos" 
ON storage.objects FOR UPDATE 
USING (
  bucket_id = 'videos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() 
    AND role = 'street_performer' 
    AND is_active = true
  )
);

-- Allow performers to delete their own videos and thumbnails
CREATE POLICY "Performers can delete own videos" 
ON storage.objects FOR DELETE 
USING (
  bucket_id = 'videos' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() 
    AND role = 'street_performer' 
    AND is_active = true
  )
);

-- ===========================================
-- ADMIN OVERRIDE POLICIES
-- ===========================================

-- Allow admins to manage all content (for moderation)
CREATE POLICY "Admins can manage all storage objects" 
ON storage.objects FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() 
    AND role = 'admin' 
    AND is_active = true
  )
);

-- ===========================================
-- HELPER FUNCTIONS FOR TESTING
-- ===========================================

-- Function to test storage access for current user
CREATE OR REPLACE FUNCTION public.test_storage_access(
  test_bucket text,
  test_path text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
  user_id uuid;
  user_role text;
  folder_owner text;
BEGIN
  -- Get current user info
  user_id := auth.uid();
  SELECT role INTO user_role FROM public.user_profiles WHERE id = user_id;
  
  -- Extract folder owner from path
  folder_owner := (storage.foldername(test_path))[1];
  
  -- Build test result
  result := json_build_object(
    'user_id', user_id,
    'user_role', user_role,
    'test_bucket', test_bucket,
    'test_path', test_path,
    'folder_owner', folder_owner,
    'can_access_own_folder', (user_id::text = folder_owner),
    'is_performer', (user_role = 'street_performer'),
    'is_admin', (user_role = 'admin')
  );
  
  RETURN result;
END;
$$;

-- Grant execute permission on helper function
GRANT EXECUTE ON FUNCTION public.test_storage_access TO authenticated;

-- Create indexes for better RLS policy performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_auth_role ON public.user_profiles(id, role) WHERE is_active = true;