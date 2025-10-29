import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class VideoContextMenuWidget extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onReport;

  const VideoContextMenuWidget({
    super.key,
    required this.video,
    required this.onSave,
    required this.onShare,
    required this.onReport,
  });

  static void show(
    BuildContext context,
    Map<String, dynamic> video, {
    required VoidCallback onSave,
    required VoidCallback onShare,
    required VoidCallback onReport,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoContextMenuWidget(
        video: video,
        onSave: onSave,
        onShare: onShare,
        onReport: onReport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: AppTheme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 3.h),

          // Video Info
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomImageWidget(
                  imageUrl: video["thumbnailUrl"] as String? ?? "",
                  width: 15.w,
                  height: 20.w,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video["title"] as String? ?? "Untitled Video",
                      style: AppTheme.darkTheme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      "${_formatViewCount(video["viewCount"] as int? ?? 0)} views • ${_formatDuration(video["duration"] as int? ?? 0)}",
                      style: AppTheme.darkTheme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),

          // Menu Options
          _buildMenuOption(
            context,
            icon: 'bookmark_border',
            title: "Save Video",
            subtitle: "Save to your collection",
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              onSave();
            },
          ),
          SizedBox(height: 2.h),
          _buildMenuOption(
            context,
            icon: 'arrow_outward',
            title: "Share Video",
            subtitle: "Share with friends",
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              onShare();
            },
          ),
          SizedBox(height: 2.h),
          _buildMenuOption(
            context,
            icon: 'report',
            title: "Report Video",
            subtitle: "Report inappropriate content",
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              _showReportDialog(context);
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.inputBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppTheme.accentRed.withOpacity(0.2)
                    : AppTheme.primaryOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomIconWidget(
                iconName: icon,
                color:
                    isDestructive ? AppTheme.accentRed : AppTheme.primaryOrange,
                size: 20,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                      color: isDestructive
                          ? AppTheme.accentRed
                          : AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    subtitle,
                    style: AppTheme.darkTheme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            CustomIconWidget(
              iconName: 'chevron_right',
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          "Report Video",
          style: AppTheme.darkTheme.textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Why are you reporting this video?",
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
            SizedBox(height: 2.h),
            ...[
              "Inappropriate content",
              "Spam or misleading",
              "Harassment or bullying",
              "Violence or dangerous acts",
              "Copyright infringement",
              "Other"
            ].map((reason) => InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _submitReport(context, reason);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    child: Text(
                      reason,
                      style: AppTheme.darkTheme.textTheme.bodyMedium,
                    ),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitReport(BuildContext context, String reason) {
    onReport();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CustomIconWidget(
              iconName: 'check_circle',
              color: AppTheme.successGreen,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Text(
              "Report submitted. Thank you for helping keep YNFNY safe.",
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceDark,
        duration: const Duration(seconds: 3),
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
