-- Phase 6E: Reposting System Database Foundation
-- Enables New Yorkers to repost street performances with social features
-- Date: 2025-09-15

-- 1. Create reposts table
CREATE TABLE public.reposts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reposter_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    repost_text TEXT, -- Optional comment/caption when reposting
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent duplicate reposts by same user
    UNIQUE(reposter_id, video_id)
);

-- 2. Add repost_count to videos table
ALTER TABLE public.videos 
ADD COLUMN repost_count INTEGER DEFAULT 0;

-- 3. Create indexes for performance
CREATE INDEX idx_reposts_reposter_id ON public.reposts(reposter_id, created_at DESC);
CREATE INDEX idx_reposts_video_id ON public.reposts(video_id);
CREATE INDEX idx_reposts_created_at ON public.reposts(created_at DESC);
CREATE INDEX idx_videos_repost_count ON public.videos(repost_count DESC);

-- 4. Enable RLS on reposts table
ALTER TABLE public.reposts ENABLE ROW LEVEL SECURITY;

-- 5. Helper functions for repost system
CREATE OR REPLACE FUNCTION public.is_new_yorker()
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT EXISTS(
    SELECT 1 FROM public.user_profiles
    WHERE id = auth.uid()
    AND role = 'new_yorker'
    AND is_active = true
);
$$;

CREATE OR REPLACE FUNCTION public.can_repost_video(video_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT public.can_view_video(video_id) 
    AND public.is_new_yorker()
    AND NOT EXISTS(
        SELECT 1 FROM public.reposts 
        WHERE reposter_id = auth.uid() 
        AND reposts.video_id = can_repost_video.video_id
    );
$$;

-- 6. Function to update repost counts
CREATE OR REPLACE FUNCTION public.update_repost_count()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.videos 
        SET repost_count = repost_count + 1, updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.video_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.videos 
        SET repost_count = GREATEST(repost_count - 1, 0), updated_at = CURRENT_TIMESTAMP
        WHERE id = OLD.video_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- 7. Function to get user's repost feed
CREATE OR REPLACE FUNCTION public.get_user_reposts(
    user_id UUID,
    limit_count INTEGER DEFAULT 20,
    offset_count INTEGER DEFAULT 0
)
RETURNS TABLE(
    id UUID,
    video_id UUID,
    repost_text TEXT,
    created_at TIMESTAMPTZ,
    -- Video details
    title TEXT,
    description TEXT,
    video_url TEXT,
    thumbnail_url TEXT,
    view_count INTEGER,
    like_count INTEGER,
    comment_count INTEGER,
    repost_count INTEGER,
    video_created_at TIMESTAMPTZ,
    -- Original performer details  
    performer_id UUID,
    performer_username TEXT,
    performer_full_name TEXT,
    performer_profile_image_url TEXT,
    performer_performance_type TEXT,
    performer_is_verified BOOLEAN
)
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT 
    r.id,
    r.video_id,
    r.repost_text,
    r.created_at,
    -- Video details
    v.title,
    v.description,
    v.video_url,
    v.thumbnail_url,
    v.view_count,
    v.like_count,
    v.comment_count,
    v.repost_count,
    v.created_at as video_created_at,
    -- Original performer details
    v.performer_id,
    up.username as performer_username,
    up.full_name as performer_full_name,
    up.profile_image_url as performer_profile_image_url,
    up.performance_type as performer_performance_type,
    up.is_verified as performer_is_verified
FROM public.reposts r
JOIN public.videos v ON r.video_id = v.id
JOIN public.user_profiles up ON v.performer_id = up.id
WHERE r.reposter_id = user_id
    AND v.is_approved = true 
    AND NOT v.is_flagged
    AND up.is_active = true
ORDER BY r.created_at DESC
LIMIT limit_count OFFSET offset_count;
$$;

-- 8. RLS policies for reposts table
CREATE POLICY "authenticated_can_view_reposts"
ON public.reposts
FOR SELECT
TO authenticated
USING (public.can_view_video(video_id));

CREATE POLICY "new_yorkers_can_create_reposts"
ON public.reposts
FOR INSERT
TO authenticated
WITH CHECK (
    public.is_new_yorker() 
    AND reposter_id = auth.uid()
    AND public.can_view_video(video_id)
);

CREATE POLICY "users_can_delete_own_reposts"
ON public.reposts
FOR DELETE
TO authenticated
USING (reposter_id = auth.uid() OR public.is_admin());

-- 9. Create trigger for repost count updates
CREATE TRIGGER repost_count_trigger
    AFTER INSERT OR DELETE ON public.reposts
    FOR EACH ROW EXECUTE FUNCTION public.update_repost_count();

-- 10. Create sample data for testing (only if development environment)
-- This will be handled by the application layer

-- 11. Documentation comments
COMMENT ON TABLE public.reposts IS 'Reposts created by New Yorkers to share street performances';
COMMENT ON COLUMN public.reposts.repost_text IS 'Optional comment/caption added when reposting';
COMMENT ON COLUMN public.videos.repost_count IS 'Number of times this video has been reposted';
COMMENT ON FUNCTION public.can_repost_video(UUID) IS 'Checks if user can repost a video (New Yorker, not already reposted)';