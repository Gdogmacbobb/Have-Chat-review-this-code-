import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../core/app_export.dart';

class FeedNavigationHeaderWidget extends StatelessWidget {
  final String currentFeed; // 'following', 'discovery', or 'for_you'
  final bool showSearch;
  final int unreadCount;
  final VoidCallback? onRefresh;

  const FeedNavigationHeaderWidget({
    Key? key,
    required this.currentFeed,
    this.showSearch = false, // Default to false to prevent search button
    this.unreadCount = 0,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(153),
            Colors.transparent,
          ],
        ),
      ),
      padding: EdgeInsets.only(top: topPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Following Button
          _buildNavigationButton(
            context,
            'Following',
            currentFeed == 'following',
            () => _navigateToFeed(context, 'following'),
          ),

          SizedBox(width: 6.w),

          // Discovery Button
          _buildNavigationButton(
            context,
            'Discovery',
            currentFeed == 'discovery',
            () => _navigateToFeed(context, 'discovery'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context,
    String title,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color:
                    isActive ? AppTheme.primaryOrange : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      ),
    );
  }

  void _navigateToFeed(BuildContext context, String feedType) {
    switch (feedType) {
      case 'following':
        if (currentFeed != 'following') {
          Navigator.pushReplacementNamed(context, AppRoutes.followingFeed);
        }
        break;
      case 'discovery':
      case 'for_you':
        if (currentFeed != 'discovery' && currentFeed != 'for_you') {
          Navigator.pushReplacementNamed(context, AppRoutes.discoveryFeed);
        }
        break;
    }
  }
}
