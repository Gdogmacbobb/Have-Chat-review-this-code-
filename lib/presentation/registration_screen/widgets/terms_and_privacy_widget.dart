import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class TermsAndPrivacyWidget extends StatefulWidget {
  final bool isTermsAccepted;
  final Function(bool) onTermsChanged;

  const TermsAndPrivacyWidget({
    Key? key,
    required this.isTermsAccepted,
    required this.onTermsChanged,
  }) : super(key: key);

  @override
  State<TermsAndPrivacyWidget> createState() => _TermsAndPrivacyWidgetState();
}

class _TermsAndPrivacyWidgetState extends State<TermsAndPrivacyWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CustomIconWidget(
                iconName: 'security',
                color: AppTheme.primaryOrange,
                size: 24,
              ),
              SizedBox(width: 12.0),
              Text(
                'Legal Agreement',
                style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.0),

          // Terms and Privacy Links
          _buildLegalLink(
            title: 'Terms of Service',
            description:
                'User responsibilities, content guidelines, and platform rules',
            icon: 'description',
            onTap: () => _showTermsDialog(context),
          ),
          SizedBox(height: 16.0),

          _buildLegalLink(
            title: 'Privacy Policy',
            description:
                'How we collect, use, and protect your personal information',
            icon: 'privacy_tip',
            onTap: () => _showPrivacyDialog(context),
          ),
          SizedBox(height: 24.0),

          // Acceptance Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: widget.isTermsAccepted,
                onChanged: (value) {
                  widget.onTermsChanged(value ?? false);
                },
                activeColor: AppTheme.primaryOrange,
                checkColor: AppTheme.backgroundDark,
                side: BorderSide(
                  color: widget.isTermsAccepted
                      ? AppTheme.primaryOrange
                      : AppTheme.borderSubtle,
                  width: 2,
                ),
              ),
              SizedBox(width: 8.0),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: RichText(
                    text: TextSpan(
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(
                          text: 'I agree to the ',
                        ),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(
                          text: ' and ',
                        ),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '. I understand that YNFNY is a platform for authentic NYC street performers and that all content is subject to verification and moderation.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (!widget.isTermsAccepted)
            Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentRed.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'info',
                      color: AppTheme.accentRed,
                      size: 16,
                    ),
                    SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        'You must accept the terms and privacy policy to continue',
                        style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.accentRed,
                        ),
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

  Widget _buildLegalLink({
    required String title,
    required String description,
    required String icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AppTheme.darkTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CustomIconWidget(
              iconName: icon,
              color: AppTheme.primaryOrange,
              size: 20,
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.0),
                  Text(
                    description,
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            CustomIconWidget(
              iconName: 'arrow_forward_ios',
              color: AppTheme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkTheme.colorScheme.surface,
        title: Text(
          'Terms of Service',
          style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
            color: AppTheme.primaryOrange,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            '''Welcome to YNFNY - Your NYC street performance discovery platform.

By creating an account, you agree to:

1. AUTHENTIC CONTENT
• Only post original performance content
• Verify your identity as a legitimate street performer
• Respect intellectual property rights

2. COMMUNITY GUIDELINES
• Maintain respectful interactions
• No harassment, hate speech, or inappropriate content
• Report violations promptly

3. LOCATION REQUIREMENTS
• Performances must be within NYC five boroughs
• Location verification is mandatory
• False location claims result in account suspension

4. PAYMENT TERMS
• 5% platform fee on all donations received
• Non-refundable payment policy
• Stripe handles all payment processing

5. ACCOUNT RESPONSIBILITIES
• Keep login credentials secure
• Update profile information accurately
• Comply with all platform policies

Violation of these terms may result in account suspension or termination.''',
            style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: AppTheme.primaryOrange),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkTheme.colorScheme.surface,
        title: Text(
          'Privacy Policy',
          style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
            color: AppTheme.primaryOrange,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            '''YNFNY Privacy Policy - Effective Date: July 28, 2025

INFORMATION WE COLLECT:
• Account information (name, email, performance type)
• Location data for NYC verification
• Social media handles for performer verification
• Payment information (processed by Stripe)
• Performance videos and user interactions

HOW WE USE YOUR DATA:
• Verify performer authenticity
• Enable location-based content discovery
• Process donations and payments
• Improve platform functionality
• Send important account notifications

DATA SHARING:
• We do not sell personal information
• Payment data is handled by Stripe
• Location data is used only for NYC verification
• Social media verification is optional

YOUR RIGHTS:
• Access your personal data
• Request data deletion
• Opt out of non-essential communications
• Update account information anytime

DATA SECURITY:
• Encrypted data transmission
• Secure server infrastructure
• Regular security audits
• Limited employee access

CONTACT US:
For privacy questions, email: privacy@ynfny.com

This policy may be updated periodically. Users will be notified of significant changes.''',
            style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: AppTheme.primaryOrange),
            ),
          ),
        ],
      ),
    );
  }
}
