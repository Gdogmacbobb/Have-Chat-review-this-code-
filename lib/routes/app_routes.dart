import 'package:flutter/material.dart';

import '../presentation/account_type_selection/account_type_selection.dart';
import '../presentation/discovery_feed/discovery_feed.dart';
import '../presentation/donation_flow/donation_flow.dart';
import '../presentation/following_feed/following_feed.dart';
import '../presentation/handle_creation_screen/handle_creation_screen.dart';
import '../presentation/login_screen/login_screen.dart';
import '../presentation/onboarding_flow/onboarding_flow.dart';
import '../presentation/performer_profile/performer_profile.dart';
import '../presentation/performer_profile/performer_profile_video_player.dart';
import '../presentation/registration_screen/registration_screen.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/user_profile/user_profile.dart';
import '../presentation/video_recording/video_recording_screen.dart';
import '../presentation/video_upload/video_upload_screen.dart';
import '../presentation/ynf_wallet/ynf_wallet_screen.dart';

class AppRoutes {
  // TODO: Add your routes here
  static const String initial = '/splash-screen';
  static const String accountTypeSelection = '/account-type-selection';
  static const String loginScreen = '/login-screen';
  static const String splashScreen = '/splash-screen';
  static const String videoRecording = '/video-recording';
  static const String followingFeed = '/following-feed';
  static const String videoUpload = '/video-upload';
  static const String discoveryFeed = '/discovery-feed';
  static const String discovery = '/discovery'; // Alias for discovery-feed
  static const String registrationScreen = '/registration-screen';
  static const String userProfile = '/user-profile';
  static const String donationFlow = '/donation-flow';
  static const String performerProfile = '/performer-profile';
  static const String performerProfileVideoPlayer = '/performer-profile-video-player';
  static const String onboardingFlow = '/onboarding-flow';
  static const String videoPlayer = '/video-player';
  static const String handleCreationScreen = '/handle-creation-screen';
  static const String ynfWallet = '/ynf-wallet';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    accountTypeSelection: (context) => const AccountTypeSelection(),
    loginScreen: (context) => const LoginScreen(),
    splashScreen: (context) => const SplashScreen(),
    videoRecording: (context) => const VideoRecordingScreen(),
    followingFeed: (context) => const FollowingFeed(),
    videoUpload: (context) => const VideoUploadScreen(),
    discoveryFeed: (context) => const DiscoveryFeed(),
    discovery: (context) => const DiscoveryFeed(), // Alias for discoveryFeed
    registrationScreen: (context) => const RegistrationScreen(),
    userProfile: (context) => const UserProfile(userId: 'b6557ae4-ec19-4483-a2bd-844ff1c0dd9e'),
    donationFlow: (context) => const DonationFlow(),
    performerProfile: (context) => const PerformerProfile(),
    performerProfileVideoPlayer: (context) => const PerformerProfileVideoPlayer(),
    onboardingFlow: (context) => const OnboardingFlow(),
    videoPlayer: (context) => const VideoPlayerScreen(),
    handleCreationScreen: (context) => const HandleCreationScreen(),
    ynfWallet: (context) => const YNFWalletScreen(),
    // TODO: Add your other routes here
  };

  // Safe navigation helper to prevent crashes
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    try {
      if (routes.containsKey(routeName)) {
        return await Navigator.pushNamed<T>(
          context,
          routeName,
          arguments: arguments,
        );
      } else {
        debugPrint('Route not found: $routeName');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feature coming soon!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return null;
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      return null;
    }
  }

  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    TO? result,
  }) async {
    try {
      if (routes.containsKey(routeName)) {
        return await Navigator.pushReplacementNamed<T, TO>(
          context,
          routeName,
          arguments: arguments,
          result: result,
        );
      } else {
        debugPrint('Route not found: $routeName');
        return null;
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      return null;
    }
  }
}

// Placeholder Video Player Screen until real implementation
class VideoPlayerScreen extends StatelessWidget {
  const VideoPlayerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // SAFETY: Use safe null check instead of force unwrap
    final videoData =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          videoData['title'] ?? 'Video Player',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 100,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'Video Player Coming Soon',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 10),
            Text(
              videoData['title'] ?? 'No title',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
