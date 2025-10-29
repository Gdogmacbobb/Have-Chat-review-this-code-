-- Add thumbnail frame time field to videos table
-- This stores the timestamp in milliseconds for the selected thumbnail frame
-- Date: 2025-10-09

ALTER TABLE public.videos 
ADD COLUMN IF NOT EXISTS thumbnail_frame_time INTEGER DEFAULT 0;

COMMENT ON COLUMN public.videos.thumbnail_frame_time IS 'Timestamp in milliseconds for the selected thumbnail frame from the video';

-- Create index for performance when querying videos with thumbnails
CREATE INDEX IF NOT EXISTS idx_videos_thumbnail_frame_time ON public.videos(thumbnail_frame_time);
