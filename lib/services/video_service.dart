import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:universal_html/html.dart' as html;

import './supabase_service.dart';

class VideoService {
  final SupabaseService _supabaseService = SupabaseService();
  final Dio _dio = Dio();
  
  String get _baseUrl {
    if (kIsWeb) {
      return html.window.location.origin;
    }
    return 'http://localhost:5000';
  }

  // Upload video with location verification
  Future<Map<String, dynamic>?> uploadVideo({
    required String title,
    required String description,
    required String videoUrl,
    required String thumbnailUrl,
    required int duration,
    required double latitude,
    required double longitude,
    required String locationName,
    required String borough,
  }) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;

      if (userId == null) throw Exception('User not authenticated');

      // Verify NYC location (approximate boundaries)
      if (!_isInNYC(latitude, longitude)) {
        throw Exception(
            'Videos can only be uploaded from within NYC boundaries');
      }

      final response = await client
          .from('videos')
          .insert({
            'performer_id': userId,
            'title': title,
            'description': description,
            'video_url': videoUrl,
            'thumbnail_url': thumbnailUrl,
            'duration': duration,
            'location_latitude': latitude,
            'location_longitude': longitude,
            'location_name': locationName,
            'borough': borough,
            'is_approved': false, // Requires admin approval
          })
          .select()
          .single();

      return response;
    } catch (error) {
      debugPrint('Upload video error: $error');
      rethrow;
    }
  }

  // Get discovery feed (approved videos for all users)
  Future<List<Map<String, dynamic>>> getDiscoveryFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('[FEED_API_CALL] Discovery feed: limit=$limit offset=$offset');
      
      final response = await _dio.get(
        '$_baseUrl/api/feeds/discovery',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      final videos = List<Map<String, dynamic>>.from(
        (response.data['videos'] as List).map((v) => Map<String, dynamic>.from(v))
      );
      
      debugPrint('[FEED_DATA_LOADED] Discovery: ${videos.length} videos');
      return videos;
    } catch (error) {
      debugPrint('[FEED_ERROR] Discovery feed error: $error');
      return [];
    }
  }

  // Get following feed (videos from followed performers)
  Future<List<Map<String, dynamic>>> getFollowingFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('[FEED_API_CALL] Following feed: limit=$limit offset=$offset');
      
      final client = await _supabaseService.client;
      final session = client.auth.currentSession;
      final accessToken = session?.accessToken;
      
      if (accessToken == null) {
        debugPrint('[FEED_ERROR] Following feed: No auth token, using discovery fallback');
        return getDiscoveryFeed(limit: limit, offset: offset);
      }

      final response = await _dio.get(
        '$_baseUrl/api/feeds/following',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final videos = List<Map<String, dynamic>>.from(
        (response.data['videos'] as List).map((v) => Map<String, dynamic>.from(v))
      );
      
      debugPrint('[FEED_DATA_LOADED] Following: ${videos.length} videos');
      
      // If empty, return discovery feed
      if (videos.isEmpty || response.data['isDiscoveryFallback'] == true) {
        debugPrint('[FEED_DATA_LOADED] Following empty, using discovery fallback');
        return getDiscoveryFeed(limit: limit, offset: offset);
      }
      
      return videos;
    } catch (error) {
      debugPrint('[FEED_ERROR] Following feed error: $error, using discovery fallback');
      return getDiscoveryFeed(limit: limit, offset: offset);
    }
  }

  Future<List<String>> _getFollowedPerformerIds() async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      return response
          .map<String>((follow) => follow['following_id'].toString())
          .toList();
    } catch (e) {
      debugPrint('Error fetching followed performer IDs: $e');
      return ['mock-performer-1', 'mock-performer-2', 'mock-performer-3'];
    }
  }

  List<Map<String, dynamic>> _getMockFollowingVideos() {
    return [
      {
        "id": "following-1",
        "title": "Smooth Jazz Session",
        "description":
            "Smooth jazz vibes in Washington Square Park 🎷 #JazzLife #NYCStreets",
        "video_url": "https://example.com/video1.mp4",
        "thumbnail_url":
            "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=800&fit=crop",
        "duration": 180,
        "like_count": 1247,
        "comment_count": 89,
        "share_count": 156,
        "view_count": 5623,
        "location_name": "Washington Square Park",
        "borough": "Manhattan",
        "created_at":
            DateTime.now().subtract(Duration(hours: 3)).toIso8601String(),
        "performer": {
          "id": "performer-1",
          "username": "jazzy_marcus",
          "profile_image_url":
              "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face",
          "performance_type": "musician",
          "is_verified": true
        }
      },
      {
        "id": "following-2",
        "title": "Hip-Hop Freestyle",
        "description":
            "Hip-hop freestyle session! Drop your bars in the comments 🎤 #HipHop #Freestyle",
        "video_url": "https://example.com/video2.mp4",
        "thumbnail_url":
            "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=800&fit=crop",
        "duration": 240,
        "like_count": 2156,
        "comment_count": 234,
        "share_count": 89,
        "view_count": 8934,
        "location_name": "Brooklyn Bridge",
        "borough": "Brooklyn",
        "created_at":
            DateTime.now().subtract(Duration(hours: 5)).toIso8601String(),
        "performer": {
          "id": "performer-2",
          "username": "brooklyn_beats",
          "profile_image_url":
              "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face",
          "performance_type": "singer",
          "is_verified": false
        }
      },
      {
        "id": "following-3",
        "title": "Classical Violin",
        "description":
            "Classical meets modern in Times Square ✨ Playing requests all day!",
        "video_url": "https://example.com/video3.mp4",
        "thumbnail_url":
            "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=800&fit=crop",
        "duration": 300,
        "like_count": 3421,
        "comment_count": 167,
        "share_count": 298,
        "view_count": 12456,
        "location_name": "Times Square",
        "borough": "Manhattan",
        "created_at":
            DateTime.now().subtract(Duration(hours: 8)).toIso8601String(),
        "performer": {
          "id": "performer-3",
          "username": "violin_virtuoso",
          "profile_image_url":
              "https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face",
          "performance_type": "musician",
          "is_verified": true
        }
      },
    ];
  }

  // Get performer's videos
  Future<List<Map<String, dynamic>>> getPerformerVideos(
    String performerId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final client = await _supabaseService.client;

      final response = await client
          .from('videos')
          .select('*')
          .eq('performer_id', performerId)
          .eq('is_approved', true)
          .eq('is_flagged', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Get performer videos error: $error');
      return [];
    }
  }

  // Like/unlike video
  Future<void> toggleVideoLike(String videoId) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;

      if (userId == null) throw Exception('User not authenticated');

      // Check if already liked
      final existingLike = await client
          .from('video_interactions')
          .select()
          .eq('user_id', userId)
          .eq('video_id', videoId)
          .eq('interaction_type', 'like')
          .limit(1);

      if (existingLike.isNotEmpty) {
        // Unlike
        await client
            .from('video_interactions')
            .delete()
            .eq('user_id', userId)
            .eq('video_id', videoId)
            .eq('interaction_type', 'like');
      } else {
        // Like
        await client.from('video_interactions').insert({
          'user_id': userId,
          'video_id': videoId,
          'interaction_type': 'like',
        });
      }
    } catch (error) {
      debugPrint('Toggle video like error: $error');
      rethrow;
    }
  }

  // Record video view
  Future<void> recordVideoView(String videoId) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;

      if (userId == null) return;

      // Check if already viewed by this user (to prevent duplicate views)
      final existingView = await client
          .from('video_interactions')
          .select()
          .eq('user_id', userId)
          .eq('video_id', videoId)
          .eq('interaction_type', 'view')
          .limit(1);

      if (existingView.isEmpty) {
        await client.from('video_interactions').insert({
          'user_id': userId,
          'video_id': videoId,
          'interaction_type': 'view',
        });
      }
    } catch (error) {
      debugPrint('Record video view error: $error');
    }
  }

  // Add comment to video
  Future<Map<String, dynamic>?> addComment(
      String videoId, String content) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;

      if (userId == null) throw Exception('User not authenticated');

      final response = await client.from('comments').insert({
        'video_id': videoId,
        'user_id': userId,
        'content': content,
      }).select('''
            *,
            user:user_profiles!user_id(
              username, full_name, profile_image_url
            )
          ''').single();

      return response;
    } catch (error) {
      debugPrint('Add comment error: $error');
      rethrow;
    }
  }

  // Get video comments
  Future<List<Map<String, dynamic>>> getVideoComments(
    String videoId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final client = await _supabaseService.client;

      final response = await client
          .from('comments')
          .select('''
            *,
            user:user_profiles!user_id(
              username, full_name, profile_image_url
            )
          ''')
          .eq('video_id', videoId)
          .eq('is_flagged', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Get video comments error: $error');
      return [];
    }
  }

  // Repost video (for New Yorkers)
  Future<void> repostVideo(String videoId, {String? caption}) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;

      if (userId == null) throw Exception('User not authenticated');

      await client.from('reposts').insert({
        'user_id': userId,
        'video_id': videoId,
        if (caption != null) 'caption': caption,
      });
    } catch (error) {
      debugPrint('Repost video error: $error');
      rethrow;
    }
  }

  // Get user's reposts
  Future<List<Map<String, dynamic>>> getUserReposts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final client = await _supabaseService.client;

      final response = await client
          .from('reposts')
          .select('''
            *,
            video:videos!video_id(
              *,
              performer:user_profiles!performer_id(
                username, full_name, profile_image_url, 
                performance_types, is_verified
              )
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Get user reposts error: $error');
      return [];
    }
  }

  // Delete video (with 24-hour soft delete safety)
  Future<Map<String, dynamic>> deleteVideo(String videoId) async {
    try {
      // Use html.window.console.log for production builds (debugPrint is stripped)
      if (kIsWeb) {
        html.window.console.log('[DEL_UI] start:$videoId - Calling backend delete endpoint');
      }
      debugPrint('[DEL_UI] start:$videoId - Calling backend delete endpoint');
      
      final client = await _supabaseService.client;
      final session = client.auth.currentSession;
      final accessToken = session?.accessToken;
      
      if (accessToken == null) {
        if (kIsWeb) html.window.console.error('[DEL_UI] fail:$videoId - No auth token available');
        debugPrint('[DEL_UI] fail:$videoId - No auth token available');
        throw Exception('User not authenticated');
      }

      final deleteUrl = '$_baseUrl/api/videos/$videoId';
      if (kIsWeb) {
        html.window.console.log('[DEL_UI] request_url:$deleteUrl');
        html.window.console.log('[DEL_UI] auth_token:${accessToken.substring(0, 20)}...');
      }
      debugPrint('[DEL_UI] request_url:$deleteUrl');

      if (kIsWeb) html.window.console.log('[DEL_UI] sending_delete_request...');
      
      final response = await _dio.delete(
        deleteUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true, // Accept all status codes for handling
        ),
      );

      if (kIsWeb) {
        html.window.console.log('[DEL_UI] response_status:${response.statusCode}');
        html.window.console.log('[DEL_UI] response_type:${response.data.runtimeType}');
        html.window.console.log('[DEL_UI] response_data:${response.data}');
      }
      debugPrint('[DEL_UI] response_status:${response.statusCode}');
      debugPrint('[DEL_UI] response_type:${response.data.runtimeType}');

      if (response.statusCode == 403) {
        if (kIsWeb) html.window.console.error('[DEL_UI] auth_denied:$videoId - User does not own video');
        debugPrint('[DEL_UI] auth_denied:$videoId - User does not own video');
        return {
          'success': false,
          'denied': true,
          'error': 'You cannot delete videos that aren\'t yours.',
        };
      }

      if (response.statusCode == 404) {
        final data = response.data;
        if (data is Map && data['already_deleted'] == true) {
          if (kIsWeb) html.window.console.warn('[DEL_UI] already_deleted:$videoId - Idempotent success');
          debugPrint('[DEL_UI] already_deleted:$videoId - Idempotent success');
          return {
            'success': true,
            'message': 'Video already deleted',
            'already_deleted': true,
          };
        }
        if (kIsWeb) html.window.console.error('[DEL_UI] video_not_found:$videoId');
        debugPrint('[DEL_UI] video_not_found:$videoId');
        return {
          'success': false,
          'error': 'Video not found',
        };
      }

      if (response.statusCode != 200) {
        if (kIsWeb) {
          html.window.console.error('[DEL_UI] fail:$videoId - HTTP ${response.statusCode}');
          html.window.console.error('[DEL_UI] response_data:${response.data}');
        }
        debugPrint('[DEL_UI] fail:$videoId - HTTP ${response.statusCode}');
        debugPrint('[DEL_UI] response_data:${response.data}');
        return {
          'success': false,
          'error': 'Failed to delete video (HTTP ${response.statusCode})',
        };
      }

      // Parse response data
      Map<String, dynamic> result;
      if (response.data is String) {
        // If response is HTML string, it means the request didn't reach the API
        if (kIsWeb) html.window.console.error('[DEL_UI] fail:$videoId - Received HTML instead of JSON');
        debugPrint('[DEL_UI] fail:$videoId - Received HTML instead of JSON');
        return {
          'success': false,
          'error': 'Server returned HTML - API endpoint may not be reachable',
        };
      } else {
        result = response.data as Map<String, dynamic>;
      }

      if (kIsWeb) {
        html.window.console.log('[DEL_UI] ✅ backend_ok:$videoId');
        html.window.console.log('[DEL_UI] verified:${result['verified']}');
      }
      debugPrint('[DEL_UI] backend_ok:$videoId');
      debugPrint('[DEL_UI] verified_ok:$videoId - ${result['verified']}');
      
      return {
        'success': true,
        'message': result['message'] ?? 'Video deleted successfully',
        'deleted': result['deleted'],
        'verified': result['verified'],
      };
    } catch (error, stackTrace) {
      if (kIsWeb) {
        html.window.console.error('[DEL_UI] ❌ EXCEPTION:$videoId');
        html.window.console.error('[DEL_UI] error:$error');
        html.window.console.error('[DEL_UI] stackTrace:$stackTrace');
      }
      debugPrint('[DEL_UI] fail:$videoId:$error');
      debugPrint('[DEL_UI] stackTrace:$stackTrace');
      return {
        'success': false,
        'error': 'Failed to delete video: $error',
      };
    }
  }

  // Verify video is deleted from database
  Future<bool> verifyDatabaseDeletion(String videoId) async {
    try {
      final client = await _supabaseService.client;
      final response = await client
          .from('videos')
          .select('id')
          .eq('id', videoId)
          .limit(1);
      
      final deleted = response.isEmpty;
      if (kIsWeb) {
        html.window.console.log('[DELETE_VERIFIED_DB] videoId=$videoId deleted=$deleted');
      }
      return deleted;
    } catch (e) {
      if (kIsWeb) {
        html.window.console.error('[DELETE_VERIFY_FAIL_DB] videoId=$videoId error=$e');
      }
      return false;
    }
  }

  // Verify video files are deleted from storage
  Future<bool> verifyStorageDeletion(String videoId) async {
    try {
      // Try to fetch the video URL - should return 404
      final videoUrl = '$_baseUrl/api/videos/$videoId';
      final response = await _dio.get(
        videoUrl,
        options: Options(validateStatus: (status) => true),
      );
      
      final deleted = (response.statusCode == 404);
      if (kIsWeb) {
        html.window.console.log('[DELETE_VERIFIED_STORAGE] videoId=$videoId deleted=$deleted status=${response.statusCode}');
      }
      return deleted;
    } catch (e) {
      if (kIsWeb) {
        html.window.console.error('[DELETE_VERIFY_FAIL_STORAGE] videoId=$videoId error=$e');
      }
      return false;
    }
  }

  // Helper: Check if coordinates are within NYC boundaries (approximate)
  bool _isInNYC(double latitude, double longitude) {
    // NYC approximate boundaries
    const double minLat = 40.4774;
    const double maxLat = 40.9176;
    const double minLng = -74.2591;
    const double maxLng = -73.7004;

    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLng &&
        longitude <= maxLng;
  }
}
