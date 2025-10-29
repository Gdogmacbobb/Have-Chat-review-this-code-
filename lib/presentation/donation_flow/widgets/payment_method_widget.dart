import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class PaymentMethodWidget extends StatefulWidget {
  final Function(String) onPaymentMethodSelected;
  final String selectedPaymentMethod;

  const PaymentMethodWidget({
    Key? key,
    required this.onPaymentMethodSelected,
    required this.selectedPaymentMethod,
  }) : super(key: key);

  @override
  State<PaymentMethodWidget> createState() => _PaymentMethodWidgetState();
}

class _PaymentMethodWidgetState extends State<PaymentMethodWidget> {
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'apple_pay',
      'name': 'Apple Pay',
      'icon': 'apple',
      'available': true,
    },
    {
      'id': 'google_pay',
      'name': 'Google Pay',
      'icon': 'google',
      'available': true,
    },
    {
      'id': 'card_1234',
      'name': 'Visa •••• 1234',
      'icon': 'credit_card',
      'available': true,
    },
    {
      'id': 'card_5678',
      'name': 'Mastercard •••• 5678',
      'icon': 'credit_card',
      'available': true,
    },
  ];

  void _selectPaymentMethod(String methodId) {
    widget.onPaymentMethodSelected(methodId);
  }

  void _addNewCard() {
    // Navigate to add card screen or show modal
    showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surfaceDark,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => Container(
            padding: const EdgeInsets.all(16),
            height: 320,
            child: Column(children: [
              Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.borderSubtle,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Add New Card',
                  style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 24),
              Text(
                  'This feature will integrate with Stripe for secure card management.',
                  style: AppTheme.darkTheme.textTheme.bodyMedium
                      ?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment Method',
              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),

          // Payment Methods List
          ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paymentMethods.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final method = _paymentMethods[index];
                final isSelected = widget.selectedPaymentMethod == method['id'];

                return GestureDetector(
                    onTap: () => _selectPaymentMethod(method['id'] as String),
                    child: SizedBox(
                        height: 64,
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryOrange.withOpacity(0.08)
                                    : AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryOrange
                                        : AppTheme.borderSubtle,
                                    width: isSelected ? 2 : 1)),
                            child: Row(children: [
                              SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Center(
                                      child: CustomIconWidget(
                                          iconName: method['icon'] as String,
                                          color: AppTheme.textPrimary,
                                          size: 20))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(method['name'] as String,
                                      style: AppTheme.darkTheme.textTheme.bodyLarge
                                          ?.copyWith(
                                              color: AppTheme.textPrimary,
                                              fontWeight: FontWeight.w500))),
                              if (isSelected)
                                Icon(
                                    Icons.check_circle,
                                    color: AppTheme.primaryOrange,
                                    size: 20),
                            ]))));
              }),

          const SizedBox(height: 16),

          // Add New Card Button
          GestureDetector(
              onTap: _addNewCard,
              child: SizedBox(
                  height: 64,
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.primaryOrange, width: 2)),
                      child: Row(children: [
                        SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                                child: Icon(
                                    Icons.add,
                                    color: AppTheme.primaryOrange,
                                    size: 20))),
                        const SizedBox(width: 12),
                        Text('Add New Card',
                            style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.w500)),
                      ])))),
        ]));
  }
}
