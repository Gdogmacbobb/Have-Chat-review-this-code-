import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class ActivityItemWidget extends StatelessWidget {
  final Map<String, dynamic> activity;

  const ActivityItemWidget({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final activityType = activity["type"] as String? ?? "";
    final timestamp = activity["timestamp"] as DateTime? ?? DateTime.now();
    final timeAgo = _getTimeAgo(timestamp);

    return Container(
      padding: EdgeInsets.all(12.0),
      margin: EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.borderSubtle.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              color: _getActivityColor(activityType).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CustomIconWidget(
                iconName: _getActivityIcon(activityType),
                color: _getActivityColor(activityType),
                size: 20.0,
              ),
            ),
          ),
          SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getActivityTitle(activity),
                  style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.0),
                Text(
                  timeAgo,
                  style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (activity["amount"] != null) ...[
            Text(
              "\$${(activity["amount"] as double).toStringAsFixed(2)}",
              style: AppTheme.donationAmountStyle(isLight: false).copyWith(
                fontSize: 14.0,
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getActivityIcon(String type) {
    switch (type) {
      case 'like':
        return 'favorite';
      case 'comment':
        return 'chat_bubble';
      case 'follow':
        return 'person_add';
      case 'donation_received':
        return 'attach_money';
      case 'donation_sent':
        return 'volunteer_activism';
      case 'video_posted':
        return 'video_library';
      default:
        return 'notifications';
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'like':
        return AppTheme.accentRed;
      case 'comment':
        return AppTheme.primaryOrange;
      case 'follow':
        return AppTheme.primaryOrange;
      case 'donation_received':
      case 'donation_sent':
        return AppTheme.successGreen;
      case 'video_posted':
        return AppTheme.accentRed;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getActivityTitle(Map<String, dynamic> activity) {
    final type = activity["type"] as String? ?? "";
    final userName = activity["userName"] as String? ?? "Someone";

    switch (type) {
      case 'like':
        return "$userName liked your video";
      case 'comment':
        return "$userName commented on your video";
      case 'follow':
        return "$userName started following you";
      case 'donation_received':
        return "Received donation from $userName";
      case 'donation_sent':
        return "Donated to $userName";
      case 'video_posted':
        return "You posted a new video";
      default:
        return "New activity";
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return "${difference.inDays}d ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours}h ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes}m ago";
    } else {
      return "Just now";
    }
  }
}
