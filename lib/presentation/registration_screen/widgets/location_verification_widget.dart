import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class LocationVerificationWidget extends StatefulWidget {
  final bool isLocationVerified;
  final Function() onVerifyLocation;
  final String? selectedBorough;
  final Function(String?) onBoroughChanged;

  const LocationVerificationWidget({
    Key? key,
    required this.isLocationVerified,
    required this.onVerifyLocation,
    this.selectedBorough,
    required this.onBoroughChanged,
  }) : super(key: key);

  @override
  State<LocationVerificationWidget> createState() =>
      _LocationVerificationWidgetState();
}

class _LocationVerificationWidgetState
    extends State<LocationVerificationWidget> {
  bool _isVerifying = false;

  final List<Map<String, String>> boroughs = [
    {'value': 'manhattan', 'label': 'Manhattan'},
    {'value': 'brooklyn', 'label': 'Brooklyn'},
    {'value': 'queens', 'label': 'Queens'},
    {'value': 'bronx', 'label': 'The Bronx'},
    {'value': 'staten_island', 'label': 'Staten Island'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isLocationVerified
              ? AppTheme.successGreen
              : AppTheme.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: 'location_on',
                color: widget.isLocationVerified
                    ? AppTheme.successGreen
                    : AppTheme.primaryOrange,
                size: 24,
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'NYC Location Verification',
                  style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.isLocationVerified)
                CustomIconWidget(
                  iconName: 'check_circle',
                  color: AppTheme.successGreen,
                  size: 20,
                ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            widget.isLocationVerified
                ? 'Your location has been verified as within NYC limits.'
                : 'We need to verify you\'re in New York City to ensure authentic local content.',
            style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 3.h),
          if (!widget.isLocationVerified) ...[
            // GPS Verification Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isVerifying ? null : _handleLocationVerification,
                icon: _isVerifying
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.backgroundDark,
                          ),
                        ),
                      )
                    : CustomIconWidget(
                        iconName: 'my_location',
                        color: AppTheme.backgroundDark,
                        size: 20,
                      ),
                label: Text(
                    _isVerifying ? 'Verifying Location...' : 'Verify with GPS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: AppTheme.backgroundDark,
                ),
              ),
            ),
            SizedBox(height: 2.h),

            // Divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AppTheme.borderSubtle,
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    'OR',
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AppTheme.borderSubtle,
                    thickness: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),

            // Manual Borough Selection
            Text(
              'Select Your Borough',
              style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 1.h),
            DropdownButtonFormField<String>(
              value: widget.selectedBorough,
              decoration: InputDecoration(
                hintText: 'Choose your NYC borough',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'location_city',
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ),
              dropdownColor: AppTheme.darkTheme.colorScheme.surface,
              items: boroughs.map((borough) {
                return DropdownMenuItem<String>(
                  value: borough['value'],
                  child: Text(
                    borough['label']!,
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: widget.onBoroughChanged,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your borough';
                }
                return null;
              },
            ),
          ] else ...[
            // Verified Status
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.successGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'verified',
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'Location verified successfully',
                      style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleLocationVerification() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      // Simulate GPS verification process
      await Future.delayed(const Duration(seconds: 2));

      // Mock verification success (in real app, this would use actual GPS)
      widget.onVerifyLocation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CustomIconWidget(
                  iconName: 'check_circle',
                  color: AppTheme.successGreen,
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Text(
                  'Location verified successfully!',
                  style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.darkTheme.colorScheme.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CustomIconWidget(
                  iconName: 'error',
                  color: AppTheme.accentRed,
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'Unable to verify location. Please select your borough manually.',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.darkTheme.colorScheme.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }
}
