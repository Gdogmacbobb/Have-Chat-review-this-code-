import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ynfny/utils/responsive_scale.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../core/constants/user_roles.dart';
import '../../config/supabase_config.dart';
import '../../widgets/primary_button.dart';
import './widgets/account_type_header.dart';
import './widgets/common_form_fields.dart';
import './widgets/location_verification_widget.dart';
import './widgets/new_yorker_specific_fields.dart';
import './widgets/password_strength_indicator.dart';
import './widgets/performer_specific_fields.dart';
import './widgets/terms_and_privacy_widget.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Common form controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _handleController = TextEditingController();

  // Performer-specific controllers
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _xController = TextEditingController();
  final _snapchatController = TextEditingController();
  final _facebookController = TextEditingController();
  final _soundcloudController = TextEditingController();
  final _spotifyController = TextEditingController();

  // Form state
  String _accountType = UserRoles.performerLabel; // Default from previous screen
  List<String> _selectedPerformanceTypes = []; // Simplified: just category names
  DateTime? _selectedBirthDate;
  String? _selectedBorough;
  bool _isLocationVerified = false;
  bool _isTermsAccepted = false;
  bool _isLoading = false;
  String? _idempotencyKey;

  // Validation state
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _isEmailChecking = false;
  Timer? _emailDebounceTimer;
  
  // Username availability state
  bool _isUsernameChecking = false;
  bool? _isUsernameAvailable; // null = not checked yet, true = available, false = taken
  List<String> _usernameSuggestions = [];
  Timer? _usernameDebounceTimer;

  // Mock user data for testing
  final List<Map<String, dynamic>> existingUsers = [
    {
      "email": "performer@test.com",
      "type": "performer",
      "name": "Test Performer"
    },
    {
      "email": "newyorker@test.com",
      "type": "newyorker",
      "name": "Test New Yorker"
    },
    {"email": "admin@ynfny.com", "type": "admin", "name": "YNFNY Admin"}
  ];

  @override
  void initState() {
    super.initState();
    // Get account type from previous screen arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['accountType'] != null) {
        setState(() {
          _accountType = args['accountType'];
        });
      }
      
      // Auto-check username availability if handle already exists
      if (_handleController.text.isNotEmpty) {
        _onUsernameChanged(_handleController.text);
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _handleController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _youtubeController.dispose();
    _xController.dispose();
    _snapchatController.dispose();
    _facebookController.dispose();
    _soundcloudController.dispose();
    _spotifyController.dispose();
    _scrollController.dispose();
    _emailDebounceTimer?.cancel();
    _usernameDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.textPrimary,
            size: 24,
          ),
        ),
        title: Text(
          'Create Account',
          style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Account Type Header
                  AccountTypeHeader(accountType: _accountType),
                  SizedBox(height: 4.h),

                  // Welcome Message
                  Text(
                    'Join the NYC Street Performance Community',
                    style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    _accountType == UserRoles.performerLabel
                        ? 'Showcase your talent and connect with NYC audiences'
                        : 'Discover and support amazing street performers in your city',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4.h),

                  // Common Form Fields
                  CommonFormFields(
                    fullNameController: _fullNameController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    handleController: _handleController,
                    onEmailChanged: _onEmailChanged,
                    onPasswordChanged: _onPasswordChanged,
                    onChangeHandle: _navigateToHandleCreation,
                    emailError: _emailError,
                    passwordError: _passwordError,
                    confirmPasswordError: _confirmPasswordError,
                    isEmailChecking: _isEmailChecking,
                    onUsernameChanged: _onUsernameChanged,
                    isUsernameChecking: _isUsernameChecking,
                    isUsernameAvailable: _isUsernameAvailable,
                    usernameSuggestions: _usernameSuggestions,
                  ),
                  SizedBox(height: 3.h),

                  // Password Strength Indicator
                  if (_passwordController.text.isNotEmpty)
                    Column(
                      children: [
                        PasswordStrengthIndicator(
                            password: _passwordController.text),
                        SizedBox(height: 4.h),
                      ],
                    ),

                  // Account Type Specific Fields
                  if (_accountType == UserRoles.performerLabel) ...[
                    PerformerSpecificFields(
                      selectedPerformanceTypes: _selectedPerformanceTypes,
                      onCategoryToggled: (category, isSelected) {
                        setState(() {
                          if (isSelected) {
                            if (!_selectedPerformanceTypes.contains(category)) {
                              _selectedPerformanceTypes.add(category);
                            }
                          } else {
                            _selectedPerformanceTypes.remove(category);
                          }
                        });
                      },
                      instagramController: _instagramController,
                      tiktokController: _tiktokController,
                      youtubeController: _youtubeController,
                      xController: _xController,
                      snapchatController: _snapchatController,
                      facebookController: _facebookController,
                      soundcloudController: _soundcloudController,
                      spotifyController: _spotifyController,
                      selectedBirthDate: _selectedBirthDate,
                      onBirthDateChanged: (date) {
                        setState(() {
                          _selectedBirthDate = date;
                        });
                      },
                    ),
                    SizedBox(height: 4.h),

                    // Location Verification for Performers
                    LocationVerificationWidget(
                      isLocationVerified: _isLocationVerified,
                      onVerifyLocation: () {
                        setState(() {
                          _isLocationVerified = true;
                        });
                      },
                      selectedBorough: _selectedBorough,
                      onBoroughChanged: (borough) {
                        setState(() {
                          _selectedBorough = borough;
                          if (borough != null) {
                            _isLocationVerified = true;
                          }
                        });
                      },
                    ),
                  ] else ...[
                    NewYorkerSpecificFields(
                      selectedBirthDate: _selectedBirthDate,
                      onBirthDateChanged: (date) {
                        setState(() {
                          _selectedBirthDate = date;
                        });
                      },
                      selectedBorough: _selectedBorough,
                      onBoroughChanged: (borough) {
                        setState(() {
                          _selectedBorough = borough;
                        });
                      },
                    ),
                  ],
                  SizedBox(height: 4.h),

                  // Terms and Privacy
                  TermsAndPrivacyWidget(
                    isTermsAccepted: _isTermsAccepted,
                    onTermsChanged: (accepted) {
                      setState(() {
                        _isTermsAccepted = accepted;
                      });
                    },
                  ),
                  SizedBox(height: 2.h),

                  // Login Link
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login-screen');
                      },
                      child: RichText(
                        text: TextSpan(
                          style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 2.h),
        child: PrimaryButton(
          label: 'Create Account',
          onPressed: _canSubmitForm() ? _handleRegistration : null,
          isLoading: _isLoading,
        ),
      ),
    );
  }

  Future<void> _navigateToHandleCreation() async {
    final selectedHandle = await Navigator.pushNamed(
      context,
      '/handle-creation-screen',
    ) as String?;

    if (selectedHandle != null) {
      setState(() {
        _handleController.text = selectedHandle;
      });
      // Trigger username availability check
      _onUsernameChanged(selectedHandle);
    }
  }

  void _onEmailChanged(String email) {
    _emailDebounceTimer?.cancel();
    _emailDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkEmailAvailability(email);
    });
  }

  void _onPasswordChanged(String password) {
    setState(() {
      _passwordError = null;
      if (_confirmPasswordController.text.isNotEmpty) {
        _validateConfirmPassword();
      }
    });
  }

  Future<void> _checkEmailAvailability(String email) async {
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _emailError = null;
        _isEmailChecking = false;
      });
      return;
    }

    setState(() {
      _isEmailChecking = true;
      _emailError = null;
    });

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Check against mock existing users
      final existingUser = existingUsers.any((user) =>
          (user['email'] as String).toLowerCase() == email.toLowerCase());

      if (mounted) {
        setState(() {
          _emailError =
              existingUser ? 'This email is already registered' : null;
          _isEmailChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = 'Unable to verify email availability';
          _isEmailChecking = false;
        });
      }
    }
  }

  void _onUsernameChanged(String username) {
    _usernameDebounceTimer?.cancel();
    _usernameDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(username);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    // Remove @ symbol if present
    final cleanUsername = username.replaceAll('@', '').trim();
    
    if (cleanUsername.isEmpty || cleanUsername.length < 3) {
      setState(() {
        _isUsernameAvailable = null;
        _isUsernameChecking = false;
        _usernameSuggestions = [];
      });
      return;
    }

    setState(() {
      _isUsernameChecking = true;
      _isUsernameAvailable = null;
      _usernameSuggestions = [];
    });

    try {
      final supabaseService = SupabaseService();
      
      await supabaseService.waitForInitialization();
      
      if (supabaseService.client == null) {
        throw Exception('Supabase client not initialized');
      }
      
      final response = await supabaseService.client!
          .rpc('check_username_availability', params: {'p_username': cleanUsername});
      
      final isAvailable = response as bool;

      if (mounted) {
        setState(() {
          _isUsernameAvailable = isAvailable;
          _isUsernameChecking = false;
        });

        if (!isAvailable) {
          _getUsernameSuggestions(cleanUsername);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUsernameAvailable = null;
          _isUsernameChecking = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to verify username availability. Please try again.'),
            backgroundColor: AppTheme.accentRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _getUsernameSuggestions(String baseUsername) async {
    try {
      final supabaseService = SupabaseService();
      
      await supabaseService.waitForInitialization();
      
      if (supabaseService.client == null) {
        return;
      }
      
      final response = await supabaseService.client!.rpc(
        'get_username_suggestions',
        params: {
          'p_username': baseUsername,
          'p_borough': _selectedBorough,
          'p_performance_types': _selectedPerformanceTypes.isEmpty 
              ? null 
              : _selectedPerformanceTypes,
        },
      );

      if (mounted && response != null) {
        final suggestions = (response as List).cast<String>();
        setState(() {
          _usernameSuggestions = suggestions;
        });
      }
    } catch (e) {
      // Silently fail - suggestions are optional
    }
  }

  void _validateConfirmPassword() {
    if (_confirmPasswordController.text != _passwordController.text) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
    } else {
      setState(() {
        _confirmPasswordError = null;
      });
    }
  }

  bool _canSubmitForm() {
    if (_isLoading) {
      return false;
    }
    if (_isEmailChecking) {
      return false;
    }
    if (_isUsernameChecking) {
      return false;
    }

    if (_fullNameController.text.trim().length < 2) {
      return false;
    }
    if (_emailError != null || _emailController.text.isEmpty) {
      return false;
    }
    if (_passwordController.text.length < 8) {
      return false;
    }
    if (_confirmPasswordController.text != _passwordController.text) {
      return false;
    }
    if (_handleController.text.isEmpty) {
      return false;
    }
    if (_isUsernameAvailable != true) {
      return false;
    }
    if (!_isTermsAccepted) {
      return false;
    }

    if (_selectedBirthDate == null) {
      return false;
    }
    
    final now = DateTime.now();
    int age = now.year - _selectedBirthDate!.year;
    if (now.month < _selectedBirthDate!.month ||
        (now.month == _selectedBirthDate!.month &&
            now.day < _selectedBirthDate!.day)) {
      age--;
    }
    if (age < 18) {
      return false;
    }
    
    if (_accountType == UserRoles.performerLabel) {
      if (_selectedPerformanceTypes.isEmpty) {
        return false;
      }
      if (!_isLocationVerified && _selectedBorough == null) {
        return false;
      }
      if (_instagramController.text.trim().isEmpty &&
          _tiktokController.text.trim().isEmpty &&
          _youtubeController.text.trim().isEmpty &&
          _xController.text.trim().isEmpty &&
          _snapchatController.text.trim().isEmpty &&
          _facebookController.text.trim().isEmpty &&
          _soundcloudController.text.trim().isEmpty &&
          _spotifyController.text.trim().isEmpty) {
        return false;
      }
    } else {
      if (_selectedBorough == null) {
        return false;
      }
    }

    return true;
  }

  // Map borough display values to codes expected by Edge Function
  String _getBoroughCode(String? borough) {
    if (borough == null) return 'VISITOR';
    
    final boroughMap = {
      'manhattan': 'MN',
      'brooklyn': 'BK',
      'queens': 'QN',
      'bronx': 'BX',
      'the bronx': 'BX',
      'staten_island': 'SI',
      'staten island': 'SI',
      'visitor': 'VISITOR',
    };
    
    return boroughMap[borough.toLowerCase()] ?? 'VISITOR';
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields correctly'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final accountType = UserRoles.getCanonicalRole(_accountType);
      
      _idempotencyKey ??= '${DateTime.now().millisecondsSinceEpoch}_${_emailController.text.hashCode}';
      
      final boroughCode = _getBoroughCode(_selectedBorough);
      
      // Prepare payload for Edge Function
      final payload = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'username': _handleController.text.trim(),
        'birthday': _selectedBirthDate?.toIso8601String().split('T').first,
        'borough': boroughCode,
        'tos_accepted': true,
        'idempotency_key': _idempotencyKey!,
        'device_fingerprint': 'flutter_web_${DateTime.now().millisecondsSinceEpoch}',
        'full_name': _fullNameController.text.trim(),
        'role': accountType,
      };
      
      // Add role-specific fields
      if (accountType == 'street_performer') {
        payload['performance_types'] = _selectedPerformanceTypes;
        payload['socials_instagram'] = _instagramController.text.trim().isNotEmpty 
            ? _instagramController.text.trim() 
            : null;
        payload['socials_tiktok'] = _tiktokController.text.trim().isNotEmpty 
            ? _tiktokController.text.trim() 
            : null;
        payload['socials_youtube'] = _youtubeController.text.trim().isNotEmpty 
            ? _youtubeController.text.trim() 
            : null;
        payload['socials_x'] = _xController.text.trim().isNotEmpty 
            ? _xController.text.trim() 
            : null;
        payload['socials_snapchat'] = _snapchatController.text.trim().isNotEmpty 
            ? _snapchatController.text.trim() 
            : null;
        payload['socials_facebook'] = _facebookController.text.trim().isNotEmpty 
            ? _facebookController.text.trim() 
            : null;
        payload['socials_soundcloud'] = _soundcloudController.text.trim().isNotEmpty 
            ? _soundcloudController.text.trim() 
            : null;
        payload['socials_spotify'] = _spotifyController.text.trim().isNotEmpty 
            ? _spotifyController.text.trim() 
            : null;
      }
      
      // Call Edge Function using Supabase client
      final supabaseService = SupabaseService();
      final response = await supabaseService.client.functions
          .invoke('finalize-registration', body: payload)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Registration timed out. Please try again.');
        },
      );
      
      final responseData = response.data as Map<String, dynamic>;
      
      if (response.status != 200 || responseData['success'] != true) {
        final errorCode = responseData['code'];
        final errorMessage = responseData['message'] ?? 'Registration failed';
        final errors = responseData['errors'] as List?;
        
        // Handle specific error codes
        if (errorCode == 'VALIDATION_FAILED') {
          if (errors != null && errors.isNotEmpty) {
            final firstError = errors[0];
            throw Exception(firstError['message'] ?? errorMessage);
          }
          throw Exception(errorMessage);
        } else if (errorCode == 'USERNAME_EXISTS') {
          throw Exception('Username "@${_handleController.text.trim()}" is already taken. Please choose a different handle.');
        } else if (errorCode == 'EMAIL_EXISTS') {
          throw Exception('This email is already registered. Please use a different email or sign in.');
        } else if (errorCode == 'INVALID_AGE') {
          throw Exception('You must be at least 18 years old to register.');
        } else if (errorCode == 'INVALID_BOROUGH') {
          throw Exception('Please select a valid NYC borough.');
        } else if (errorCode == 'MISSING_PERFORMANCE_TYPES') {
          throw Exception('Please select at least one performance type.');
        } else if (errorCode == 'MISSING_SOCIAL_MEDIA') {
          throw Exception('Please provide at least one social media handle.');
        } else {
          throw Exception(errorMessage);
        }
      }
      
      final userId = responseData['user_id'];
      final session = responseData['session'];
      final message = responseData['message'] ?? 'Account created successfully';
      
      if (session == null || session['access_token'] == null || session['refresh_token'] == null) {
        throw Exception('Invalid session data received from server');
      }
      
      await supabaseService.setSession(
        accessToken: session['access_token'],
        refreshToken: session['refresh_token'],
      );
      
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
                Expanded(
                  child: Text(
                    message,
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.darkTheme.colorScheme.surface,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pushReplacementNamed(context, '/discovery-feed');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        final errorStr = e.toString();
        
        if (errorStr.contains('already registered')) {
          errorMessage = 'Email already registered. Please use a different email.';
        } else if (errorStr.contains('Exception:')) {
          errorMessage = errorStr.replaceFirst('Exception:', '').trim();
        } else if (errorStr.contains('AuthException')) {
          errorMessage = 'Authentication error. Please check your email and password.';
        } else {
          errorMessage = 'Registration failed. Please try again.';
        }
        
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
                    errorMessage,
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.darkTheme.colorScheme.surface,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
