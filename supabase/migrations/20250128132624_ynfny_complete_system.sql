-- Location: supabase/migrations/20250128132624_ynfny_complete_system.sql
-- YNFNY Social Media Platform - Complete System Migration
-- Implements street performer discovery app with role-based access, video content, and donations

-- 1. Extensions and Types
CREATE TYPE public.user_role AS ENUM ('street_performer', 'new_yorker', 'admin');
CREATE TYPE public.performance_type AS ENUM ('singer', 'dancer', 'magician', 'musician', 'artist', 'other');
CREATE TYPE public.verification_status AS ENUM ('pending', 'approved', 'rejected', 'under_review');
CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'failed', 'refunded');

-- 2. User Profiles Table (Required for PostgREST compatibility)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    role public.user_role DEFAULT 'new_yorker'::public.user_role,
    profile_image_url TEXT,
    bio TEXT,
    
    -- Street Performer specific fields
    performance_type public.performance_type,
    frequent_performance_spots TEXT,
    social_media_links JSONB DEFAULT '{}'::JSONB,
    verification_status public.verification_status DEFAULT 'pending'::public.verification_status,
    verification_photo_url TEXT,
    total_donations_received DECIMAL(10,2) DEFAULT 0.00,
    
    -- Account status
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Video Content Table
CREATE TABLE public.videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    performer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    duration INTEGER NOT NULL, -- in seconds
    
    -- Location data (NYC geofencing requirement)
    location_latitude DOUBLE PRECISION NOT NULL,
    location_longitude DOUBLE PRECISION NOT NULL,
    location_name TEXT,
    borough TEXT NOT NULL CHECK (borough IN ('Manhattan', 'Brooklyn', 'Queens', 'Bronx', 'Staten Island')),
    
    -- Engagement metrics
    view_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    share_count INTEGER DEFAULT 0,
    
    -- Content moderation
    is_approved BOOLEAN DEFAULT false,
    is_flagged BOOLEAN DEFAULT false,
    moderation_notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Video Interactions Table
CREATE TABLE public.video_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    interaction_type TEXT NOT NULL CHECK (interaction_type IN ('like', 'view', 'share')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, video_id, interaction_type)
);

-- 5. Comments Table
CREATE TABLE public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_flagged BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 6. Follows Table
CREATE TABLE public.follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id)
);

-- 7. Donations Table
CREATE TABLE public.donations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    performer_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    video_id UUID REFERENCES public.videos(id) ON DELETE SET NULL,
    
    -- Payment details
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    currency TEXT DEFAULT 'USD',
    stripe_payment_intent_id TEXT UNIQUE,
    transaction_status public.transaction_status DEFAULT 'pending'::public.transaction_status,
    
    -- Platform fee (5%)
    platform_fee DECIMAL(10,2) NOT NULL,
    performer_amount DECIMAL(10,2) NOT NULL,
    
    -- Optional message from donor
    message TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ
);

-- 8. Reposts Table (New Yorkers sharing performer content)
CREATE TABLE public.reposts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    caption TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, video_id)
);

-- 9. Notifications Table
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow', 'donation', 'verification', 'new_video')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}'::JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 10. Essential Indexes
CREATE INDEX idx_user_profiles_username ON public.user_profiles(username);
CREATE INDEX idx_user_profiles_role ON public.user_profiles(role);
CREATE INDEX idx_user_profiles_verification_status ON public.user_profiles(verification_status);

CREATE INDEX idx_videos_performer_id ON public.videos(performer_id);
CREATE INDEX idx_videos_created_at ON public.videos(created_at DESC);
CREATE INDEX idx_videos_borough ON public.videos(borough);
CREATE INDEX idx_videos_approved ON public.videos(is_approved);

CREATE INDEX idx_video_interactions_user_video ON public.video_interactions(user_id, video_id);
CREATE INDEX idx_video_interactions_video_type ON public.video_interactions(video_id, interaction_type);

CREATE INDEX idx_comments_video_id ON public.comments(video_id);
CREATE INDEX idx_comments_user_id ON public.comments(user_id);

CREATE INDEX idx_follows_follower_id ON public.follows(follower_id);
CREATE INDEX idx_follows_following_id ON public.follows(following_id);

CREATE INDEX idx_donations_performer_id ON public.donations(performer_id);
CREATE INDEX idx_donations_donor_id ON public.donations(donor_id);
CREATE INDEX idx_donations_status ON public.donations(transaction_status);

CREATE INDEX idx_reposts_user_id ON public.reposts(user_id);
CREATE INDEX idx_reposts_video_id ON public.reposts(video_id);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_unread ON public.notifications(user_id, is_read);

-- 11. Enable Row Level Security
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reposts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 12. Helper Functions for RLS Policies
CREATE OR REPLACE FUNCTION public.is_performer()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() AND up.role = 'street_performer'::public.user_role
)
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() AND up.role = 'admin'::public.user_role
)
$$;

CREATE OR REPLACE FUNCTION public.can_view_video(video_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.videos v
    WHERE v.id = video_uuid AND (v.is_approved = true OR v.performer_id = auth.uid())
)
$$;

CREATE OR REPLACE FUNCTION public.owns_video(video_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.videos v
    WHERE v.id = video_uuid AND v.performer_id = auth.uid()
)
$$;

-- 13. RLS Policies
-- User Profiles: Users can view approved profiles, manage their own
CREATE POLICY "public_can_view_active_profiles"
ON public.user_profiles
FOR SELECT
TO public
USING (is_active = true AND (is_verified = true OR role = 'street_performer'::public.user_role));

CREATE POLICY "users_manage_own_profile"
ON public.user_profiles
FOR ALL
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "admins_manage_all_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Videos: Public can view approved videos, performers manage their own
CREATE POLICY "public_can_view_approved_videos"
ON public.videos
FOR SELECT
TO public
USING (is_approved = true AND NOT is_flagged);

CREATE POLICY "performers_manage_own_videos"
ON public.videos
FOR ALL
TO authenticated
USING (public.owns_video(id) OR public.is_admin())
WITH CHECK (performer_id = auth.uid() OR public.is_admin());

-- Video Interactions: Users can interact with viewable videos
CREATE POLICY "users_manage_own_interactions"
ON public.video_interactions
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid() AND public.can_view_video(video_id));

-- Comments: Users can comment on viewable videos, manage their own comments
CREATE POLICY "public_can_view_comments"
ON public.comments
FOR SELECT
TO public
USING (NOT is_flagged AND public.can_view_video(video_id));

CREATE POLICY "authenticated_users_can_comment"
ON public.comments
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid() AND public.can_view_video(video_id));

CREATE POLICY "users_manage_own_comments"
ON public.comments
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_delete_own_comments"
ON public.comments
FOR DELETE
TO authenticated
USING (user_id = auth.uid() OR public.is_admin());

-- Follows: Users can manage their own follow relationships
CREATE POLICY "users_manage_own_follows"
ON public.follows
FOR ALL
TO authenticated
USING (follower_id = auth.uid())
WITH CHECK (follower_id = auth.uid());

CREATE POLICY "public_can_view_follows"
ON public.follows
FOR SELECT
TO public
USING (true);

-- Donations: Transparent for participants, protected from others
CREATE POLICY "participants_can_view_donations"
ON public.donations
FOR SELECT
TO authenticated
USING (donor_id = auth.uid() OR performer_id = auth.uid() OR public.is_admin());

CREATE POLICY "authenticated_users_can_donate"
ON public.donations
FOR INSERT
TO authenticated
WITH CHECK (donor_id = auth.uid());

CREATE POLICY "system_can_update_donations"
ON public.donations
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Reposts: Users manage their own reposts
CREATE POLICY "public_can_view_reposts"
ON public.reposts
FOR SELECT
TO public
USING (public.can_view_video(video_id));

CREATE POLICY "users_manage_own_reposts"
ON public.reposts
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid() AND public.can_view_video(video_id));

-- Notifications: Users see only their own notifications
CREATE POLICY "users_manage_own_notifications"
ON public.notifications
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 14. Triggers and Functions
-- Auto-create user profile on auth user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, username, full_name, role)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'new_yorker'::public.user_role)
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Update video engagement counts
CREATE OR REPLACE FUNCTION public.update_video_engagement()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.videos 
    SET 
      like_count = CASE WHEN NEW.interaction_type = 'like' THEN like_count + 1 ELSE like_count END,
      view_count = CASE WHEN NEW.interaction_type = 'view' THEN view_count + 1 ELSE view_count END,
      share_count = CASE WHEN NEW.interaction_type = 'share' THEN share_count + 1 ELSE share_count END,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.video_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.videos 
    SET 
      like_count = CASE WHEN OLD.interaction_type = 'like' THEN GREATEST(like_count - 1, 0) ELSE like_count END,
      view_count = CASE WHEN OLD.interaction_type = 'view' THEN GREATEST(view_count - 1, 0) ELSE view_count END,
      share_count = CASE WHEN OLD.interaction_type = 'share' THEN GREATEST(share_count - 1, 0) ELSE share_count END,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.video_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER video_engagement_trigger
  AFTER INSERT OR DELETE ON public.video_interactions
  FOR EACH ROW EXECUTE FUNCTION public.update_video_engagement();

-- Update comment counts
CREATE OR REPLACE FUNCTION public.update_comment_count()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.videos 
    SET comment_count = comment_count + 1, updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.video_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.videos 
    SET comment_count = GREATEST(comment_count - 1, 0), updated_at = CURRENT_TIMESTAMP
    WHERE id = OLD.video_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER comment_count_trigger
  AFTER INSERT OR DELETE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.update_comment_count();

-- Calculate platform fee and performer amount for donations
CREATE OR REPLACE FUNCTION public.calculate_donation_amounts()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Calculate 5% platform fee
  NEW.platform_fee := NEW.amount * 0.05;
  NEW.performer_amount := NEW.amount - NEW.platform_fee;
  RETURN NEW;
END;
$$;

CREATE TRIGGER donation_calculation_trigger
  BEFORE INSERT ON public.donations
  FOR EACH ROW EXECUTE FUNCTION public.calculate_donation_amounts();

-- 15. Mock Data for Development
DO $$
DECLARE
    admin_uuid UUID := gen_random_uuid();
    performer1_uuid UUID := gen_random_uuid();
    performer2_uuid UUID := gen_random_uuid();
    user1_uuid UUID := gen_random_uuid();
    user2_uuid UUID := gen_random_uuid();
    video1_uuid UUID := gen_random_uuid();
    video2_uuid UUID := gen_random_uuid();
BEGIN
    -- Create auth users with required fields
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (admin_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'admin@ynfny.com', crypt('admin123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "YNFNY Admin", "username": "admin", "role": "admin"}'::jsonb, 
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (performer1_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'jazz.guitarist@ynfny.com', crypt('performer123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Marcus Rodriguez", "username": "jazzguitar_marcus", "role": "street_performer"}'::jsonb,
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (performer2_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'soul.singer@ynfny.com', crypt('performer123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Alicia Washington", "username": "soulful_alicia", "role": "street_performer"}'::jsonb,
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (user1_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'brooklyn.lover@ynfny.com', crypt('user123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Sarah Chen", "username": "brooklynite_sarah", "role": "new_yorker"}'::jsonb,
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (user2_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'manhattan.explorer@ynfny.com', crypt('user123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "David Kim", "username": "manhattan_david", "role": "new_yorker"}'::jsonb,
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Wait for triggers to create user profiles, then update performer-specific data
    UPDATE public.user_profiles SET
        performance_type = 'musician'::public.performance_type,
        frequent_performance_spots = 'Washington Square Park, Union Square',
        social_media_links = '{"instagram": "jazzguitar_marcus", "youtube": "MarcusJazzGuitar"}'::jsonb,
        verification_status = 'approved'::public.verification_status,
        is_verified = true,
        bio = 'Jazz guitarist bringing smooth melodies to NYC streets. 15+ years performing across the five boroughs.'
    WHERE id = performer1_uuid;

    UPDATE public.user_profiles SET
        performance_type = 'singer'::public.performance_type,
        frequent_performance_spots = 'Times Square, Brooklyn Bridge, Central Park',
        social_media_links = '{"instagram": "soulful_alicia", "tiktok": "aliciasings"}'::jsonb,
        verification_status = 'approved'::public.verification_status,
        is_verified = true,
        bio = 'Soul and R&B vocalist spreading love through music. Featured in NYC street performance documentary.'
    WHERE id = performer2_uuid;

    -- Create sample videos
    INSERT INTO public.videos (id, performer_id, title, description, video_url, thumbnail_url, duration, 
                              location_latitude, location_longitude, location_name, borough, is_approved) VALUES
        (video1_uuid, performer1_uuid, 'Autumn Leaves - Jazz Interpretation', 
         'Classic jazz standard performed with my signature fingerstyle technique. Perfect NYC fall vibes!',
         'https://example.com/videos/autumn-leaves-jazz.mp4',
         'https://example.com/thumbnails/autumn-leaves.jpg',
         240, 40.7489, -73.9680, 'Washington Square Park', 'Manhattan', true),
        (video2_uuid, performer2_uuid, 'Soulful Sunday Mornings', 
         'Original composition inspired by Harlem Renaissance. Sunday morning energy in Brooklyn!',
         'https://example.com/videos/soulful-sunday.mp4',
         'https://example.com/thumbnails/soulful-sunday.jpg',
         195, 40.6892, -73.9442, 'Prospect Park', 'Brooklyn', true);

    -- Create sample interactions
    INSERT INTO public.video_interactions (user_id, video_id, interaction_type) VALUES
        (user1_uuid, video1_uuid, 'like'),
        (user1_uuid, video1_uuid, 'view'),
        (user2_uuid, video1_uuid, 'like'),
        (user2_uuid, video1_uuid, 'view'),
        (user1_uuid, video2_uuid, 'like'),
        (user1_uuid, video2_uuid, 'view'),
        (user2_uuid, video2_uuid, 'view');

    -- Create sample comments
    INSERT INTO public.comments (video_id, user_id, content) VALUES
        (video1_uuid, user1_uuid, 'Amazing guitar skills! Love how you bring jazz to the streets 🎸'),
        (video2_uuid, user2_uuid, 'Your voice is incredible! Keep sharing your gift with NYC ❤️');

    -- Create sample follows
    INSERT INTO public.follows (follower_id, following_id) VALUES
        (user1_uuid, performer1_uuid),
        (user1_uuid, performer2_uuid),
        (user2_uuid, performer1_uuid),
        (user2_uuid, performer2_uuid);

    -- Create sample donations
    INSERT INTO public.donations (donor_id, performer_id, video_id, amount, currency, 
                                 transaction_status, message, completed_at) VALUES
        (user1_uuid, performer1_uuid, video1_uuid, 10.00, 'USD', 
         'completed'::public.transaction_status, 
         'Love your music! Keep spreading joy in the city 🎵', now() - interval '2 days'),
        (user2_uuid, performer2_uuid, video2_uuid, 25.00, 'USD',
         'completed'::public.transaction_status,
         'Your voice touched my soul. Thank you for sharing your talent!', now() - interval '1 day');

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;