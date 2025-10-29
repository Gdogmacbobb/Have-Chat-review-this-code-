import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './supabase_service.dart';

class ProfileService {
  final SupabaseService _supabaseService = SupabaseService();

  /// Get user profile data by user ID from Supabase user_profiles table
  /// Returns consistent data structure for both PerformerProfile and UserProfile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final client = _supabaseService.client;
      
      // First, try to query with all fields including optional ones
      Map<String, dynamic>? response;
      try {
        response = await client
            .from('user_profiles')
            .select('''
              id,
              full_name,
              username,
              role,
              bio,
              profile_image_url,
              total_donations_received,
              is_verified,
              created_at,
              socials_instagram,
              socials_tiktok,
              socials_youtube,
              socials_x,
              socials_snapchat,
              socials_facebook,
              socials_soundcloud,
              socials_spotify,
              frequent_location,
              performance_schedule,
              performance_types
            ''')
            .eq('id', userId)
            .maybeSingle();

        if (response == null) {
          debugPrint('ProfileService: No profile found for user $userId');
          return null;
        }

        debugPrint('ProfileService: Retrieved profile with all fields for user $userId');
      } on PostgrestException catch (e) {
        // If columns don't exist (code 42703), fall back to basic fields
        if (e.code == '42703') {
          debugPrint('ProfileService: Optional columns not available, using basic fields only');
          response = await client
              .from('user_profiles')
              .select('''
                id,
                full_name,
                username,
                role,
                bio,
                profile_image_url,
                total_donations_received,
                is_verified,
                created_at,
                socials_instagram,
                socials_tiktok,
                socials_youtube,
                socials_x,
                socials_snapchat,
                socials_facebook,
                socials_soundcloud,
                socials_spotify
              ''')
              .eq('id', userId)
              .maybeSingle();

          if (response == null) {
            debugPrint('ProfileService: No profile found for user $userId');
            return null;
          }

          debugPrint('ProfileService: Retrieved profile with basic fields for user $userId');
        } else {
          rethrow;
        }
      }

      // Fetch real-time stats from relationships
      final supportersCount = await getSupportersCount(userId);
      final supportingCount = await getSupportingCount(userId);
      final videosCount = await getVideosCount(userId);

      return _normalizeProfileData(response, supportersCount, supportingCount, videosCount);
    } catch (e) {
      debugPrint('ProfileService Error: Failed to fetch profile for user $userId - $e');
      return null;
    }
  }

  /// Normalize Supabase field names to expected UI field names
  /// This ensures both PerformerProfile and UserProfile get consistent data
  Map<String, dynamic> _normalizeProfileData(
    Map<String, dynamic> rawData,
    int supportersCount,
    int supportingCount,
    int videosCount,
  ) {
    final result = {
      // Core identifiers
      'id': rawData['id'],
      'userId': rawData['id'], // Alias for compatibility
      
      // Profile information
      'name': rawData['full_name'] ?? 'Unknown Performer',
      'full_name': rawData['full_name'], // Keep original for UserProfile
      'username': rawData['username'] ?? '',
      'role': rawData['role'] ?? '',
      'accountType': rawData['role'] ?? '', // Alias for UserProfile compatibility
      'bio': rawData['bio'] ?? '',
      
      // Profile image
      'avatar': rawData['profile_image_url'] ?? getDefaultProfileImage(),
      'profile_image_url': rawData['profile_image_url'], // Keep original
      
      // Stats (using real Supabase counts)
      'followersCount': supportersCount,
      'followers_count': supportersCount, // Keep original format
      'supportingCount': supportingCount, // NEW: Count of users this user is following
      'supporting_count': supportingCount, // Keep original format
      'videoCount': videosCount,
      'video_count': videosCount, // Keep original format
      'totalDonations': rawData['total_donations_received'] ?? 0,
      'supporter_count': rawData['total_donations_received'] ?? 0, // Keep original format
      
      // Verification status (using database field)
      'verificationStatus': rawData['is_verified'] == true ? 'verified' : 'none',
      'isVerified': rawData['is_verified'] ?? false,
      
      // Additional computed fields for compatibility
      'email': rawData['email'] ?? '',
      'joinDate': rawData['created_at'] ?? DateTime.now().toIso8601String(),
      
      // Social media handles
      'socials_instagram': rawData['socials_instagram'] ?? '',
      'socials_tiktok': rawData['socials_tiktok'] ?? '',
      'socials_youtube': rawData['socials_youtube'] ?? '',
      'socials_x': rawData['socials_x'] ?? '',
      'socials_snapchat': rawData['socials_snapchat'] ?? '',
      'socials_facebook': rawData['socials_facebook'] ?? '',
      'socials_soundcloud': rawData['socials_soundcloud'] ?? '',
      'socials_spotify': rawData['socials_spotify'] ?? '',
    };
    
    // Only include performance info if columns exist in database
    if (rawData.containsKey('frequent_location')) {
      result['frequent_location'] = rawData['frequent_location'];
    }
    if (rawData.containsKey('performance_schedule')) {
      result['performance_schedule'] = rawData['performance_schedule'];
    }
    if (rawData.containsKey('performance_types')) {
      result['performance_types'] = rawData['performance_types'];
    }
    
    return result;
  }

  /// Get user's videos from videos table with performer data joined
  Future<List<Map<String, dynamic>>> getUserVideos(String userId) async {
    try {
      final client = _supabaseService.client;
      
      final response = await client
          .from('videos')
          .select('''
            *,
            performer:user_profiles!performer_id(
              id,
              username,
              full_name,
              profile_image_url,
              performance_type
            )
          ''')
          .eq('performer_id', userId)
          .eq('is_approved', true)
          .order('created_at', ascending: false);

      debugPrint('ProfileService: Retrieved ${response.length} videos with performer data for user $userId');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ProfileService Error: Failed to fetch videos for user $userId - $e');
      return [];
    }
  }

  /// Update user's profile photo URL in database
  Future<bool> updateProfilePhoto(String userId, String imageUrl) async {
    try {
      final client = _supabaseService.client;
      
      await client
          .from('user_profiles')
          .update({'profile_image_url': imageUrl})
          .eq('id', userId);

      debugPrint('ProfileService: Updated profile photo for user $userId');
      return true;
    } catch (e) {
      debugPrint('ProfileService Error: Failed to update profile photo - $e');
      return false;
    }
  }

  /// Get default profile image URL when profile_image_url is null
  String getDefaultProfileImage() {
    return 'assets/images/default_avatar.png'; // Will fall back to icon if asset doesn't exist
  }

  /// Format follower/supporter counts for display (e.g., 1234 -> "1.2K")
  String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return count.toString();
    }
  }

  /// Update user's social media handles
  Future<bool> updateSocialMedia(
    String userId, {
    required String instagram,
    required String tiktok,
    required String youtube,
    required String x,
    required String snapchat,
    required String facebook,
    required String soundcloud,
    required String spotify,
  }) async {
    try {
      final client = _supabaseService.client;
      
      await client
          .from('user_profiles')
          .update({
            'socials_instagram': instagram.isEmpty ? null : instagram,
            'socials_tiktok': tiktok.isEmpty ? null : tiktok,
            'socials_youtube': youtube.isEmpty ? null : youtube,
            'socials_x': x.isEmpty ? null : x,
            'socials_snapchat': snapchat.isEmpty ? null : snapchat,
            'socials_facebook': facebook.isEmpty ? null : facebook,
            'socials_soundcloud': soundcloud.isEmpty ? null : soundcloud,
            'socials_spotify': spotify.isEmpty ? null : spotify,
          })
          .eq('id', userId);

      debugPrint('ProfileService: Updated social media for user $userId');
      return true;
    } catch (e) {
      debugPrint('ProfileService Error: Failed to update social media - $e');
      return false;
    }
  }

  /// Update user's frequent performance location
  Future<bool> updateFrequentLocation(String userId, String location) async {
    try {
      final client = _supabaseService.client;
      
      await client
          .from('user_profiles')
          .update({
            'frequent_location': location.isEmpty ? null : location,
          })
          .eq('id', userId);

      debugPrint('ProfileService: Updated frequent location for user $userId');
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        debugPrint('ProfileService: frequent_location column not available in database');
        return false;
      }
      debugPrint('ProfileService Error: Failed to update frequent location - $e');
      return false;
    } catch (e) {
      debugPrint('ProfileService Error: Failed to update frequent location - $e');
      return false;
    }
  }

  /// Update user's performance schedule
  Future<bool> updatePerformanceSchedule(String userId, String schedule) async {
    try {
      final client = _supabaseService.client;
      
      await client
          .from('user_profiles')
          .update({
            'performance_schedule': schedule.isEmpty ? null : schedule,
          })
          .eq('id', userId);

      debugPrint('ProfileService: Updated performance schedule for user $userId');
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        debugPrint('ProfileService: performance_schedule column not available in database');
        return false;
      }
      debugPrint('ProfileService Error: Failed to update performance schedule - $e');
      return false;
    } catch (e) {
      debugPrint('ProfileService Error: Failed to update performance schedule - $e');
      return false;
    }
  }

  /// Get count of supporters (followers) for a user from user_follows table
  Future<int> getSupportersCount(String userId) async {
    try {
      final client = _supabaseService.client;
      
      final response = await client
          .from('user_follows')
          .select('id')
          .eq('following_id', userId)
          .count();

      final count = response.count;
      debugPrint('ProfileService: Retrieved $count supporters for user $userId');
      return count;
    } catch (e) {
      debugPrint('ProfileService Error: Failed to fetch supporters count for user $userId - $e');
      return 0;
    }
  }

  /// Get count of users this user is supporting (following) from user_follows table
  Future<int> getSupportingCount(String userId) async {
    try {
      final client = _supabaseService.client;
      
      final response = await client
          .from('user_follows')
          .select('id')
          .eq('follower_id', userId)
          .count();

      final count = response.count;
      debugPrint('ProfileService: Retrieved $count supporting for user $userId');
      return count;
    } catch (e) {
      debugPrint('ProfileService Error: Failed to fetch supporting count for user $userId - $e');
      return 0;
    }
  }

  /// Get count of approved videos for a user from videos table
  Future<int> getVideosCount(String userId) async {
    try {
      final client = _supabaseService.client;
      
      final response = await client
          .from('videos')
          .select('id')
          .eq('performer_id', userId)
          .eq('is_approved', true)
          .count();

      final count = response.count;
      debugPrint('ProfileService: Retrieved $count videos for user $userId');
      return count;
    } catch (e) {
      debugPrint('ProfileService Error: Failed to fetch videos count for user $userId - $e');
      return 0;
    }
  }

  /// Get Supabase client for external operations (like updates)
  get client => _supabaseService.client;
}