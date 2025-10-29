import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class DonationButtonWidget extends StatelessWidget {
  final VoidCallback onDonationTap;

  const DonationButtonWidget({
    super.key,
    required this.onDonationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 10.h,
      right: 4.w,
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showDonationBottomSheet(context);
        },
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: AppTheme.backgroundDark,
        elevation: 4.0,
        icon: CustomIconWidget(
          iconName: 'favorite',
          color: AppTheme.backgroundDark,
          size: 20,
        ),
        label: Text(
          "Donate",
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.backgroundDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showDonationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DonationBottomSheet(
        onDonationComplete: () {
          Navigator.pop(context);
          onDonationTap();
        },
      ),
    );
  }
}

class DonationBottomSheet extends StatefulWidget {
  final VoidCallback onDonationComplete;

  const DonationBottomSheet({
    super.key,
    required this.onDonationComplete,
  });

  @override
  State<DonationBottomSheet> createState() => _DonationBottomSheetState();
}

class _DonationBottomSheetState extends State<DonationBottomSheet> {
  double selectedAmount = 5.0;
  final TextEditingController customAmountController = TextEditingController();
  bool isCustomAmount = false;
  bool isProcessing = false;

  final List<double> presetAmounts = [1.0, 5.0, 10.0, 20.0];

  @override
  void dispose() {
    customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          4.w, 2.h, 4.w, MediaQuery.of(context).viewInsets.bottom + 2.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: AppTheme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 3.h),

          // Title
          Text(
            "Support this performer",
            style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            "Your donation helps support street performers in NYC",
            style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: 3.h),

          // Preset Amount Buttons
          Text(
            "Choose amount",
            style: AppTheme.darkTheme.textTheme.titleMedium,
          ),
          SizedBox(height: 2.h),
          Row(
            children: presetAmounts.map((amount) {
              final isSelected = !isCustomAmount && selectedAmount == amount;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: amount != presetAmounts.last ? 2.w : 0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAmount = amount;
                        isCustomAmount = false;
                        customAmountController.clear();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryOrange.withOpacity(0.2)
                            : AppTheme.inputBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryOrange
                              : AppTheme.borderSubtle,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "\$${amount.toInt()}",
                          style: AppTheme.donationAmountStyle(isLight: false)
                              .copyWith(
                            color: isSelected
                                ? AppTheme.primaryOrange
                                : AppTheme.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 2.h),

          // Custom Amount Input
          Text(
            "Or enter custom amount",
            style: AppTheme.darkTheme.textTheme.titleMedium,
          ),
          SizedBox(height: 1.h),
          TextField(
            controller: customAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTheme.darkTheme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: "Enter amount",
              prefixText: "\$ ",
              prefixStyle: AppTheme.darkTheme.textTheme.bodyLarge,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isCustomAmount
                      ? AppTheme.primaryOrange
                      : AppTheme.borderSubtle,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryOrange,
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() {
                isCustomAmount = value.isNotEmpty;
                if (value.isNotEmpty) {
                  selectedAmount = double.tryParse(value) ?? 0.0;
                }
              });
            },
          ),
          SizedBox(height: 4.h),

          // Donate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (selectedAmount > 0 && !isProcessing)
                  ? _processDonation
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: AppTheme.backgroundDark,
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isProcessing
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.backgroundDark),
                      ),
                    )
                  : Text(
                      "Donate \$${selectedAmount.toStringAsFixed(2)}",
                      style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.backgroundDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 1.h),

          // Disclaimer
          Text(
            "Donations are non-refundable. 5% platform fee applies.",
            style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _processDonation() async {
    if (selectedAmount <= 0) return;

    setState(() {
      isProcessing = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        isProcessing = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CustomIconWidget(
                iconName: 'check_circle',
                color: AppTheme.successGreen,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                "Thank you for your \$${selectedAmount.toStringAsFixed(2)} donation!",
                style: AppTheme.darkTheme.textTheme.bodyMedium,
              ),
            ],
          ),
          backgroundColor: AppTheme.surfaceDark,
          duration: const Duration(seconds: 3),
        ),
      );

      widget.onDonationComplete();
    }
  }
}
