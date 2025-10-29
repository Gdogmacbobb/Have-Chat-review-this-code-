import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class LoginHeaderWidget extends StatelessWidget {
  const LoginHeaderWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth * 0.45; // 45% of screen width for full visibility
    
    return Column(
      children: [
        // YNFNY Logo - Full resolution display
        Center(
          child: Container(
            width: logoSize,
            height: logoSize,
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowDark,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/YNFNY_Logo_Web.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Statue of Liberty silhouette
                        CustomIconWidget(
                          iconName: 'account_balance',
                          color: AppTheme.textSecondary,
                          size: logoSize * 0.5,
                        ),
                        // Red glowing eyes effect
                        Positioned(
                          top: logoSize * 0.25,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: logoSize * 0.05,
                                height: logoSize * 0.05,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRed,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentRed
                                          .withOpacity(0.6),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: logoSize * 0.08),
                              Container(
                                width: logoSize * 0.05,
                                height: logoSize * 0.05,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRed,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentRed
                                          .withOpacity(0.6),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        SizedBox(height: 4.h),

        // YNFNY Brand Text
        Text(
          'YNFNY',
          style: AppTheme.darkTheme.textTheme.headlineLarge?.copyWith(
            color: AppTheme.primaryOrange,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),

        SizedBox(height: 0.5.h),

        // WE OUTSIDE Tagline
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2.w),
            border: Border.all(
              color: AppTheme.primaryOrange.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            'WE OUTSIDE',
            style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
              color: AppTheme.primaryOrange,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),

        SizedBox(height: 3.h),

        // Welcome Back Text
        Text(
          'Welcome Back',
          style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),

        SizedBox(height: 0.5.h),

        // Subtitle
        Text(
          'Sign in to discover NYC street performers',
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
