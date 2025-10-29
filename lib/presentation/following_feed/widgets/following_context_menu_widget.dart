import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class FollowingContextMenuWidget extends StatelessWidget {
  final VoidCallback? onUnfollow;
  final VoidCallback? onSave;
  final VoidCallback? onReport;
  final VoidCallback? onShare;
  final VoidCallback? onClose;

  const FollowingContextMenuWidget({
    Key? key,
    this.onUnfollow,
    this.onSave,
    this.onReport,
    this.onShare,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        width: 100.w,
        height: 100.h,
        color: AppTheme.backgroundDark.withOpacity(0.8),
        child: Center(
          child: Container(
            width: 80.w,
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowDark,
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.borderSubtle,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Options',
                        style:
                            AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: CustomIconWidget(
                          iconName: 'close',
                          color: AppTheme.textSecondary,
                          size: 6.w,
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu Items
                Column(
                  children: [
                    // Unfollow Option
                    _buildMenuItem(
                      icon: 'person_remove',
                      title: 'Unfollow',
                      subtitle: 'Stop seeing posts from this performer',
                      iconColor: AppTheme.accentRed,
                      onTap: () {
                        onClose?.call();
                        onUnfollow?.call();
                      },
                    ),

                    _buildDivider(),

                    // Save Option
                    _buildMenuItem(
                      icon: 'bookmark_border',
                      title: 'Save Video',
                      subtitle: 'Add to your saved collection',
                      iconColor: AppTheme.textSecondary,
                      onTap: () {
                        onClose?.call();
                        onSave?.call();
                      },
                    ),

                    _buildDivider(),

                    // Share Option
                    _buildMenuItem(
                      icon: 'arrow_outward',
                      title: 'Share',
                      subtitle: 'Share this performance',
                      iconColor: AppTheme.textSecondary,
                      onTap: () {
                        onClose?.call();
                        onShare?.call();
                      },
                    ),

                    _buildDivider(),

                    // Report Option
                    _buildMenuItem(
                      icon: 'flag',
                      title: 'Report',
                      subtitle: 'Report inappropriate content',
                      iconColor: AppTheme.accentRed,
                      onTap: () {
                        onClose?.call();
                        onReport?.call();
                      },
                    ),
                  ],
                ),

                SizedBox(height: 2.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
        child: Row(
          children: [
            Container(
              width: 12.w,
              height: 12.w,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CustomIconWidget(
                iconName: icon,
                color: iconColor,
                size: 6.w,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    subtitle,
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            CustomIconWidget(
              iconName: 'chevron_right',
              color: AppTheme.textSecondary,
              size: 5.w,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      height: 1,
      color: AppTheme.borderSubtle.withOpacity(0.3),
    );
  }
}
