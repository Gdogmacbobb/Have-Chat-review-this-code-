import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';
import 'package:ynfny/core/constants/performance_categories.dart';

import '../../../core/app_export.dart';
import 'performance_type_row.dart';

class AboutSectionWidget extends StatelessWidget {
  final Map<String, dynamic> performerData;

  const AboutSectionWidget({
    super.key,
    required this.performerData,
  });
  
  // Performance type definitions for normalization
  static const List<Map<String, String>> performanceTypes = [
    {'value': 'music', 'label': 'Music', 'icon': 'music_note', 'emoji': '🎵'},
    {'value': 'dance', 'label': 'Dance', 'icon': 'accessibility_new', 'emoji': '💃'},
    {'value': 'visual_arts', 'label': 'Visual Arts', 'icon': 'palette', 'emoji': '🎨'},
    {'value': 'comedy', 'label': 'Comedy', 'icon': 'theater_comedy', 'emoji': '🎭'},
    {'value': 'magic', 'label': 'Magic', 'icon': 'auto_fix_high', 'emoji': '✨'},
    {'value': 'other', 'label': 'Other', 'icon': 'auto_awesome', 'emoji': '⭐'},
  ];
  
  // Helper to normalize category (convert slug to label if needed)
  String? _normalizeCategoryToLabel(String? category) {
    if (category == null) return null;
    
    // Check if it's already a label
    final isLabel = performanceTypes.any((t) => t['label'] == category);
    if (isLabel) return category;
    
    // Convert slug to label
    final type = performanceTypes.firstWhere(
      (t) => t['value'] == category,
      orElse: () => {},
    );
    return type['label'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio Section
          if (performerData["bio"] != null &&
              (performerData["bio"] as String).isNotEmpty)
            _buildSection(
              "About",
              Text(
                performerData["bio"] as String,
                style: AppTheme.darkTheme.textTheme.bodyMedium,
              ),
            ),

          // Performance Types Section (supports both single and multiple types)
          if (_hasPerformanceTypes(performerData))
            _buildSection(
              "Performance Types",
              _buildPerformanceTypesWidget(performerData),
            ),

          // Social Media Links (moved before location/schedule)
          if (_hasSocialMedia(performerData))
            _buildSection(
              "Social Media",
              Column(
                children: _buildSocialMediaLinks(performerData),
              ),
            ),

          // Frequent Performance Location (single field with map link)
          if (performerData["frequent_location"] != null && 
              (performerData["frequent_location"] as String).isNotEmpty)
            _buildSection(
              "Frequent Performance Location",
              Builder(
                builder: (context) => InkWell(
                  onTap: () {
                    final location = performerData["frequent_location"] as String;
                    final mapsUrl = 'https://www.google.com/maps/search/${Uri.encodeComponent(location)}';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Opening Google Maps: $location"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: AppTheme.performerCardDecoration(),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'location_on',
                          color: AppTheme.primaryOrange,
                          size: 20,
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Text(
                            performerData["frequent_location"] as String,
                            style: AppTheme.darkTheme.textTheme.bodyMedium,
                          ),
                        ),
                        CustomIconWidget(
                          iconName: 'open_in_new',
                          color: AppTheme.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Performance Schedule (single field display)
          if (performerData["performance_schedule"] != null && 
              (performerData["performance_schedule"] as String).isNotEmpty)
            _buildSection(
              "Performance Schedule",
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: AppTheme.performerCardDecoration(),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'schedule',
                      color: AppTheme.primaryOrange,
                      size: 20,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        performerData["performance_schedule"] as String,
                        style: AppTheme.darkTheme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Stats Section
          _buildSection(
            "Statistics",
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: AppTheme.performerCardDecoration(),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                          "Total Videos",
                          (performerData["videoCount"] as int? ?? 0)
                              .toString()),
                      _buildStatItem(
                          "Total Views",
                          _formatCount(
                              performerData["totalViews"] as int? ?? 0)),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                          "Total Likes",
                          _formatCount(
                              performerData["totalLikes"] as int? ?? 0)),
                      _buildStatItem(
                          "Member Since",
                          _formatJoinDate(
                              performerData["joinDate"] as String? ?? "")),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        content,
        SizedBox(height: 3.h),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTheme.performerStatsStyle(isLight: false).copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          label,
          style: AppTheme.darkTheme.textTheme.bodySmall,
        ),
      ],
    );
  }

  bool _hasPerformanceTypes(Map<String, dynamic> data) {
    if (data['performance_types'] != null) {
      if (data['performance_types'] is List) {
        return (data['performance_types'] as List).isNotEmpty;
      } else if (data['performance_types'] is Map) {
        return (data['performance_types'] as Map).isNotEmpty;
      }
    }
    return false;
  }

  Widget _buildPerformanceTypesWidget(Map<String, dynamic> data) {
    if (data['performance_types'] != null && data['performance_types'] is List) {
      final performanceTypesList = (data['performance_types'] as List)
          .map((e) => e.toString())
          .toList();
      
      return PerformanceTypeRow(performanceTypes: performanceTypesList);
    }
    
    if (data['performance_types'] != null && data['performance_types'] is Map) {
      final performanceTypesMap = Map<String, dynamic>.from(data['performance_types'] as Map);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: performanceTypesMap.entries.map((entry) {
          final category = entry.key as String;
          final subcategories = entry.value is List 
              ? (entry.value as List).cast<String>() 
              : <String>[];
          
          return Container(
            margin: EdgeInsets.only(bottom: 2.h),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryOrange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PerformanceCategories.getEmoji(category),
                  style: TextStyle(fontSize: 20),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: category,
                          style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                        if (subcategories.isNotEmpty)
                          TextSpan(
                            text: " — ${subcategories.join(", ")}",
                            style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: AppTheme.performerCardDecoration(),
      child: Row(
        children: [
          CustomIconWidget(
            iconName: 'auto_awesome',
            color: AppTheme.primaryOrange,
            size: 20,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: _normalizeCategoryToLabel(data["main_performance_category"] as String?) ?? 
                          data["main_performance_category"] as String,
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  if (data["performance_subcategories"] != null && 
                      (data["performance_subcategories"] as List).isNotEmpty)
                    TextSpan(
                      text: " — ${(data["performance_subcategories"] as List).join(", ")}",
                      style: AppTheme.darkTheme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasSocialMedia(Map<String, dynamic> data) {
    return (data['socials_instagram'] != null && (data['socials_instagram'] as String).isNotEmpty) ||
           (data['socials_tiktok'] != null && (data['socials_tiktok'] as String).isNotEmpty) ||
           (data['socials_youtube'] != null && (data['socials_youtube'] as String).isNotEmpty) ||
           (data['socials_x'] != null && (data['socials_x'] as String).isNotEmpty) ||
           (data['socials_snapchat'] != null && (data['socials_snapchat'] as String).isNotEmpty) ||
           (data['socials_facebook'] != null && (data['socials_facebook'] as String).isNotEmpty) ||
           (data['socials_soundcloud'] != null && (data['socials_soundcloud'] as String).isNotEmpty) ||
           (data['socials_spotify'] != null && (data['socials_spotify'] as String).isNotEmpty);
  }

  List<Widget> _buildSocialMediaLinks(Map<String, dynamic> data) {
    List<Widget> links = [];
    
    // Instagram
    if (data['socials_instagram'] != null && (data['socials_instagram'] as String).isNotEmpty) {
      links.add(_buildSocialMediaItem(
        'Instagram',
        data['socials_instagram'] as String,
        Icons.camera_alt,
        'https://instagram.com/${_removeAtSymbol(data['socials_instagram'] as String)}',
      ));
    }
    
    // TikTok
    if (data['socials_tiktok'] != null && (data['socials_tiktok'] as String).isNotEmpty) {
      links.add(_buildSocialMediaItem(
        'TikTok',
        data['socials_tiktok'] as String,
        Icons.music_note,
        'https://tiktok.com/@${_removeAtSymbol(data['socials_tiktok'] as String)}',
      ));
    }
    
    // YouTube
    if (data['socials_youtube'] != null && (data['socials_youtube'] as String).isNotEmpty) {
      links.add(_buildSocialMediaItem(
        'YouTube',
        data['socials_youtube'] as String,
        Icons.play_circle_filled,
        'https://youtube.com/${_removeAtSymbol(data['socials_youtube'] as String)}',
      ));
    }
    
    // X (Twitter)
    if (data['socials_x'] != null && (data['socials_x'] as String).isNotEmpty) {
      links.add(_buildSocialMediaItem(
        'X (Twitter)',
        data['socials_x'] as String,
        Icons.tag,
        'https://x.com/${_removeAtSymbol(data['socials_x'] as String)}',
      ));
    }
    
    // Snapchat
    if (data['socials_snapchat'] != null && (data['socials_snapchat'] as String).isNotEmpty) {
      links.add(_buildSocialMediaItem(
        'Snapchat',
        data['socials_snapchat'] as String,
        Icons.camera_alt,
        'https://www.snapchat.com/add/${_removeAtSymbol(data['socials_snapchat'] as String)}',
      ));
    }
    
    // Facebook
    if (data['socials_facebook'] != null && (data['socials_facebook'] as String).isNotEmpty) {
      links.add(_buildSocialMediaItem(
        'Facebook',
        data['socials_facebook'] as String,
        Icons.group,
        'https://facebook.com/${_removeAtSymbol(data['socials_facebook'] as String)}',
      ));
    }
    
    // SoundCloud
    if (data['socials_soundcloud'] != null && (data['socials_soundcloud'] as String).isNotEmpty) {
      links.add(_buildSocialMediaItem(
        'SoundCloud',
        data['socials_soundcloud'] as String,
        Icons.audiotrack,
        'https://soundcloud.com/${_removeAtSymbol(data['socials_soundcloud'] as String)}',
      ));
    }
    
    // Spotify
    if (data['socials_spotify'] != null && (data['socials_spotify'] as String).isNotEmpty) {
      links.add(_buildSocialMediaItem(
        'Spotify',
        data['socials_spotify'] as String,
        Icons.music_note,
        'https://open.spotify.com/artist/${_removeAtSymbol(data['socials_spotify'] as String)}',
      ));
    }
    
    return links;
  }

  Widget _buildSocialMediaItem(String platform, String handle, IconData icon, String url) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      child: Builder(
        builder: (context) => InkWell(
          onTap: () {
            // Handle social media link tap - could use url_launcher here
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Opening $platform: $url"),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(3.w),
            decoration: AppTheme.performerCardDecoration(),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryOrange,
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platform,
                        style: AppTheme.darkTheme.textTheme.titleSmall,
                      ),
                      Text(
                        handle,
                        style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomIconWidget(
                  iconName: 'open_in_new',
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _removeAtSymbol(String handle) {
    return handle.startsWith('@') ? handle.substring(1) : handle;
  }

  String _getSocialMediaIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return 'camera_alt';
      case 'tiktok':
        return 'music_note';
      case 'youtube':
        return 'play_circle_filled';
      case 'twitter':
        return 'alternate_email';
      default:
        return 'link';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return "${(count / 1000000).toStringAsFixed(1)}M";
    } else if (count >= 1000) {
      return "${(count / 1000).toStringAsFixed(1)}K";
    }
    return count.toString();
  }

  String _formatJoinDate(String dateString) {
    if (dateString.isEmpty) return "Unknown";
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays >= 365) {
        return "${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago";
      } else if (difference.inDays >= 30) {
        return "${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago";
      } else {
        return "${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago";
      }
    } catch (e) {
      return "Unknown";
    }
  }
}
