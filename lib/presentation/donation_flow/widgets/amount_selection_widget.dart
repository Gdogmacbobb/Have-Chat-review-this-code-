import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_export.dart';

class AmountSelectionWidget extends StatefulWidget {
  final Function(double) onAmountSelected;
  final double selectedAmount;

  const AmountSelectionWidget({
    Key? key,
    required this.onAmountSelected,
    required this.selectedAmount,
  }) : super(key: key);

  @override
  State<AmountSelectionWidget> createState() => _AmountSelectionWidgetState();
}

class _AmountSelectionWidgetState extends State<AmountSelectionWidget> {
  final TextEditingController _customAmountController = TextEditingController();
  final List<double> _presetAmounts = [1.0, 5.0, 10.0, 20.0, 50.0];
  bool _isCustomAmountSelected = false;

  @override
  void initState() {
    super.initState();
    _customAmountController.addListener(_onCustomAmountChanged);
  }

  @override
  void dispose() {
    _customAmountController.removeListener(_onCustomAmountChanged);
    _customAmountController.dispose();
    super.dispose();
  }

  void _onCustomAmountChanged() {
    final text = _customAmountController.text;
    if (text.isNotEmpty) {
      final amount = double.tryParse(text);
      if (amount != null && amount > 0) {
        setState(() {
          _isCustomAmountSelected = true;
        });
        widget.onAmountSelected(amount);
      }
    }
  }

  void _selectPresetAmount(double amount) {
    HapticFeedback.lightImpact();
    setState(() {
      _isCustomAmountSelected = false;
      _customAmountController.clear();
    });
    widget.onAmountSelected(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Amount',
            style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Preset Amount Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: _presetAmounts.length,
            itemBuilder: (context, index) {
              final amount = _presetAmounts[index];
              final isSelected =
                  widget.selectedAmount == amount && !_isCustomAmountSelected;
              
              return Material(
                color: isSelected
                    ? AppTheme.primaryOrange.withOpacity(0.08)
                    : AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _selectPresetAmount(amount),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
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
                        '\$${amount.toStringAsFixed(0)}',
                        style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                          fontSize: 24,
                          color: isSelected
                              ? AppTheme.primaryOrange
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Custom Amount Input
          Text(
            'Or enter custom amount',
            style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                color: _isCustomAmountSelected
                    ? AppTheme.primaryOrange.withOpacity(0.1)
                    : AppTheme.inputBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isCustomAmountSelected
                      ? AppTheme.primaryOrange
                      : AppTheme.borderSubtle,
                  width: _isCustomAmountSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Text(
                    '\$',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _isCustomAmountSelected
                          ? AppTheme.primaryOrange
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextFormField(
                      controller: _customAmountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          color: AppTheme.textSecondary.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Selected Amount Display
          if (widget.selectedAmount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryOrange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomIconWidget(
                    iconName: 'check_circle',
                    color: AppTheme.primaryOrange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Selected: \$${widget.selectedAmount.toStringAsFixed(2)}',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
