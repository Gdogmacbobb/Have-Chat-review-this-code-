import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';
import 'package:ynfny/core/constants/performance_categories.dart';
import 'package:ynfny/widgets/performance_type_badge.dart';

import '../../../core/app_export.dart';

class PerformerSpecificFields extends StatefulWidget {
  final List<String> selectedPerformanceTypes;
  final Function(String, bool) onCategoryToggled;
  final TextEditingController instagramController;
  final TextEditingController tiktokController;
  final TextEditingController youtubeController;
  final TextEditingController xController;
  final TextEditingController snapchatController;
  final TextEditingController facebookController;
  final TextEditingController soundcloudController;
  final TextEditingController spotifyController;
  final DateTime? selectedBirthDate;
  final Function(DateTime?) onBirthDateChanged;

  const PerformerSpecificFields({
    Key? key,
    required this.selectedPerformanceTypes,
    required this.onCategoryToggled,
    required this.instagramController,
    required this.tiktokController,
    required this.youtubeController,
    required this.xController,
    required this.snapchatController,
    required this.facebookController,
    required this.soundcloudController,
    required this.spotifyController,
    this.selectedBirthDate,
    required this.onBirthDateChanged,
  }) : super(key: key);

  @override
  State<PerformerSpecificFields> createState() =>
      _PerformerSpecificFieldsState();
}

class _PerformerSpecificFieldsState extends State<PerformerSpecificFields> {
  @override
  Widget build(BuildContext context) {
    final mainCategories = PerformanceCategories.getMainCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Age Verification',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.primaryOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          'You must be 18 or older to create an account',
          style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: 2.h),

        Text(
          'Date of Birth',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        GestureDetector(
          onTap: () => _selectBirthDate(context),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.w),
            decoration: BoxDecoration(
              color: AppTheme.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderSubtle,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'calendar_today',
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    widget.selectedBirthDate != null
                        ? '${widget.selectedBirthDate!.month}/${widget.selectedBirthDate!.day}/${widget.selectedBirthDate!.year}'
                        : 'Select your birth date',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: widget.selectedBirthDate != null
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ),
                CustomIconWidget(
                  iconName: 'arrow_drop_down',
                  color: AppTheme.textSecondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),

        if (widget.selectedBirthDate != null)
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: _isAgeValid() ? 'check_circle' : 'error',
                  color: _isAgeValid()
                      ? AppTheme.successGreen
                      : AppTheme.accentRed,
                  size: 16,
                ),
                SizedBox(width: 2.w),
                Text(
                  _isAgeValid()
                      ? 'Age verified (${_calculateAge()} years old)'
                      : 'You must be 18 or older to register',
                  style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                    color: _isAgeValid()
                        ? AppTheme.successGreen
                        : AppTheme.accentRed,
                  ),
                ),
              ],
            ),
          ),

        SizedBox(height: 4.h),

        Text(
          'Performance Types',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.primaryOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          'Select your performance categories',
          style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: 2.h),

        // Main Category Wrap with unified badges
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: mainCategories.map((category) {
            final isSelected = widget.selectedPerformanceTypes.contains(category);
            
            return PerformanceTypeBadge(
              label: category,
              isActive: isSelected,
              isSelectable: true,
              onTap: () {
                widget.onCategoryToggled(category, !isSelected);
              },
            );
          }).toList(),
        ),

        SizedBox(height: 4.h),

        // Social Media Verification Section
        Text(
          'Social Media Verification',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.primaryOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          'Link your social media accounts to verify your performance history (at least one required)',
          style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: 2.h),

        // Instagram Handle
        Text(
          'Instagram Handle',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.instagramController,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: '@username',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'camera_alt',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.startsWith('@')) {
                return 'Instagram handle must start with @';
              }
              if (value.length < 2) {
                return 'Please enter a valid Instagram handle';
              }
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // TikTok Handle
        Text(
          'TikTok Handle',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.tiktokController,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: '@username',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'video_library',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.startsWith('@')) {
                return 'TikTok handle must start with @';
              }
              if (value.length < 2) {
                return 'Please enter a valid TikTok handle';
              }
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // YouTube Channel
        Text(
          'YouTube Channel',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.youtubeController,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Channel name or URL',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'play_circle',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty && value.length < 2) {
              return 'Please enter a valid YouTube channel';
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // X (Twitter) Handle
        Text(
          'X (Twitter) Handle',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.xController,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: '@username',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'tag',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.startsWith('@')) {
                return 'X handle must start with @';
              }
              if (value.length < 2) {
                return 'Please enter a valid X handle';
              }
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // Snapchat Handle
        Text(
          'Snapchat Handle',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.snapchatController,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: '@username',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'camera_alt',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.startsWith('@')) {
                return 'Snapchat handle must start with @';
              }
              if (value.length < 2) {
                return 'Please enter a valid Snapchat handle';
              }
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // Facebook Profile
        Text(
          'Facebook Profile',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.facebookController,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Profile name or URL',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'group',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty && value.length < 2) {
              return 'Please enter a valid Facebook profile';
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // SoundCloud Profile
        Text(
          'SoundCloud Profile',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.soundcloudController,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: '@username',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'audiotrack',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.startsWith('@')) {
                return 'SoundCloud handle must start with @';
              }
              if (value.length < 2) {
                return 'Please enter a valid SoundCloud handle';
              }
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // Spotify Profile
        Text(
          'Spotify Artist',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.spotifyController,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Artist name or URL',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'music_note',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty && value.length < 2) {
              return 'Please enter a valid Spotify artist name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme.copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppTheme.darkTheme.colorScheme.surface,
              headerBackgroundColor: AppTheme.primaryOrange,
              headerForegroundColor: AppTheme.backgroundDark,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.backgroundDark;
                }
                return AppTheme.textPrimary;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primaryOrange;
                }
                return Colors.transparent;
              }),
              todayForegroundColor:
                  WidgetStateProperty.all(AppTheme.primaryOrange),
              todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
              todayBorder: const BorderSide(color: AppTheme.primaryOrange),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != widget.selectedBirthDate) {
      widget.onBirthDateChanged(picked);
    }
  }

  bool _isAgeValid() {
    if (widget.selectedBirthDate == null) return false;
    return _calculateAge() >= 18;
  }

  int _calculateAge() {
    if (widget.selectedBirthDate == null) return 0;
    final now = DateTime.now();
    int age = now.year - widget.selectedBirthDate!.year;
    if (now.month < widget.selectedBirthDate!.month ||
        (now.month == widget.selectedBirthDate!.month &&
            now.day < widget.selectedBirthDate!.day)) {
      age--;
    }
    return age;
  }
}
