-- Phase 6G: Safety & Moderation System Database Migration
-- Implements comprehensive content reporting, user blocking, and moderation tools
-- Date: 2025-09-15

-- 1. Create report types and moderation action types
CREATE TYPE public.report_type AS ENUM ('spam', 'harassment', 'inappropriate_content', 'copyright', 'fake_account', 'violence', 'hate_speech', 'nudity', 'other');
CREATE TYPE public.moderation_action_type AS ENUM ('warning', 'content_removal', 'account_suspension', 'account_ban', 'content_approval', 'report_dismissed', 'content_demonetization');
CREATE TYPE public.report_status AS ENUM ('pending', 'under_review', 'resolved', 'dismissed');

-- 2. User Reports Table - Users can report videos, comments, and other users
CREATE TABLE public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    
    -- What is being reported (polymorphic - only one should be set)
    reported_user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    reported_video_id UUID REFERENCES public.videos(id) ON DELETE CASCADE,
    reported_comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    
    -- Report details
    report_type public.report_type NOT NULL,
    description TEXT NOT NULL,
    status public.report_status DEFAULT 'pending'::public.report_status,
    
    -- Moderation tracking
    assigned_moderator_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    moderator_notes TEXT,
    resolution_reason TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    
    -- Ensure only one target is set
    CONSTRAINT check_single_report_target CHECK (
        (reported_user_id IS NOT NULL)::int + 
        (reported_video_id IS NOT NULL)::int + 
        (reported_comment_id IS NOT NULL)::int = 1
    )
);

-- 3. User Blocks Table - Users can block other users
CREATE TABLE public.user_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    reason TEXT, -- Optional reason for blocking
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(blocker_id, blocked_id),
    CHECK (blocker_id != blocked_id)
);

-- 4. Moderation Actions Table - Track all admin actions
CREATE TABLE public.moderation_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moderator_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    
    -- What was acted upon (polymorphic)
    target_user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    target_video_id UUID REFERENCES public.videos(id) ON DELETE CASCADE,
    target_comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    related_report_id UUID REFERENCES public.reports(id) ON DELETE SET NULL,
    
    -- Action details
    action_type public.moderation_action_type NOT NULL,
    reason TEXT NOT NULL,
    notes TEXT,
    duration_days INTEGER, -- For temporary actions like suspensions
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ, -- For temporary actions
    
    -- Ensure at least one target is set
    CONSTRAINT check_moderation_target CHECK (
        target_user_id IS NOT NULL OR 
        target_video_id IS NOT NULL OR 
        target_comment_id IS NOT NULL
    )
);

-- 5. Content Warnings Table - For flagged content that needs warnings
CREATE TABLE public.content_warnings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
    warning_type TEXT NOT NULL, -- e.g., 'sensitive_content', 'explicit_language'
    warning_message TEXT NOT NULL,
    created_by_moderator_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(video_id, warning_type)
);

-- 6. Community Guidelines Violations - Track user violations
CREATE TABLE public.user_violations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    violation_type public.report_type NOT NULL,
    severity INTEGER NOT NULL DEFAULT 1 CHECK (severity BETWEEN 1 AND 5), -- 1 = minor, 5 = severe
    description TEXT NOT NULL,
    related_report_id UUID REFERENCES public.reports(id) ON DELETE SET NULL,
    created_by_moderator_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 7. Enable Row Level Security on new tables
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_warnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_violations ENABLE ROW LEVEL SECURITY;

-- 8. Performance Indexes
CREATE INDEX idx_reports_reporter_id ON public.reports(reporter_id);
CREATE INDEX idx_reports_status ON public.reports(status);
CREATE INDEX idx_reports_type ON public.reports(report_type);
CREATE INDEX idx_reports_reported_user ON public.reports(reported_user_id) WHERE reported_user_id IS NOT NULL;
CREATE INDEX idx_reports_reported_video ON public.reports(reported_video_id) WHERE reported_video_id IS NOT NULL;
CREATE INDEX idx_reports_reported_comment ON public.reports(reported_comment_id) WHERE reported_comment_id IS NOT NULL;
CREATE INDEX idx_reports_moderator ON public.reports(assigned_moderator_id) WHERE assigned_moderator_id IS NOT NULL;
CREATE INDEX idx_reports_created_pending ON public.reports(created_at DESC) WHERE status = 'pending';

CREATE INDEX idx_user_blocks_blocker ON public.user_blocks(blocker_id);
CREATE INDEX idx_user_blocks_blocked ON public.user_blocks(blocked_id);
CREATE INDEX idx_user_blocks_relationship ON public.user_blocks(blocker_id, blocked_id);

CREATE INDEX idx_moderation_actions_moderator ON public.moderation_actions(moderator_id);
CREATE INDEX idx_moderation_actions_target_user ON public.moderation_actions(target_user_id) WHERE target_user_id IS NOT NULL;
CREATE INDEX idx_moderation_actions_target_video ON public.moderation_actions(target_video_id) WHERE target_video_id IS NOT NULL;
CREATE INDEX idx_moderation_actions_created ON public.moderation_actions(created_at DESC);
CREATE INDEX idx_moderation_actions_active ON public.moderation_actions(expires_at) WHERE expires_at > CURRENT_TIMESTAMP;

CREATE INDEX idx_content_warnings_video ON public.content_warnings(video_id);
CREATE INDEX idx_content_warnings_active ON public.content_warnings(is_active) WHERE is_active = true;

CREATE INDEX idx_user_violations_user ON public.user_violations(user_id);
CREATE INDEX idx_user_violations_severity ON public.user_violations(severity DESC);
CREATE INDEX idx_user_violations_created ON public.user_violations(created_at DESC);

-- 9. Helper Functions for Safety & Moderation

-- Check if user is blocked by another user
CREATE OR REPLACE FUNCTION public.is_user_blocked(blocker_user_id UUID, blocked_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT EXISTS(
    SELECT 1 FROM public.user_blocks
    WHERE blocker_id = blocker_user_id 
    AND blocked_id = blocked_user_id
);
$$;

-- Check if user has active suspension
CREATE OR REPLACE FUNCTION public.is_user_suspended(user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT EXISTS(
    SELECT 1 FROM public.moderation_actions ma
    WHERE ma.target_user_id = user_id
    AND ma.action_type IN ('account_suspension', 'account_ban')
    AND (ma.expires_at IS NULL OR ma.expires_at > CURRENT_TIMESTAMP)
);
$$;

-- Get user violation count by severity
CREATE OR REPLACE FUNCTION public.get_user_violation_count(user_id UUID, min_severity INTEGER DEFAULT 1)
RETURNS INTEGER
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT COUNT(*)::INTEGER
FROM public.user_violations
WHERE user_id = get_user_violation_count.user_id
AND severity >= get_user_violation_count.min_severity;
$$;

-- Check if content needs warning overlay
CREATE OR REPLACE FUNCTION public.content_has_warnings(video_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT EXISTS(
    SELECT 1 FROM public.content_warnings
    WHERE video_id = content_has_warnings.video_id
    AND is_active = true
);
$$;

-- 10. RLS Policies for Safety Tables

-- Reports policies
CREATE POLICY "Users can create reports" ON public.reports
FOR INSERT WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Users can view their own reports" ON public.reports
FOR SELECT USING (reporter_id = auth.uid());

CREATE POLICY "Moderators can view all reports" ON public.reports
FOR SELECT USING (public.is_admin());

CREATE POLICY "Moderators can update reports" ON public.reports
FOR UPDATE USING (public.is_admin());

-- User blocks policies
CREATE POLICY "Users can manage their blocks" ON public.user_blocks
FOR ALL USING (blocker_id = auth.uid());

CREATE POLICY "Users can see who blocked them (for debugging)" ON public.user_blocks
FOR SELECT USING (blocked_id = auth.uid());

-- Moderation actions policies (admin only)
CREATE POLICY "Only admins can view moderation actions" ON public.moderation_actions
FOR SELECT USING (public.is_admin());

CREATE POLICY "Only admins can create moderation actions" ON public.moderation_actions
FOR INSERT WITH CHECK (public.is_admin() AND moderator_id = auth.uid());

-- Content warnings policies
CREATE POLICY "Everyone can view content warnings" ON public.content_warnings
FOR SELECT USING (true);

CREATE POLICY "Only admins can manage content warnings" ON public.content_warnings
FOR ALL USING (public.is_admin());

-- User violations policies (admin only)
CREATE POLICY "Only admins can view violations" ON public.user_violations
FOR SELECT USING (public.is_admin());

CREATE POLICY "Only admins can create violations" ON public.user_violations
FOR INSERT WITH CHECK (public.is_admin() AND created_by_moderator_id = auth.uid());

-- 11. Update existing tables with suspension support

-- Add suspension tracking to user profiles
ALTER TABLE public.user_profiles 
ADD COLUMN is_suspended BOOLEAN DEFAULT false,
ADD COLUMN suspension_reason TEXT,
ADD COLUMN suspended_until TIMESTAMPTZ;

-- Create index for suspension queries
CREATE INDEX idx_user_profiles_suspended ON public.user_profiles(is_suspended, suspended_until);

-- 12. Trigger Functions for Automation

-- Auto-update user suspension status from moderation actions
CREATE OR REPLACE FUNCTION public.update_user_suspension_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if this is a suspension or ban action
    IF NEW.action_type IN ('account_suspension', 'account_ban') AND NEW.target_user_id IS NOT NULL THEN
        UPDATE public.user_profiles
        SET 
            is_suspended = true,
            suspension_reason = NEW.reason,
            suspended_until = NEW.expires_at
        WHERE id = NEW.target_user_id;
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_suspension
    AFTER INSERT ON public.moderation_actions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_user_suspension_status();

-- Auto-resolve expired suspensions
CREATE OR REPLACE FUNCTION public.resolve_expired_suspensions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.user_profiles
    SET 
        is_suspended = false,
        suspension_reason = NULL,
        suspended_until = NULL
    WHERE is_suspended = true
    AND suspended_until IS NOT NULL
    AND suspended_until <= CURRENT_TIMESTAMP;
END;
$$;

-- 13. Enhanced video visibility function that considers suspensions and blocks
CREATE OR REPLACE FUNCTION public.can_view_video_safely(video_id UUID)
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
    AND NOT up.is_suspended
    AND NOT public.is_user_blocked(auth.uid(), v.performer_id)
    AND NOT public.is_user_blocked(v.performer_id, auth.uid())
);
$$;

-- 14. Comments with safety considerations
CREATE OR REPLACE FUNCTION public.can_view_comment_safely(comment_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT EXISTS(
    SELECT 1 FROM public.comments c
    JOIN public.user_profiles up ON c.user_id = up.id
    WHERE c.id = comment_id
    AND NOT c.is_flagged
    AND up.is_active = true
    AND NOT up.is_suspended
    AND NOT public.is_user_blocked(auth.uid(), c.user_id)
    AND NOT public.is_user_blocked(c.user_id, auth.uid())
);
$$;

-- 15. RPC functions for efficient reporting
CREATE OR REPLACE FUNCTION public.submit_report(
    reported_user_id UUID DEFAULT NULL,
    reported_video_id UUID DEFAULT NULL,
    reported_comment_id UUID DEFAULT NULL,
    report_type public.report_type,
    description TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    report_id UUID;
BEGIN
    -- Validate that exactly one target is provided
    IF (reported_user_id IS NOT NULL)::int + 
       (reported_video_id IS NOT NULL)::int + 
       (reported_comment_id IS NOT NULL)::int != 1 THEN
        RAISE EXCEPTION 'Exactly one target must be specified for reporting';
    END IF;
    
    -- Create the report
    INSERT INTO public.reports (
        reporter_id,
        reported_user_id,
        reported_video_id,
        reported_comment_id,
        report_type,
        description
    ) VALUES (
        auth.uid(),
        reported_user_id,
        reported_video_id,
        reported_comment_id,
        submit_report.report_type,
        submit_report.description
    ) RETURNING id INTO report_id;
    
    -- Auto-flag content if it receives multiple reports
    IF reported_video_id IS NOT NULL THEN
        UPDATE public.videos 
        SET is_flagged = true
        WHERE id = reported_video_id
        AND (
            SELECT COUNT(*) FROM public.reports r
            WHERE r.reported_video_id = reported_video_id
            AND r.status IN ('pending', 'under_review')
        ) >= 3; -- Flag after 3 reports
    END IF;
    
    IF reported_comment_id IS NOT NULL THEN
        UPDATE public.comments 
        SET is_flagged = true
        WHERE id = reported_comment_id
        AND (
            SELECT COUNT(*) FROM public.reports r
            WHERE r.reported_comment_id = reported_comment_id
            AND r.status IN ('pending', 'under_review')
        ) >= 3; -- Flag after 3 reports
    END IF;
    
    RETURN report_id;
END;
$$;

-- 16. Block/Unblock RPC functions
CREATE OR REPLACE FUNCTION public.block_user(
    user_to_block_id UUID,
    reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Can't block yourself
    IF user_to_block_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot block yourself';
    END IF;
    
    -- Insert block relationship
    INSERT INTO public.user_blocks (blocker_id, blocked_id, reason)
    VALUES (auth.uid(), user_to_block_id, reason)
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
    
    -- Remove follow relationships
    DELETE FROM public.follows 
    WHERE (follower_id = auth.uid() AND following_id = user_to_block_id)
    OR (follower_id = user_to_block_id AND following_id = auth.uid());
    
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.unblock_user(user_to_unblock_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.user_blocks
    WHERE blocker_id = auth.uid() AND blocked_id = user_to_unblock_id;
    
    RETURN true;
END;
$$;

-- 17. Get moderation dashboard data (admin only)
CREATE OR REPLACE FUNCTION public.get_moderation_dashboard()
RETURNS TABLE (
    pending_reports INTEGER,
    flagged_videos INTEGER,
    flagged_comments INTEGER,
    recent_violations INTEGER,
    active_suspensions INTEGER
)
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
SELECT 
    (SELECT COUNT(*)::INTEGER FROM public.reports WHERE status = 'pending'),
    (SELECT COUNT(*)::INTEGER FROM public.videos WHERE is_flagged = true),
    (SELECT COUNT(*)::INTEGER FROM public.comments WHERE is_flagged = true),
    (SELECT COUNT(*)::INTEGER FROM public.user_violations WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'),
    (SELECT COUNT(*)::INTEGER FROM public.user_profiles WHERE is_suspended = true);
$$;