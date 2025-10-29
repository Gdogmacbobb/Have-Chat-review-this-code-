import 'package:flutter/material.dart';
import 'package:ynfny/core/app_export.dart';
import 'package:ynfny/utils/responsive_scale.dart';

/// Reusable primary action button used across authentication screens.
/// Fixed 56px height ensures consistent rendering without compression.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  static const double _fixedHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _fixedHeight,
      child: ElevatedButton(
        onPressed: (onPressed != null && !isLoading) ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null
              ? AppTheme.primaryOrange
              : AppTheme.borderSubtle,
          foregroundColor: onPressed != null
              ? AppTheme.backgroundDark
              : AppTheme.textSecondary,
          disabledBackgroundColor: AppTheme.borderSubtle,
          elevation: onPressed != null ? 2.0 : 0,
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2.w),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.backgroundDark,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                      color: onPressed != null
                          ? AppTheme.backgroundDark
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  if (icon != null) ...[
                    SizedBox(width: 2.w),
                    Icon(
                      icon,
                      size: 5.w,
                      color: onPressed != null
                          ? AppTheme.backgroundDark
                          : AppTheme.textSecondary,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
