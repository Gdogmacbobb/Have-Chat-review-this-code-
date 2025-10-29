import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class VideoGridWidget extends StatelessWidget {
  final List<Map<String, dynamic>> videos;
  final Function(Map<String, dynamic>) onVideoTap;
  final Function(Map<String, dynamic>) onVideoLongPress;
  final bool showMoreOptions; // Show "..." overlay on each thumbnail for own profile
  final Function(Map<String, dynamic>)? onMoreOptionsTap;

  const VideoGridWidget({
    super.key,
    required this.videos,
    required this.onVideoTap,
    required this.onVideoLongPress,
    this.showMoreOptions = false,
    this.onMoreOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'video_library',
              color: AppTheme.textSecondary,
              size: 48,
            ),
            SizedBox(height: 2.h),
            Text(
              "No videos yet",
              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              "Videos will appear here once uploaded",
              style: AppTheme.darkTheme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    debugPrint('[VIDEO_MENU] OLD_BOX_REMOVED - Static box replaced with per-thumbnail overlays');
    
    return GridView.builder(
      padding: EdgeInsets.all(2.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1.w,
        mainAxisSpacing: 1.w,
        childAspectRatio: 0.75,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _buildVideoThumbnail(context, video);
      },
    );
  }

  Widget _buildVideoThumbnail(
      BuildContext context, Map<String, dynamic> video) {
    return GestureDetector(
      onTap: () => onVideoTap(video),
      onLongPress: () => onVideoLongPress(video),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.surfaceDark,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomImageWidget(
                imageUrl: video["thumbnailUrl"] as String? ?? "",
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            // Play Icon Overlay
            Center(
              child: Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppTheme.videoOverlay,
                  shape: BoxShape.circle,
                ),
                child: CustomIconWidget(
                  iconName: 'play_arrow',
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
              ),
            ),
            // View Count Overlay (bottom-left)
            if (video["viewCount"] != null)
              Positioned(
                bottom: 1.w,
                left: 1.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: AppTheme.videoOverlay,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'visibility',
                        color: AppTheme.textPrimary,
                        size: 12,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        _formatViewCount(video["viewCount"] as int),
                        style: AppTheme.videoOverlayStyle().copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Duration Overlay
            Positioned(
              bottom: 1.w,
              right: 1.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: AppTheme.videoOverlay,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(video["duration"] as int? ?? 0),
                  style: AppTheme.videoOverlayStyle().copyWith(
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            // Like Count (if available)
            if (video["likeCount"] != null)
              Positioned(
                top: 1.w,
                right: 1.w,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: AppTheme.videoOverlay,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'favorite',
                        color: AppTheme.accentRed,
                        size: 12,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        _formatViewCount(video["likeCount"] as int),
                        style: AppTheme.videoOverlayStyle().copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // More Options Overlay (top-left, only on own profile)
            if (showMoreOptions)
              Positioned(
                top: 1.w,
                left: 1.w,
                child: GestureDetector(
                  onTap: () {
                    debugPrint('[VIDEO_MENU] OVERLAY_TAPPED - Video ID: ${video["id"]}');
                    onMoreOptionsTap?.call(video);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: AppTheme.videoOverlay,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '...',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return "${(count / 1000000).toStringAsFixed(1)}M";
    } else if (count >= 1000) {
      return "${(count / 1000).toStringAsFixed(1)}K";
    }
    return count.toString();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }
}
