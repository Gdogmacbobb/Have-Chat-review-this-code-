import 'package:flutter/foundation.dart';

import './supabase_service.dart';

class UserService {
  final SupabaseService _supabaseService = SupabaseService();

  // Get performer profile by ID
  Future<Map<String, dynamic>?> getPerformerProfile(String performerId) async {
    try {
      final client = await _supabaseService.client;
      
      final response = await client
          .from('user_profiles')
          .select('''
            *,
            follower_count:follows!following_id(count),
            following_count:follows!follower_id(count)
          ''')
          .eq('id', performerId)
          .eq('role', 'street_performer')
          .single();

      return response;
    } catch (error) {
      debugPrint('Get performer profile error: $error');
      return null;
    }
  }

  // Search performers
  Future<List<Map<String, dynamic>>> searchPerformers({
    String? query,
    String? performanceType,
    String? borough,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final client = await _supabaseService.client;
      
      var queryBuilder = client
          .from('user_profiles')
          .select('''
            *,
            recent_videos:videos!performer_id(
              id, title, thumbnail_url, view_count, like_count, created_at
            )
          ''')
          .eq('role', 'street_performer')
          .eq('is_verified', true);

      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or('username.ilike.%$query%,full_name.ilike.%$query%');
      }

      if (performanceType != null) {
        queryBuilder = queryBuilder.eq('performance_type', performanceType);
      }

      final response = await queryBuilder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Search performers error: $error');
      return [];
    }
  }

  // Follow/unfollow performer
  Future<void> toggleFollowPerformer(String performerId) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;
      
      if (userId == null) throw Exception('User not authenticated');
      if (userId == performerId) throw Exception('Cannot follow yourself');

      // Check if already following
      final existingFollow = await client
          .from('follows')
          .select()
          .eq('follower_id', userId)
          .eq('following_id', performerId)
          .limit(1);

      if (existingFollow.isNotEmpty) {
        // Unfollow
        await client
            .from('follows')
            .delete()
            .eq('follower_id', userId)
            .eq('following_id', performerId);
      } else {
        // Follow
        await client
            .from('follows')
            .insert({
              'follower_id': userId,
              'following_id': performerId,
            });

        // Create notification
        await _createFollowNotification(performerId);
      }
    } catch (error) {
      debugPrint('Toggle follow performer error: $error');
      rethrow;
    }
  }

  // Check if following performer
  Future<bool> isFollowingPerformer(String performerId) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;
      
      if (userId == null) return false;

      final response = await client
          .from('follows')
          .select()
          .eq('follower_id', userId)
          .eq('following_id', performerId)
          .limit(1);

      return response.isNotEmpty;
    } catch (error) {
      debugPrint('Check follow status error: $error');
      return false;
    }
  }

  // Get user's followed performers
  Future<List<Map<String, dynamic>>> getFollowedPerformers(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final client = await _supabaseService.client;
      
      final response = await client
          .from('follows')
          .select('''
            *,
            performer:user_profiles!following_id(
              id, username, full_name, profile_image_url, 
              performance_type, is_verified, bio
            )
          ''')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Get followed performers error: $error');
      return [];
    }
  }

  // Get user's followers
  Future<List<Map<String, dynamic>>> getUserFollowers(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final client = await _supabaseService.client;
      
      final response = await client
          .from('follows')
          .select('''
            *,
            follower:user_profiles!follower_id(
              id, username, full_name, profile_image_url, role
            )
          ''')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Get user followers error: $error');
      return [];
    }
  }

  // Get user statistics
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final client = await _supabaseService.client;
      
      // Get user profile to determine role
      final profile = await client
          .from('user_profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final role = profile['role'] as String;
      
      if (role == 'street_performer') {
        return await _getPerformerStats(userId);
      } else {
        return await _getNewYorkerStats(userId);
      }
    } catch (error) {
      debugPrint('Get user stats error: $error');
      return {};
    }
  }

  // Get notifications for user
  Future<List<Map<String, dynamic>>> getUserNotifications(
    String userId, {
    bool unreadOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final client = await _supabaseService.client;
      
      var queryBuilder = client
          .from('notifications')
          .select()
          .eq('user_id', userId);

      if (unreadOnly) {
        queryBuilder = queryBuilder.eq('is_read', false);
      }

      final response = await queryBuilder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Get user notifications error: $error');
      return [];
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final client = await _supabaseService.client;
      
      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (error) {
      debugPrint('Mark notification as read error: $error');
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;
      
      if (userId == null) return;

      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (error) {
      debugPrint('Mark all notifications as read error: $error');
    }
  }

  // Get performer statistics
  Future<Map<String, dynamic>> _getPerformerStats(String performerId) async {
    try {
      final client = await _supabaseService.client;
      
      final videoIds = await _getPerformerVideoIds(performerId);
      
      final results = await Future.wait([
        // Video count
        client
            .from('videos')
            .select()
            .eq('performer_id', performerId)
            .eq('is_approved', true)
            .count(),
        
        // Total views
        client
            .from('video_interactions')
            .select()
            .eq('interaction_type', 'view')
            .inFilter('video_id', videoIds)
            .count(),
        
        // Total likes
        client
            .from('video_interactions')
            .select()
            .eq('interaction_type', 'like')
            .inFilter('video_id', videoIds)
            .count(),
        
        // Follower count
        client
            .from('follows')
            .select()
            .eq('following_id', performerId)
            .count(),
        
        // Following count
        client
            .from('follows')
            .select()
            .eq('follower_id', performerId)
            .count(),
      ]);

      return {
        'video_count': results[0].count ?? 0,
        'total_views': results[1].count ?? 0,
        'total_likes': results[2].count ?? 0,
        'follower_count': results[3].count ?? 0,
        'following_count': results[4].count ?? 0,
      };
    } catch (error) {
      debugPrint('Get performer stats error: $error');
      return {};
    }
  }

  // Get New Yorker statistics
  Future<Map<String, dynamic>> _getNewYorkerStats(String userId) async {
    try {
      final client = await _supabaseService.client;
      
      final results = await Future.wait([
        // Following count
        client
            .from('follows')
            .select()
            .eq('follower_id', userId)
            .count(),
        
        // Reposts count
        client
            .from('reposts')
            .select()
            .eq('user_id', userId)
            .count(),
        
        // Donations made count
        client
            .from('donations')
            .select()
            .eq('donor_id', userId)
            .eq('transaction_status', 'completed')
            .count(),
      ]);

      return {
        'following_count': results[0].count ?? 0,
        'reposts_count': results[1].count ?? 0,
        'donations_made': results[2].count ?? 0,
      };
    } catch (error) {
      debugPrint('Get New Yorker stats error: $error');
      return {};
    }
  }

  // Helper: Get performer's video IDs
  Future<List<String>> _getPerformerVideoIds(String performerId) async {
    try {
      final client = await _supabaseService.client;
      
      final response = await client
          .from('videos')
          .select('id')
          .eq('performer_id', performerId)
          .eq('is_approved', true);

      return response.map<String>((video) => video['id'] as String).toList();
    } catch (error) {
      debugPrint('Get performer video IDs error: $error');
      return [];
    }
  }

  // Create follow notification
  Future<void> _createFollowNotification(String performerId) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;
      
      if (userId == null) return;

      // Get follower's name
      final followerProfile = await client
          .from('user_profiles')
          .select('username, full_name')
          .eq('id', userId)
          .single();

      final followerName = followerProfile['full_name'] ?? followerProfile['username'];

      await client
          .from('notifications')
          .insert({
            'user_id': performerId,
            'type': 'follow',
            'title': 'New Follower!',
            'message': '$followerName started following you!',
            'data': {'follower_id': userId},
          });
    } catch (error) {
      debugPrint('Create follow notification error: $error');
    }
  }
}
