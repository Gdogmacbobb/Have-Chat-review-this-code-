import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class ProfileSectionWidget extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Function(String) onItemTap;

  const ProfileSectionWidget({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.0),
      decoration: AppTheme.performerCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
            child: Text(
              title,
              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                color: AppTheme.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(
              color: AppTheme.borderSubtle.withOpacity(0.3),
              height: 1,
              indent: 16.0,
              endIndent: 16.0,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                leading: CustomIconWidget(
                  iconName: item["icon"] as String,
                  color: AppTheme.textSecondary,
                  size: 24.0,
                ),
                title: Text(
                  item["title"] as String,
                  style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                subtitle: item["subtitle"] != null
                    ? Text(
                        item["subtitle"] as String,
                        style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : null,
                trailing: item["showBadge"] == true
                    ? Container(
                        width: 8.0,
                        height: 8.0,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentRed,
                          shape: BoxShape.circle,
                        ),
                      )
                    : CustomIconWidget(
                        iconName: 'chevron_right',
                        color: AppTheme.textSecondary,
                        size: 20.0,
                      ),
                onTap: () => onItemTap(item["route"] as String? ?? ""),
              );
            },
          ),
        ],
      ),
    );
  }
}
