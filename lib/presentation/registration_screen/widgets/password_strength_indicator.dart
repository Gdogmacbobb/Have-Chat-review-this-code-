import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    Key? key,
    required this.password,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final strength = _calculatePasswordStrength(password);
    final requirements = _getPasswordRequirements(password);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Password Strength: ',
                style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                _getStrengthText(strength),
                style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                  color: _getStrengthColor(strength),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          LinearProgressIndicator(
            value: strength / 4,
            backgroundColor: AppTheme.borderSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getStrengthColor(strength),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Requirements:',
            style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 1.h),
          ...requirements
              .map((requirement) => Padding(
                    padding: EdgeInsets.only(bottom: 0.5.h),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: requirement['met']
                              ? 'check_circle'
                              : 'radio_button_unchecked',
                          color: requirement['met']
                              ? AppTheme.successGreen
                              : AppTheme.textSecondary,
                          size: 16,
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            requirement['text'],
                            style: AppTheme.darkTheme.textTheme.bodySmall
                                ?.copyWith(
                              color: requirement['met']
                                  ? AppTheme.successGreen
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  int _calculatePasswordStrength(String password) {
    int strength = 0;

    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) strength++;

    return strength;
  }

  String _getStrengthText(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Weak';
    }
  }

  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return AppTheme.accentRed;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return AppTheme.successGreen;
      default:
        return AppTheme.accentRed;
    }
  }

  List<Map<String, dynamic>> _getPasswordRequirements(String password) {
    return [
      {
        'text': 'At least 8 characters',
        'met': password.length >= 8,
      },
      {
        'text': 'Contains uppercase letter',
        'met': RegExp(r'[A-Z]').hasMatch(password),
      },
      {
        'text': 'Contains number',
        'met': RegExp(r'[0-9]').hasMatch(password),
      },
      {
        'text': 'Contains special character',
        'met': RegExp(r'[!@#\$&*~]').hasMatch(password),
      },
    ];
  }
}
