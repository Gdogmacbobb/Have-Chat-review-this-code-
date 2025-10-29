import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class HandleValidationWidget extends StatelessWidget {
  final String handle;

  const HandleValidationWidget({
    Key? key,
    required this.handle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Handle Requirements',
            style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          _buildValidationRule(
            'At least 3 characters',
            handle.length >= 3,
          ),
          SizedBox(height: 1.h),
          _buildValidationRule(
            'Maximum 20 characters',
            handle.length <= 20,
          ),
          SizedBox(height: 1.h),
          _buildValidationRule(
            'Only letters, numbers, periods, and underscores',
            handle.isEmpty || RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(handle),
          ),
          SizedBox(height: 1.h),
          _buildValidationRule(
            'No consecutive special characters',
            handle.isEmpty || !RegExp(r'[._]{2,}').hasMatch(handle),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationRule(String rule, bool isValid) {
    final color = handle.isEmpty
        ? AppTheme.textSecondary
        : isValid
            ? AppTheme.successGreen
            : AppTheme.accentRed;

    final iconName = handle.isEmpty
        ? 'radio_button_unchecked'
        : isValid
            ? 'check_circle'
            : 'cancel';

    return Row(
      children: [
        CustomIconWidget(
          iconName: iconName,
          color: color,
          size: 16,
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(
            rule,
            style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
