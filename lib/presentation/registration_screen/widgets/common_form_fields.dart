import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class CommonFormFields extends StatefulWidget {
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController handleController;
  final Function(String) onEmailChanged;
  final Function(String) onPasswordChanged;
  final VoidCallback onChangeHandle;
  final String? emailError;
  final String? passwordError;
  final String? confirmPasswordError;
  final bool isEmailChecking;
  final Function(String)? onUsernameChanged;
  final bool isUsernameChecking;
  final bool? isUsernameAvailable;
  final List<String> usernameSuggestions;

  const CommonFormFields({
    Key? key,
    required this.fullNameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.handleController,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onChangeHandle,
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    this.isEmailChecking = false,
    this.onUsernameChanged,
    this.isUsernameChecking = false,
    this.isUsernameAvailable,
    this.usernameSuggestions = const [],
  }) : super(key: key);

  @override
  State<CommonFormFields> createState() => _CommonFormFieldsState();
}

class _CommonFormFieldsState extends State<CommonFormFields> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full Name Field
        Text(
          'Full Name',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.fullNameController,
          textCapitalization: TextCapitalization.words,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'person',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Full name is required';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // Handle Field
        Text(
          'Handle',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isUsernameAvailable == true
                  ? AppTheme.successGreen
                  : widget.isUsernameAvailable == false
                      ? Colors.red
                      : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              // @ prefix and handle display
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  child: Row(
                    children: [
                      Text(
                        '@',
                        style:
                            AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: Text(
                          widget.handleController.text.isEmpty
                              ? 'your_unique_handle'
                              : widget.handleController.text,
                          style: AppTheme.darkTheme.textTheme.titleMedium
                              ?.copyWith(
                            color: widget.handleController.text.isEmpty
                                ? AppTheme.textSecondary.withAlpha(179)
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Availability indicator
                      if (widget.isUsernameChecking)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryOrange,
                            ),
                          ),
                        )
                      else if (widget.isUsernameAvailable == true)
                        CustomIconWidget(
                          iconName: 'check_circle',
                          color: AppTheme.successGreen,
                          size: 20,
                        )
                      else if (widget.isUsernameAvailable == false)
                        CustomIconWidget(
                          iconName: 'cancel',
                          color: Colors.red,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
              // Change button
              Container(
                margin: EdgeInsets.all(2.w),
                child: TextButton(
                  onPressed: widget.onChangeHandle,
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: AppTheme.backgroundDark,
                    padding:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Change',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.backgroundDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Username availability message and suggestions
        if (widget.isUsernameAvailable == false && widget.usernameSuggestions.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Text(
            'This username is taken. Try one of these:',
            style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: Colors.red,
            ),
          ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: widget.usernameSuggestions.map((suggestion) {
              return ActionChip(
                label: Text(
                  '@$suggestion',
                  style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: AppTheme.primaryOrange.withOpacity(0.15),
                side: BorderSide(color: AppTheme.primaryOrange, width: 1),
                onPressed: () {
                  widget.handleController.text = suggestion;
                  if (widget.onUsernameChanged != null) {
                    widget.onUsernameChanged!(suggestion);
                  }
                },
              );
            }).toList(),
          ),
        ] else if (widget.isUsernameAvailable == true) ...[
          SizedBox(height: 1.h),
          Text(
            '✓ Username is available',
            style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.successGreen,
            ),
          ),
        ],
        
        SizedBox(height: 3.h),

        // Email Field
        Text(
          'Email Address',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: widget.onEmailChanged,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your email address',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'email',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
            suffixIcon: widget.isEmailChecking
                ? Padding(
                    padding: EdgeInsets.all(3.w),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryOrange,
                        ),
                      ),
                    ),
                  )
                : null,
            errorText: widget.emailError,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // Password Field
        Text(
          'Password',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.passwordController,
          obscureText: !_isPasswordVisible,
          onChanged: widget.onPasswordChanged,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Create a strong password',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'lock',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
              icon: CustomIconWidget(
                iconName: _isPasswordVisible ? 'visibility_off' : 'visibility',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
            errorText: widget.passwordError,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // Confirm Password Field
        Text(
          'Confirm Password',
          style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Confirm your password',
            hintStyle: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(153),
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'lock',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
              icon: CustomIconWidget(
                iconName:
                    _isConfirmPasswordVisible ? 'visibility_off' : 'visibility',
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
            errorText: widget.confirmPasswordError,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != widget.passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }
}
