import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class PerformerStatsWidget extends StatelessWidget {
  final Map<String, dynamic> performerData;

  const PerformerStatsWidget({
    super.key,
    required this.performerData,
  });

  @override
  Widget build(BuildContext context) {
    final totalEarnings = performerData["totalEarnings"] as double? ?? 0.0;
    final followerCount = performerData["followerCount"] as int? ?? 0;
    final videoCount = performerData["videoCount"] as int? ?? 0;
    final monthlyEarnings = performerData["monthlyEarnings"] as double? ?? 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.0),
      decoration: AppTheme.performerCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Performance Stats",
            style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 24.0),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  "Total Earnings",
                  "\$${totalEarnings.toStringAsFixed(2)}",
                  CustomIconWidget(
                    iconName: 'attach_money',
                    color: AppTheme.successGreen,
                    size: 24.0,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 64.0,
                color: AppTheme.borderSubtle,
              ),
              Expanded(
                child: _buildStatItem(
                  "Followers",
                  _formatNumber(followerCount),
                  CustomIconWidget(
                    iconName: 'people',
                    color: AppTheme.primaryOrange,
                    size: 24.0,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  "Videos",
                  _formatNumber(videoCount),
                  CustomIconWidget(
                    iconName: 'video_library',
                    color: AppTheme.accentRed,
                    size: 24.0,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 64.0,
                color: AppTheme.borderSubtle,
              ),
              Expanded(
                child: _buildStatItem(
                  "This Month",
                  "\$${monthlyEarnings.toStringAsFixed(2)}",
                  CustomIconWidget(
                    iconName: 'trending_up',
                    color: AppTheme.successGreen,
                    size: 24.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Widget icon) {
    return Column(
      children: [
        icon,
        SizedBox(height: 8.0),
        Text(
          value,
          style: AppTheme.performerStatsStyle(isLight: false).copyWith(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4.0),
        Text(
          label,
          style: AppTheme.darkTheme.textTheme.labelMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return "${(number / 1000000).toStringAsFixed(1)}M";
    } else if (number >= 1000) {
      return "${(number / 1000).toStringAsFixed(1)}K";
    }
    return number.toString();
  }
}
