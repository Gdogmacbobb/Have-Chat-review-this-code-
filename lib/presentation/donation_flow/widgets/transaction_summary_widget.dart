import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class TransactionSummaryWidget extends StatelessWidget {
  final double donationAmount;
  final double platformFee;
  final double netAmount;
  final bool isNonRefundableAccepted;
  final Function(bool) onNonRefundableChanged;

  const TransactionSummaryWidget({
    Key? key,
    required this.donationAmount,
    required this.platformFee,
    required this.netAmount,
    required this.isNonRefundableAccepted,
    required this.onNonRefundableChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Summary',
            style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),

          // Summary Container
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderSubtle,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Donation Amount
                _buildSummaryRow(
                  'Donation Amount',
                  '\$${donationAmount.toStringAsFixed(2)}',
                  isTotal: false,
                ),

                SizedBox(height: 1.h),

                // Platform Fee
                _buildSummaryRow(
                  'Platform Fee (5%)',
                  '-\$${platformFee.toStringAsFixed(2)}',
                  isTotal: false,
                  isDeduction: true,
                ),

                SizedBox(height: 1.h),

                // Divider
                Container(
                  height: 1,
                  color: AppTheme.borderSubtle,
                ),

                SizedBox(height: 1.h),

                // Net Amount to Performer
                _buildSummaryRow(
                  'Amount to Performer',
                  '\$${netAmount.toStringAsFixed(2)}',
                  isTotal: true,
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Platform Fee Explanation
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primaryOrange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: AppTheme.primaryOrange,
                  size: 16,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'The 5% platform fee helps us maintain YNFNY and support the street performer community.',
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Non-Refundable Policy
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.accentRed.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomIconWidget(
                      iconName: 'warning',
                      color: AppTheme.accentRed,
                      size: 16,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Non-Refundable Policy',
                        style:
                            AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.accentRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  'All donations are final and non-refundable. By proceeding, you acknowledge that this is a voluntary contribution to support the performer.',
                  style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 1.h),

                // Checkbox for acceptance
                GestureDetector(
                  onTap: () => onNonRefundableChanged(!isNonRefundableAccepted),
                  child: Row(
                    children: [
                      Container(
                        width: 5.w,
                        height: 5.w,
                        decoration: BoxDecoration(
                          color: isNonRefundableAccepted
                              ? AppTheme.primaryOrange
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isNonRefundableAccepted
                                ? AppTheme.primaryOrange
                                : AppTheme.borderSubtle,
                            width: 2,
                          ),
                        ),
                        child: isNonRefundableAccepted
                            ? Center(
                                child: CustomIconWidget(
                                  iconName: 'check',
                                  color: AppTheme.backgroundDark,
                                  size: 12,
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'I understand and accept the non-refundable policy',
                          style:
                              AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: 11.sp,
                          ),
                        ),
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
  }

  Widget _buildSummaryRow(String label, String amount,
      {required bool isTotal, bool isDeduction = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
            color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          amount,
          style: AppTheme.donationAmountStyle(isLight: false).copyWith(
            fontSize: isTotal ? 16.sp : 14.sp,
            color: isDeduction
                ? AppTheme.accentRed
                : isTotal
                    ? AppTheme.primaryOrange
                    : AppTheme.textPrimary,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
