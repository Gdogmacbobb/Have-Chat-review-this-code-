import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';

class RetryConnectionWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const RetryConnectionWidget({
    Key? key,
    required this.onRetry,
    this.message = 'Connection timeout. Please check your network.',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Warning icon
          Container(
            width: 60.0,
            height: 60.0,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryOrange,
                width: 2,
              ),
            ),
            child: CustomIconWidget(
              iconName: 'wifi_off',
              color: AppTheme.primaryOrange,
              size: 32.0,
            ),
          ),
          SizedBox(height: 24.0),
          // Error message
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.0),
          // Primary message
          Text(
            'YOU NOT FROM NEW YORK',
            style: GoogleFonts.inter(
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentRed,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.0),
          Text(
            'Make sure you\'re connected to the internet and try again.',
            style: GoogleFonts.inter(
              fontSize: 14.0,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.0),
          // Retry button
          SizedBox(
            width: 240.0,
            height: 48.0,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: AppTheme.backgroundDark,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'refresh',
                    color: AppTheme.backgroundDark,
                    size: 20.0,
                  ),
                  SizedBox(width: 8.0),
                  Text(
                    'Try Again',
                    style: GoogleFonts.inter(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
