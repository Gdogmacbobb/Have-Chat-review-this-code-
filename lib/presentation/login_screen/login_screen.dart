import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ynfny/utils/responsive_scale.dart';
import 'package:ynfny/widgets/primary_button.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import './widgets/login_footer_widget.dart';
import './widgets/login_form_widget.dart';
import './widgets/login_header_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  final SupabaseService _supabaseService = SupabaseService();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _canLogin = false;

  @override
  void initState() {
    super.initState();
    
    // Set status bar style for dark theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.backgroundDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    // Add listeners to validate form
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    final isValid = email.isNotEmpty &&
        password.isNotEmpty &&
        _isValidEmail(email) &&
        password.length >= 6;

    if (_canLogin != isValid) {
      setState(() {
        _canLogin = isValid;
      });
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[LOGIN] Attempting login with: $email');
      
      // Real Supabase authentication
      await _supabaseService.waitForInitialization();
      final response = await _supabaseService.signInWithPassword(email, password);
      
      if (response.session != null && response.user != null) {
        debugPrint('[LOGIN] Sign in successful for: $email');
        
        // Successful login - trigger haptic feedback
        HapticFeedback.lightImpact();
        
        // Get user role and navigate based on role
        final role = await _supabaseService.getUserRole();
        debugPrint('[LOGIN] User role: $role');
        
        if (mounted) {
          if (role == 'street_performer') {
            // Navigate to discovery feed for performers 
            Navigator.pushReplacementNamed(context, '/discovery-feed');
          } else if (role == 'new_yorker') {
            // Navigate to following feed for New Yorkers
            Navigator.pushReplacementNamed(context, '/following-feed');
          } else {
            // Default to discovery feed if role is unclear
            Navigator.pushReplacementNamed(context, '/discovery-feed');
          }
        }
        return;
      }
      
      // If we get here, login failed
      setState(() {
        _errorMessage = 'Invalid email or password. Please check your credentials and try again.';
      });
      HapticFeedback.mediumImpact();
      
    } catch (e) {
      debugPrint('[LOGIN] Authentication error: $e');
      
      setState(() {
        if (e.toString().contains('Invalid login credentials')) {
          _errorMessage = 'Invalid email or password. Please check your credentials and try again.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          _errorMessage = 'Network error. Please check your connection and try again.';
        } else {
          _errorMessage = 'Login failed. Please try again later.';
        }
      });
      HapticFeedback.mediumImpact();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _dismissError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Dismiss keyboard and error message when tapping outside
            FocusScope.of(context).unfocus();
            _dismissError();
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            child: Column(
              children: [
                // Header with logo and branding
                const LoginHeaderWidget(),

                SizedBox(height: 4.h),

                // Error message display
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(3.w),
                    margin: EdgeInsets.only(bottom: 2.h),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2.w),
                      border: Border.all(
                        color: AppTheme.accentRed.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'error_outline',
                          color: AppTheme.accentRed,
                          size: 5.w,
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTheme.darkTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: AppTheme.accentRed,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _dismissError,
                          child: CustomIconWidget(
                            iconName: 'close',
                            color: AppTheme.accentRed,
                            size: 4.w,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Login form
                LoginFormWidget(
                  emailController: _emailController,
                  passwordController: _passwordController,
                  isLoading: _isLoading,
                ),

                // Footer with additional options
                const LoginFooterWidget(),

                SizedBox(height: 2.h),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 2.h),
        child: PrimaryButton(
          label: 'Login',
          onPressed: _canLogin ? _handleLogin : null,
          isLoading: _isLoading,
        ),
      ),
    );
  }
}
