import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:ynfny/utils/responsive_scale.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import './widgets/animated_logo_widget.dart';
import './widgets/gradient_background_widget.dart';
import './widgets/loading_indicator_widget.dart';
import './widgets/retry_connection_widget.dart';

// DEV MODE: Set to true to skip auth/geo checks and go straight to camera screen
const bool DEV_SKIP_GEO_AUTH = false;

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  bool _showRetry = false;
  String _loadingText = 'Initializing YNFNY...';
  Timer? _timeoutTimer;
  Timer? _loadingTextTimer;

  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
    _startInitialization();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _loadingTextTimer?.cancel();
    super.dispose();
  }

  void _setSystemUIOverlay() {
    // Hide status bar on Android, use dark theme on iOS
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.backgroundDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _startInitialization() {
    _startLoadingTextAnimation();
    _startTimeoutTimer();
    _performInitializationTasks();
  }

  void _startLoadingTextAnimation() {
    final loadingMessages = [
      'Initializing YNFNY...',
      'Connecting to Supabase...',
      'Checking authentication...',
      'Loading user preferences...',
      'Verifying NYC location services...',
      'Preparing video cache...',
      'Almost ready...',
    ];

    int messageIndex = 0;
    _loadingTextTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && _isLoading) {
        setState(() {
          _loadingText = loadingMessages[messageIndex % loadingMessages.length];
          messageIndex++;
        });
      }
    });
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _showRetry = true;
        });
        _loadingTextTimer?.cancel();
      }
    });
  }

  Future<void> _performInitializationTasks() async {
    try {
      // Initialize Supabase and check authentication
      await _supabaseService.waitForInitialization();

      // Simulate other background tasks
      await Future.wait([
        _checkAuthenticationStatus(),
        _loadUserPreferences(),
        _verifyGeofencingCapabilities(),
        _prepareCachedVideoData(),
      ]);

      // Ensure minimum splash display time
      await Future.delayed(const Duration(milliseconds: 2500));

      if (mounted) {
        _navigateToNextScreen();
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showRetry = true;
        });
      }
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    // Check real authentication status with Supabase
    await Future.delayed(const Duration(milliseconds: 800));
    // Authentication check is handled by SupabaseService
  }

  Future<void> _loadUserPreferences() async {
    // Load user preferences
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _verifyGeofencingCapabilities() async {
    // Verify NYC geofencing capabilities
    await Future.delayed(const Duration(milliseconds: 700));
  }

  Future<void> _prepareCachedVideoData() async {
    // Prepare video cache
    await Future.delayed(const Duration(milliseconds: 900));
  }

  void _navigateToNextScreen() {
    _timeoutTimer?.cancel();
    _loadingTextTimer?.cancel();

    // Restore system UI before navigation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Navigation logic based on real authentication status
    String nextRoute;

    // DEV MODE: Skip auth/geo and go straight to camera for testing (check FIRST)
    if (DEV_SKIP_GEO_AUTH) {
      print('[NAV_STATE] DEV_SKIP_GEO_AUTH=true - bypassing auth/geo checks');
      nextRoute = '/video-recording';
    } else if (_supabaseService.isAuthenticated) {
      print('[NAV_STATE] User authenticated - routing to discovery feed');
      // Authenticated users go to Discovery Feed
      nextRoute = '/discovery-feed';
    } else {
      print('[NAV_STATE] No session - routing to login');
      // Non-authenticated users go directly to login screen
      nextRoute = '/login-screen';
    }

    // Use addPostFrameCallback to ensure navigation happens after widget build completes
    // This prevents route stack corruption
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('[NAV_STATE] Post-frame navigation to: $nextRoute');
        Navigator.pushReplacementNamed(context, nextRoute);
      }
    });
  }

  void _retryInitialization() {
    setState(() {
      _isLoading = true;
      _showRetry = false;
    });
    _startInitialization();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: GradientBackgroundWidget(
          child: _showRetry ? _buildRetryView() : _buildSplashView(),
        ),
      ),
    );
  }

  Widget _buildSplashView() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Center(
            child: AnimatedLogoWidget(
              onAnimationComplete: () {
                // Logo animation completed
              },
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingIndicatorWidget(
                  loadingText: _loadingText.replaceAll('...', ''),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRetryView() {
    return Center(
      child: RetryConnectionWidget(
        onRetry: _retryInitialization,
        message: 'Unable to connect to YNFNY servers',
      ),
    );
  }
}
