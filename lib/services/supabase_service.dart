import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  // Singleton pattern
  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Client getter - uses single initialized instance
  SupabaseClient get client {
    return Supabase.instance.client;
  }

  // No-op for backward compatibility
  Future<void> waitForInitialization() async {
    // Supabase is initialized in main.dart, nothing to wait for
  }

  // Current user
  User? get currentUser => client.auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Session management
  Future<AuthResponse> waitForInitialSession({Duration? timeout}) async {
    final session = client.auth.currentSession;
    return AuthResponse(session: session);
  }

  Future<bool> hasValidSession() async {
    final session = client.auth.currentSession;
    return session != null && !session.isExpired;
  }

  // Connectivity check - verifies Supabase is reachable
  Future<bool> checkSupabaseConnection() async {
    try {
      await client.from('user_profiles').select().limit(1);
      debugPrint('[SUPABASE STATUS] Connected successfully ✅');
      return true;
    } catch (e) {
      debugPrint('[SUPABASE ERROR] Connection failed ❌: $e');
      return false;
    }
  }

  // Authentication methods
  Future<AuthResponse> signInWithPassword(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('[SUPABASE] Sign in successful for: $email');
      return response;
    } catch (e) {
      debugPrint('[SUPABASE] Sign in error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );
      debugPrint('[SUPABASE] Sign up successful for: $email');
      return response;
    } catch (e) {
      debugPrint('[SUPABASE] Sign up error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
      debugPrint('[SUPABASE] Sign out successful');
    } catch (e) {
      debugPrint('[SUPABASE] Sign out error: $e');
      rethrow;
    }
  }

  Future<void> setSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await client.auth.setSession(refreshToken);
      debugPrint('[SUPABASE] Session set successfully with refresh token');
    } catch (e) {
      debugPrint('[SUPABASE] Set session error: $e');
      rethrow;
    }
  }

  // Auth state stream
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // User profile methods
  Future<String?> getUserRole() async {
    try {
      final user = currentUser;
      if (user == null) return null;
      
      final response = await client
          .from('user_profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
          
      return response?['role'];
    } catch (e) {
      debugPrint('[SUPABASE] Get user role error: $e');
      return null;
    }
  }

  Future<bool> isStreetPerformer() async {
    final role = await getUserRole();
    return role == 'street_performer';
  }

  Future<bool> isNewYorker() async {
    final role = await getUserRole();
    return role == 'new_yorker';
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;
      
      final response = await client
          .from('user_profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();
          
      return response;
    } catch (e) {
      debugPrint('[SUPABASE] Get current user profile error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await client
          .from('user_profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
          
      return response;
    } catch (e) {
      debugPrint('[SUPABASE] Get user profile error: $e');
      return null;
    }
  }

  // Simplified count methods (using length instead of count for compatibility)
  Future<int> getFollowerCount(String userId) async {
    try {
      final response = await client
          .from('follows')
          .select('id')
          .eq('following_id', userId);
          
      return response.length;
    } catch (e) {
      debugPrint('[SUPABASE] Get follower count error: $e');
      return 0;
    }
  }

  Future<int> getFollowingCount(String userId) async {
    try {
      final response = await client
          .from('follows')
          .select('id')
          .eq('follower_id', userId);
          
      return response.length;
    } catch (e) {
      debugPrint('[SUPABASE] Get following count error: $e');
      return 0;
    }
  }

  Future<int> getVideoCount(String userId) async {
    try {
      final response = await client
          .from('videos')
          .select('id')
          .eq('performer_id', userId);
          
      return response.length;
    } catch (e) {
      debugPrint('[SUPABASE] Get video count error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getUserVideos(String userId, {int limit = 20}) async {
    try {
      final response = await client
          .from('videos')
          .select('*')
          .eq('performer_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SUPABASE] Get user videos error: $e');
      return [];
    }
  }

  Future<bool> isFollowing(String targetUserId) async {
    try {
      final user = currentUser;
      if (user == null) return false;
      
      final response = await client
          .from('follows')
          .select('id')
          .eq('follower_id', user.id)
          .eq('following_id', targetUserId)
          .maybeSingle();
          
      return response != null;
    } catch (e) {
      debugPrint('[SUPABASE] Is following error: $e');
      return false;
    }
  }

  Future<bool> toggleFollow(String targetUserId) async {
    try {
      final user = currentUser;
      if (user == null) return false;
      
      final isCurrentlyFollowing = await isFollowing(targetUserId);
      
      if (isCurrentlyFollowing) {
        await client
            .from('follows')
            .delete()
            .eq('follower_id', user.id)
            .eq('following_id', targetUserId);
        return false;
      } else {
        await client
            .from('follows')
            .insert({
              'follower_id': user.id,
              'following_id': targetUserId,
            });
        return true;
      }
    } catch (e) {
      debugPrint('[SUPABASE] Toggle follow error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getFullProfileData() async {
    try {
      final user = currentUser;
      if (user == null) return null;
      
      final profile = await getCurrentUserProfile();
      if (profile == null) return null;
      
      final followerCount = await getFollowerCount(user.id);
      final followingCount = await getFollowingCount(user.id);
      final videoCount = await getVideoCount(user.id);
      
      return {
        ...profile,
        'follower_count': followerCount,
        'following_count': followingCount,
        'video_count': videoCount,
      };
    } catch (e) {
      debugPrint('[SUPABASE] Get full profile data error: $e');
      return null;
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final user = currentUser;
      if (user == null) return false;
      
      await client
          .from('users')
          .update(updates)
          .eq('id', user.id);
          
      debugPrint('[SUPABASE] Profile updated successfully');
      return true;
    } catch (e) {
      debugPrint('[SUPABASE] Update profile error: $e');
      return false;
    }
  }

  // Video discovery methods
  Future<List<Map<String, dynamic>>> getDiscoveryVideos({int limit = 20, int offset = 0}) async {
    try {
      final response = await client
          .from('videos')
          .select('''
            *,
            users:performer_id (
              id,
              display_name,
              handle,
              avatar_url,
              user_type
            )
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SUPABASE] Get discovery videos error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFollowingVideos({int limit = 20, int offset = 0}) async {
    try {
      final user = currentUser;
      if (user == null) return [];
      
      // Get following IDs first
      final followingIds = await _getFollowingIds(user.id);
      if (followingIds.isEmpty) return [];
      
      final response = await client
          .from('videos')
          .select('''
            *,
            users:performer_id (
              id,
              display_name,
              handle,
              avatar_url,
              user_type
            )
          ''')
          .filter('performer_id', 'in', '(${followingIds.join(',')})')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SUPABASE] Get following videos error: $e');
      return [];
    }
  }

  Future<List<String>> _getFollowingIds(String userId) async {
    try {
      final response = await client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
          
      return response.map<String>((row) => row['following_id'] as String).toList();
    } catch (e) {
      debugPrint('[SUPABASE] Get following IDs error: $e');
      return [];
    }
  }
}
