-- Phase 6 Video Social Platform Database Enhancements
-- Adds hierarchical comments, hashtags system, and storage configuration
-- Date: 2025-09-15

-- 1. Add hierarchical comment structure
ALTER TABLE public.comments 
ADD COLUMN parent_comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE;

-- Create index for hierarchical comment queries
CREATE INDEX idx_comments_parent_id ON public.comments(parent_comment_id);
CREATE INDEX idx_comments_video_parent ON public.comments(video_id, parent_comment_id);

-- 2. Create hashtags table
CREATE TABLE public.hashtags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag TEXT NOT NULL UNIQUE,
    tag_normalized TEXT NOT NULL UNIQUE, -- lowercase, trimmed version for matching
    video_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create video_hashtags junction table
CREATE TABLE public.video_hashtags (
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    hashtag_id UUID NOT NULL REFERENCES public.hashtags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (video_id, hashtag_id)
);

-- 4. Add hashtags support to videos table
ALTER TABLE public.videos 
ADD COLUMN hashtags TEXT[] DEFAULT '{}';

-- 5. Enable RLS on new tables
ALTER TABLE public.hashtags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_hashtags ENABLE ROW LEVEL SECURITY;

-- 6. Create performance indexes for hashtags
CREATE INDEX idx_hashtags_tag_normalized ON public.hashtags(tag_normalized);
CREATE INDEX idx_hashtags_video_count ON public.hashtags(video_count DESC);
CREATE INDEX idx_video_hashtags_hashtag_id ON public.video_hashtags(hashtag_id);
CREATE INDEX idx_videos_hashtags_gin ON public.videos USING gin(hashtags);

-- 7. Additional performance indexes for video feeds
CREATE INDEX idx_videos_created_approved ON public.videos(created_at DESC) WHERE is_approved = true AND NOT is_flagged;
CREATE INDEX idx_videos_performer_approved ON public.videos(performer_id, created_at DESC) WHERE is_approved = true;
CREATE INDEX idx_videos_borough_approved ON public.videos(borough, created_at DESC) WHERE is_approved = true AND NOT is_flagged;

-- 8. Composite indexes for engagement queries
CREATE INDEX idx_video_interactions_user_type_video ON public.video_interactions(user_id, interaction_type, video_id);
CREATE INDEX idx_follows_following_created ON public.follows(following_id, created_at DESC);

-- 9. Critical helper functions for security and authorization (MOVED EARLY - Before policies)
CREATE OR REPLACE FUNCTION public.can_view_video(video_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT EXISTS(
    SELECT 1 FROM public.videos v
    JOIN public.user_profiles up ON v.performer_id = up.id
    WHERE v.id = video_id
    AND v.is_approved = true
    AND NOT v.is_flagged
    AND up.is_active = true
);
$$;

CREATE OR REPLACE FUNCTION public.owns_video(video_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT EXISTS(
    SELECT 1 FROM public.videos v
    WHERE v.id = video_id
    AND v.performer_id = auth.uid()
);
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT EXISTS(
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid()
    AND role = 'admin'
    AND is_active = true
);
$$;

CREATE OR REPLACE FUNCTION public.is_performer()
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT EXISTS(
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid()
    AND role = 'street_performer'
    AND is_active = true
);
$$;

-- 10. Helper functions for hashtag management
CREATE OR REPLACE FUNCTION public.normalize_hashtag(tag TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
SELECT lower(trim(regexp_replace(tag, '^#', '', 'g')));
$$;

CREATE OR REPLACE FUNCTION public.extract_hashtags_from_text(content TEXT)
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
AS $$
SELECT ARRAY(
    SELECT DISTINCT public.normalize_hashtag(match[1])
    FROM regexp_split_to_table(content, '\s+') AS word,
         regexp_matches(word, '#([a-zA-Z0-9_]+)', 'g') AS match
    WHERE length(match[1]) >= 2 AND length(match[1]) <= 50
);
$$;

-- 11. Function to update hashtag counts
CREATE OR REPLACE FUNCTION public.update_hashtag_count()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.hashtags 
        SET video_count = video_count + 1, updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.hashtag_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.hashtags 
        SET video_count = GREATEST(video_count - 1, 0), updated_at = CURRENT_TIMESTAMP
        WHERE id = OLD.hashtag_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- 12. Function to automatically manage video hashtags
CREATE OR REPLACE FUNCTION public.manage_video_hashtags()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    hashtag_text TEXT;
    hashtag_normalized TEXT;
    hashtag_id UUID;
BEGIN
    -- Extract hashtags from title and description
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        -- Clear existing hashtags for update
        IF TG_OP = 'UPDATE' THEN
            DELETE FROM public.video_hashtags WHERE video_id = NEW.id;
        END IF;
        
        -- Extract hashtags from content
        NEW.hashtags := public.extract_hashtags_from_text(COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.description, ''));
        
        -- Process each hashtag
        FOREACH hashtag_text IN ARRAY NEW.hashtags
        LOOP
            hashtag_normalized := public.normalize_hashtag(hashtag_text);
            
            -- Get or create hashtag
            INSERT INTO public.hashtags (tag, tag_normalized) 
            VALUES (hashtag_text, hashtag_normalized)
            ON CONFLICT (tag_normalized) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
            RETURNING id INTO hashtag_id;
            
            -- Link video to hashtag
            INSERT INTO public.video_hashtags (video_id, hashtag_id)
            VALUES (NEW.id, hashtag_id)
            ON CONFLICT DO NOTHING;
        END LOOP;
        
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Clean up hashtag associations
        DELETE FROM public.video_hashtags WHERE video_id = OLD.id;
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$;

-- 13. Function to get trending hashtags
CREATE OR REPLACE FUNCTION public.get_trending_hashtags(
    limit_count INTEGER DEFAULT 10,
    time_window INTERVAL DEFAULT '7 days'
)
RETURNS TABLE(
    tag TEXT,
    video_count INTEGER,
    recent_video_count BIGINT
)
LANGUAGE sql
STABLE
AS $$
SELECT 
    h.tag,
    h.video_count,
    COUNT(v.id) as recent_video_count
FROM public.hashtags h
LEFT JOIN public.video_hashtags vh ON h.id = vh.hashtag_id
LEFT JOIN public.videos v ON vh.video_id = v.id 
    AND v.created_at >= CURRENT_TIMESTAMP - time_window
    AND v.is_approved = true 
    AND NOT v.is_flagged
GROUP BY h.id, h.tag, h.video_count
ORDER BY recent_video_count DESC, h.video_count DESC
LIMIT limit_count;
$$;

-- 14. Function to get videos by hashtag
CREATE OR REPLACE FUNCTION public.get_videos_by_hashtag(
    hashtag_name TEXT,
    limit_count INTEGER DEFAULT 20,
    offset_count INTEGER DEFAULT 0
)
RETURNS TABLE(
    id UUID,
    title TEXT,
    description TEXT,
    video_url TEXT,
    thumbnail_url TEXT,
    view_count INTEGER,
    like_count INTEGER,
    comment_count INTEGER,
    created_at TIMESTAMPTZ,
    performer_id UUID,
    performer_username TEXT,
    performer_full_name TEXT
)
LANGUAGE sql
STABLE
AS $$
SELECT 
    v.id,
    v.title,
    v.description,
    v.video_url,
    v.thumbnail_url,
    v.view_count,
    v.like_count,
    v.comment_count,
    v.created_at,
    v.performer_id,
    up.username as performer_username,
    up.full_name as performer_full_name
FROM public.videos v
JOIN public.video_hashtags vh ON v.id = vh.video_id
JOIN public.hashtags h ON vh.hashtag_id = h.id
JOIN public.user_profiles up ON v.performer_id = up.id
WHERE h.tag_normalized = public.normalize_hashtag(hashtag_name)
    AND v.is_approved = true 
    AND NOT v.is_flagged
    AND up.is_active = true
ORDER BY v.created_at DESC
LIMIT limit_count OFFSET offset_count;
$$;

-- 15. NOW CREATE POLICIES (After all functions are defined)
-- Create RLS policies for hashtags
CREATE POLICY "public_can_view_hashtags"
ON public.hashtags
FOR SELECT
TO public
USING (true);

CREATE POLICY "authenticated_users_can_create_hashtags"
ON public.hashtags
FOR INSERT
TO authenticated
WITH CHECK (true);

-- 16. Create RLS policies for video_hashtags
CREATE POLICY "public_can_view_video_hashtags"
ON public.video_hashtags
FOR SELECT
TO public
USING (public.can_view_video(video_id));

CREATE POLICY "video_owners_manage_hashtags"
ON public.video_hashtags
FOR ALL
TO authenticated
USING (public.owns_video(video_id) OR public.is_admin())
WITH CHECK (public.owns_video(video_id) OR public.is_admin());

-- 17. Update comment policies to support hierarchical structure
DROP POLICY IF EXISTS "public_can_view_comments" ON public.comments;
CREATE POLICY "public_can_view_comments"
ON public.comments
FOR SELECT
TO public
USING (NOT is_flagged AND public.can_view_video(video_id));

-- 18. Create storage buckets (PRIVATE for security - requires authentication)
-- Note: These will be configured in the application code as well
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('profile_photos', 'profile_photos', false, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]),
    ('videos', 'videos', false, 209715200, ARRAY['video/mp4', 'video/webm', 'video/quicktime']::text[])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 19. Storage bucket policies (PRIVATE BUCKETS - Authentication Required)
-- Profile Photos Policies
CREATE POLICY "authenticated_users_can_upload_profile_photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'profile_photos');

CREATE POLICY "authenticated_users_can_view_profile_photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'profile_photos');

CREATE POLICY "users_can_update_own_profile_photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'profile_photos' AND owner = auth.uid());

CREATE POLICY "users_can_delete_own_profile_photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'profile_photos' AND owner = auth.uid());

-- Video Storage Policies
CREATE POLICY "performers_can_upload_videos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'videos' AND public.is_performer());

CREATE POLICY "authenticated_users_can_view_videos"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'videos');

CREATE POLICY "performers_can_update_own_videos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'videos' AND owner = auth.uid());

CREATE POLICY "performers_can_delete_own_videos"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'videos' AND (owner = auth.uid() OR public.is_admin()));

-- 20. Create triggers (after all functions and policies are defined)
-- Trigger for hashtag count updates
CREATE TRIGGER hashtag_count_trigger
    AFTER INSERT OR DELETE ON public.video_hashtags
    FOR EACH ROW EXECUTE FUNCTION public.update_hashtag_count();

-- Trigger for automatic hashtag management
CREATE TRIGGER video_hashtag_trigger
    BEFORE INSERT OR UPDATE OR DELETE ON public.videos
    FOR EACH ROW EXECUTE FUNCTION public.manage_video_hashtags();

-- 21. Create sample hashtags for testing
INSERT INTO public.hashtags (tag, tag_normalized) VALUES
    ('nyc', 'nyc'),
    ('streetperformance', 'streetperformance'),
    ('jazz', 'jazz'),
    ('music', 'music'),
    ('dance', 'dance'),
    ('art', 'art'),
    ('manhattan', 'manhattan'),
    ('brooklyn', 'brooklyn'),
    ('singer', 'singer'),
    ('guitarist', 'guitarist')
ON CONFLICT (tag_normalized) DO NOTHING;

-- 22. Documentation comments
COMMENT ON TABLE public.hashtags IS 'Hashtags used in video content for discovery and categorization';
COMMENT ON TABLE public.video_hashtags IS 'Junction table linking videos to their hashtags';
COMMENT ON COLUMN public.comments.parent_comment_id IS 'Reference to parent comment for hierarchical threading';
COMMENT ON COLUMN public.videos.hashtags IS 'Array of hashtag strings extracted from title and description';