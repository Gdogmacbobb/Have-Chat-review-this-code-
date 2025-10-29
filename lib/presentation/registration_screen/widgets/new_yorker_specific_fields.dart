import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class NewYorkerSpecificFields extends StatefulWidget {
  final DateTime? selectedBirthDate;
  final Function(DateTime?) onBirthDateChanged;
  final String? selectedBorough;
  final Function(String?) onBoroughChanged;

  const NewYorkerSpecificFields({
    Key? key,
    this.selectedBirthDate,
    required this.onBirthDateChanged,
    this.selectedBorough,
    required this.onBoroughChanged,
  }) : super(key: key);

  @override
  State<NewYorkerSpecificFields> createState() =>
      _NewYorkerSpecificFieldsState();
}

class _NewYorkerSpecificFieldsState extends State<NewYorkerSpecificFields> {
  final List<Map<String, dynamic>> boroughs = [
    {
      'value': 'manhattan',
      'label': 'Manhattan',
      'icon': 'location_city',
    },
    {
      'value': 'brooklyn',
      'label': 'Brooklyn',
      'icon': 'home',
    },
    {
      'value': 'queens',
      'label': 'Queens',
      'icon': 'apartment',
    },
    {
      'value': 'bronx',
      'label': 'The Bronx',
      'icon': 'business',
    },
    {
      'value': 'staten_island',
      'label': 'Staten Island',
      'icon': 'nature',
    },
    {
      'value': 'visitor',
      'label': 'Frequent Visitor',
      'icon': 'flight',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Age Verification Section
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

        // Birth Date Field
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

        // Age validation message
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

        // NYC Residency Section
        Text(
          'NYC Connection',
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.primaryOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          'Select your connection to New York City',
          style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: 2.h),

        // Borough Selection Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 3.w,
            mainAxisSpacing: 2.h,
            childAspectRatio: 2.2,
          ),
          itemCount: boroughs.length,
          itemBuilder: (context, index) {
            final borough = boroughs[index];
            final isSelected = widget.selectedBorough == borough['value'];

            return GestureDetector(
              onTap: () {
                widget.onBoroughChanged(borough['value']);
              },
              child: Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryOrange.withOpacity(0.2)
                      : AppTheme.darkTheme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryOrange
                        : AppTheme.borderSubtle,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: borough['icon'],
                      color: isSelected
                          ? AppTheme.primaryOrange
                          : AppTheme.textSecondary,
                      size: 24,
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      borough['label'],
                      style: AppTheme.darkTheme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? AppTheme.primaryOrange
                            : AppTheme.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
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
