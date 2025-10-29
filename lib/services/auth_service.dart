import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './supabase_service.dart';

class AuthService {
  final SupabaseService _supabaseService = SupabaseService();

  // Sign up new user
  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String role, // 'street_performer' or 'new_yorker'
    String? performanceType,
    String? frequentSpots,
    Map<String, String>? socialMediaLinks,
    String? verificationPhotoUrl,
  }) async {
    try {
      final client = await _supabaseService.client;

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'full_name': fullName,
          'role': role,
          if (performanceType != null) 'performance_type': performanceType,
          if (frequentSpots != null)
            'frequent_performance_spots': frequentSpots,
          if (socialMediaLinks != null) 'social_media_links': socialMediaLinks,
          if (verificationPhotoUrl != null)
            'verification_photo_url': verificationPhotoUrl,
        },
      );

      return response;
    } catch (error) {
      debugPrint('Sign up error: $error');
      rethrow;
    }
  }

  // Sign in existing user
  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final client = await _supabaseService.client;

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response;
    } catch (error) {
      debugPrint('Sign in error: $error');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final client = await _supabaseService.client;
      await client.auth.signOut();
    } catch (error) {
      debugPrint('Sign out error: $error');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      final client = await _supabaseService.client;
      await client.auth.resetPasswordForEmail(email);
    } catch (error) {
      debugPrint('Reset password error: $error');
      rethrow;
    }
  }

  // Update profile
  Future<void> updateProfile({
    String? username,
    String? fullName,
    String? bio,
    String? profileImageUrl,
    String? performanceType,
    String? frequentSpots,
    Map<String, String>? socialMediaLinks,
  }) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;

      if (userId == null) throw Exception('User not authenticated');

      final updateData = <String, dynamic>{};

      if (username != null) updateData['username'] = username;
      if (fullName != null) updateData['full_name'] = fullName;
      if (bio != null) updateData['bio'] = bio;
      if (profileImageUrl != null)
        updateData['profile_image_url'] = profileImageUrl;
      if (performanceType != null)
        updateData['performance_type'] = performanceType;
      if (frequentSpots != null)
        updateData['frequent_performance_spots'] = frequentSpots;
      if (socialMediaLinks != null)
        updateData['social_media_links'] = socialMediaLinks;

      if (updateData.isNotEmpty) {
        updateData['updated_at'] = DateTime.now().toIso8601String();

        await client.from('user_profiles').update(updateData).eq('id', userId);
      }
    } catch (error) {
      debugPrint('Update profile error: $error');
      rethrow;
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;

      if (userId == null) return null;

      final response =
          await client.from('user_profiles').select().eq('id', userId).single();

      return response;
    } catch (error) {
      debugPrint('Get user profile error: $error');
      return null;
    }
  }

  // Check username availability
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final client = await _supabaseService.client;

      final response = await client
          .from('user_profiles')
          .select('id')
          .eq('username', username)
          .limit(1);

      return response.isEmpty;
    } catch (error) {
      debugPrint('Username check error: $error');
      return false;
    }
  }

  // OAuth sign in (for future implementation)
  Future<bool> signInWithGoogle() async {
    try {
      final client = await _supabaseService.client;
      return await client.auth.signInWithOAuth(OAuthProvider.google);
    } catch (error) {
      debugPrint('Google sign in error: $error');
      return false;
    }
  }
}
