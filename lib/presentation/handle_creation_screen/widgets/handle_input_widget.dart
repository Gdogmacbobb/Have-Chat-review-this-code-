import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class HandleInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isValidating;
  final bool isAvailable;
  final String? error;

  const HandleInputWidget({
    Key? key,
    required this.controller,
    required this.focusNode,
    this.isValidating = false,
    this.isAvailable = false,
    this.error,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Handle',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          maxLength: 20,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
          ],
          style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
            color: Colors.white, // Explicitly white for maximum visibility
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Choose your unique handle',
            hintStyle: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary, // Gray for hint text
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: Text(
                '@',
                style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            suffixIcon: _buildSuffixIcon(),
            errorText: error,
            counterText: '${controller.text.length}/20',
            counterStyle: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onChanged: (value) {
            // Convert to lowercase for consistency
            if (value != value.toLowerCase()) {
              controller.value = controller.value.copyWith(
                text: value.toLowerCase(),
                selection: TextSelection.collapsed(
                  offset: value.toLowerCase().length,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (isValidating) {
      return Padding(
        padding: EdgeInsets.all(3.w),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.primaryOrange,
            ),
          ),
        ),
      );
    }

    if (isAvailable && controller.text.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.all(3.w),
        child: CustomIconWidget(
          iconName: 'check_circle',
          color: AppTheme.successGreen,
          size: 20,
        ),
      );
    }

    if (error != null && controller.text.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.all(3.w),
        child: CustomIconWidget(
          iconName: 'error',
          color: AppTheme.accentRed,
          size: 20,
        ),
      );
    }

    return null;
  }
}
