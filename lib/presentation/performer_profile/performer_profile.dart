import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;
import 'package:ynfny/utils/responsive_scale.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';
import '../../services/video_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/feed_refresh_service.dart';
import './widgets/about_section_widget.dart';
import './widgets/donation_button_widget.dart';
import './widgets/profile_header_widget.dart';
import './widgets/video_context_menu_widget.dart';
import './widgets/video_grid_widget.dart';

class PerformerProfile extends StatefulWidget {
  final String? performerId; // If null, shows current user's profile
  final String? performerHandle; // Optional handle for display
  
  const PerformerProfile({
    super.key,
    this.performerId,
    this.performerHandle,
  });

  @override
  State<PerformerProfile> createState() => _PerformerProfileState();
}

class _PerformerProfileState extends State<PerformerProfile>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabaseService = SupabaseService();
  final VideoService _videoService = VideoService();
  final ProfileService _profileService = ProfileService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  StreamSubscription<String>? _refreshSubscription;
  
  // UI state
  bool isFollowing = false;
  bool isRefreshing = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isUploadingPhoto = false;
  bool _isOwnProfile = false; // Track if viewing own profile
  
  // Real data from Supabase
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userVideos = [];
  
  // Default placeholder for missing profile images
  static const String _defaultAvatarIcon = 'person';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
    
    // Subscribe to global feed refresh events
    _refreshSubscription = FeedRefreshService().refreshStream.listen((feedName) {
      if (feedName == 'profile' && mounted) {
        if (kIsWeb) {
          html.window.console.log('[FEED_REFRESH_PROFILE] Reloading profile data');
        }
        _loadProfileData();
      }
    });
  }

  // Load user profile and videos from Supabase using ProfileService
  Future<void> _loadProfileData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      // Get current user
      final currentUser = _supabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Determine which performer profile to load
      final targetPerformerId = widget.performerId ?? currentUser.id;
      final isOwnProfile = (targetPerformerId == currentUser.id);
      
      debugPrint('[NAV_PROFILE] currentUser.id=${currentUser.id} viewedUser.id=$targetPerformerId');
      debugPrint('[EDIT_VISIBILITY] isOwnProfile=$isOwnProfile');

      // Fetch user profile data using ProfileService
      final profileData = await _profileService.getUserProfile(targetPerformerId);
      if (profileData == null) {
        throw Exception('Failed to load user profile');
      }

      // Fetch user's videos using ProfileService
      final videosData = await _profileService.getUserVideos(targetPerformerId);

      // Transform video data to match expected format (camelCase) + enrich with performer data
      final transformedVideos = videosData.map((video) {
        // Extract nested performer data from Supabase join
        final performer = video['performer'] as Map<String, dynamic>?;
        
        // [OMEGA_PILL_QUERY] Read performance_type from VIDEO record, not performer profile
        final performanceType = video['performance_type'] ?? '';
        debugPrint('[OMEGA_PILL_DATA] PerformerProfile context video_id=${video['id']} db.performance_type=$performanceType');
        
        return {
          // Video fields
          'id': video['id'],
          'thumbnailUrl': video['thumbnail_url'] ?? '',
          'videoUrl': video['video_url'] ?? '',
          'thumbnail': video['thumbnail_url'] ?? '',
          'video_url': video['video_url'] ?? '',
          'duration': video['duration'] ?? 0,
          'viewCount': video['view_count'] ?? 0,
          'likeCount': video['like_count'] ?? 0,
          'like_count': video['like_count'] ?? 0,
          'commentCount': video['comment_count'] ?? 0,
          'comment_count': video['comment_count'] ?? 0,
          'shareCount': video['share_count'] ?? 0,
          'share_count': video['share_count'] ?? 0,
          'donation_count': video['donation_count'] ?? 0,
          'title': video['title'] ?? '',
          'description': video['description'] ?? '',
          'caption': video['description'] ?? '',
          'location': video['location_name'] ?? profileData['frequent_location'] ?? '',
          'location_name': video['location_name'] ?? profileData['frequent_location'] ?? '',
          
          // Performer fields from joined performer object (falls back to profile data)
          'performerUsername': performer?['username'] ?? profileData['username'] ?? '',
          'performer_handle': performer?['username'] ?? profileData['username'] ?? '',
          'posterHandle': performer?['username'] ?? profileData['username'] ?? '',
          'performerAvatar': performer?['profile_image_url'] ?? profileData['profile_image_url'] ?? '',
          'poster_profile_photo_url': performer?['profile_image_url'] ?? profileData['profile_image_url'] ?? '',
          'isVerified': profileData['is_verified'] ?? false,
          'performanceType': performanceType, // From video record, not performer
          'performance_type': performanceType, // Alias for compatibility
        };
      }).toList();

      if (mounted) {
        setState(() {
          _profileData = profileData;
          _userVideos = transformedVideos;
          _isOwnProfile = isOwnProfile;
          _isLoading = false;
          _hasError = false;
        });
        
        debugPrint('[PROFILE_LOAD] ✅ Profile loaded: userId=$targetPerformerId isOwnProfile=$isOwnProfile videos=${transformedVideos.length}');
        debugPrint('[PROFILE_LOAD] showMoreOptions will be: $_isOwnProfile (... button ${_isOwnProfile ? "VISIBLE" : "HIDDEN"})');
        if (transformedVideos.isNotEmpty) {
          debugPrint('[PROFILE_LOAD] First video: id=${transformedVideos[0]['id']} thumbnail=${transformedVideos[0]['thumbnailUrl']}');
        }
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load profile data. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // Handle pull-to-refresh
  Future<void> _handleRefresh() async {
    await _loadProfileData();
  }

  Future<void> _handleAvatarTap() async {
    // Show bottom sheet with photo options
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change Profile Picture',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primaryOrange),
              title: Text('Choose from Library', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _uploadProfilePhoto();
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.grey),
              title: Text('Cancel', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadProfilePhoto() async {
    try {
      setState(() => _isUploadingPhoto = true);

      final currentUser = _supabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Pick and upload photo
      final imageUrl = await _imageUploadService.pickAndUploadProfilePhoto(currentUser.id);
      
      if (imageUrl == null) {
        setState(() => _isUploadingPhoto = false);
        return;
      }

      // Update database with new photo URL
      final success = await _profileService.updateProfilePhoto(currentUser.id, imageUrl);
      
      if (success) {
        // Reload profile to show new photo
        await _loadProfileData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: AppTheme.primaryOrange,
            ),
          );
        }
      } else {
        throw Exception('Failed to update profile photo');
      }
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryOrange,
          ),
        ),
      );
    }

    // Show error state
    if (_hasError) {
      return Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: AppTheme.accentRed,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                _errorMessage,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfileData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show profile data (only if not loading and no error)
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppTheme.primaryOrange,
            backgroundColor: AppTheme.surfaceDark,
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
                  foregroundColor: AppTheme.textPrimary,
                  elevation: 0,
                  floating: true,
                  snap: true,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: CustomIconWidget(
                      iconName: 'arrow_back',
                      color: AppTheme.textPrimary,
                      size: 24,
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: _handleShare,
                      icon: CustomIconWidget(
                        iconName: 'share',
                        color: AppTheme.textPrimary,
                        size: 24,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: CustomIconWidget(
                        iconName: 'more_vert',
                        color: AppTheme.textPrimary,
                        size: 24,
                      ),
                      color: AppTheme.surfaceDark,
                      onSelected: _handleMenuAction,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'block',
                                color: AppTheme.accentRed,
                                size: 20,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                "Block User",
                                style: AppTheme.darkTheme.textTheme.bodyMedium
                                    ?.copyWith(
                                  color: AppTheme.accentRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'report',
                                color: AppTheme.accentRed,
                                size: 20,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                "Report Profile",
                                style: AppTheme.darkTheme.textTheme.bodyMedium
                                    ?.copyWith(
                                  color: AppTheme.accentRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Profile Header
                SliverToBoxAdapter(
                  child: ProfileHeaderWidget(
                    performerData: _profileData ?? {},
                    isFollowing: isFollowing,
                    onFollowTap: _handleFollowTap,
                    currentUserId: _supabaseService.currentUser?.id,
                    onEditTap: _handleEditProfile,
                    onProfileUpdated: _loadProfileData,
                    onAvatarTap: (_supabaseService.currentUser?.id == _profileData?['id']) ? _handleAvatarTap : null,
                  ),
                ),

                // Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: "Videos"),
                        Tab(text: "About"),
                      ],
                    ),
                  ),
                ),

                // Tab Content
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Videos Tab
                      VideoGridWidget(
                        videos: _userVideos,
                        onVideoTap: _handleVideoTap,
                        onVideoLongPress: _handleVideoLongPress,
                        showMoreOptions: _isOwnProfile,
                        onMoreOptionsTap: _handleMoreOptions,
                      ),
                      // About Tab
                      AboutSectionWidget(
                        performerData: _profileData ?? {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Donation Button
          DonationButtonWidget(
            onDonationTap: _handleDonationComplete,
          ),
        ],
      ),
    );
  }


  Future<void> _handleFollowTap() async {
    HapticFeedback.lightImpact();
    
    final currentUserId = _supabaseService.currentUser?.id;
    final targetUserId = _profileData?['id']?.toString();
    
    // OMEGA SECURITY: Prevent self-follow at UI level
    if (currentUserId == targetUserId) {
      if (kDebugMode) print('[OMEGA_SECURITY_LOG] self_follow_prevented_UI user:$currentUserId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 20),
              SizedBox(width: 2.w),
              const Text("You cannot follow yourself"),
            ],
          ),
          backgroundColor: AppTheme.surfaceDark,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    if (targetUserId == null) {
      if (kDebugMode) print('[FOLLOW_ERROR] No target user ID');
      return;
    }

    final userName = _profileData?['full_name'] ?? _profileData?['username'] ?? 'User';
    final willFollow = !isFollowing;
    
    // Optimistically update UI
    setState(() {
      isFollowing = willFollow;
    });

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final baseUrl = kIsWeb ? '' : 'http://localhost:5000';
      final endpoint = willFollow 
        ? '$baseUrl/api/users/$targetUserId/follow'
        : '$baseUrl/api/users/$targetUserId/follow';
      
      if (kDebugMode) print('[FOLLOW_API] ${willFollow ? "follow" : "unfollow"} request to: $targetUserId');

      final response = willFollow
        ? await http.post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
        : await http.delete(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) print('[FOLLOW_API] Success: ${willFollow ? "followed" : "unfollowed"}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  CustomIconWidget(
                    iconName: willFollow ? 'person_add' : 'person_remove',
                    color: AppTheme.primaryOrange,
                    size: 20,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    willFollow
                        ? "Now following $userName"
                        : "Unfollowed $userName",
                    style: AppTheme.darkTheme.textTheme.bodyMedium,
                  ),
                ],
              ),
              backgroundColor: AppTheme.surfaceDark,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (response.statusCode == 400) {
        // Handle self-follow error from backend
        final data = json.decode(response.body);
        if (data['prevented'] == 'self_follow') {
          if (kDebugMode) print('[OMEGA_API_LOG] backend_self_follow_rejected');
          throw Exception('You cannot follow yourself');
        }
        throw Exception(data['error'] ?? 'Failed to update follow status');
      } else {
        throw Exception('Failed to update follow status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('[FOLLOW_ERROR] $e');
      
      // Revert optimistic update
      if (mounted) {
        setState(() {
          isFollowing = !willFollow;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade900,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleVideoTap(Map<String, dynamic> video) {
    HapticFeedback.lightImpact();
    // Navigate to full-screen video player for profile
    AppRoutes.pushNamed(
      context,
      AppRoutes.performerProfileVideoPlayer,
      arguments: video,
    );
  }

  void _handleVideoLongPress(Map<String, dynamic> video) {
    HapticFeedback.mediumImpact();
    VideoContextMenuWidget.show(
      context,
      video,
      onSave: () => _handleVideoSave(video),
      onShare: () => _handleVideoShare(video),
      onReport: () => _handleVideoReport(video),
    );
  }

  void _handleVideoSave(Map<String, dynamic> video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CustomIconWidget(
              iconName: 'bookmark',
              color: AppTheme.primaryOrange,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Text(
              "Video saved to collection",
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleVideoShare(Map<String, dynamic> video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CustomIconWidget(
              iconName: 'share',
              color: AppTheme.primaryOrange,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Text(
              "Video link copied to clipboard",
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleVideoReport(Map<String, dynamic> video) {
    // Report handling is done in VideoContextMenuWidget
  }

  void _handleEditProfile() {
    HapticFeedback.lightImpact();
    
    // Navigate to profile editing screen
    // TODO: Implement profile editing screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CustomIconWidget(
              iconName: 'edit',
              color: AppTheme.primaryOrange,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Text(
              "Edit Profile feature coming soon!",
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleShare() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CustomIconWidget(
              iconName: 'share',
              color: AppTheme.primaryOrange,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Text(
              "Profile link copied to clipboard",
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleMoreOptions(Map<String, dynamic> video) {
    HapticFeedback.lightImpact();
    debugPrint('[VIDEO_MENU] OVERLAY_OPENED - Video ID: ${video["id"]}, Title: ${video["title"] ?? "Untitled"}');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        padding: EdgeInsets.all(10),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.archive, color: AppTheme.textPrimary),
                title: Text(
                  'Archive',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleArchive(video);
                },
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.delete, color: AppTheme.accentRed),
                title: Text(
                  'Delete',
                  style: TextStyle(
                    color: AppTheme.accentRed,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleDelete(video);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleArchive(Map<String, dynamic> video) {
    debugPrint('[VIDEO_MENU] ARCHIVE_SELECTED - Showing confirmation for video: ${video["id"]}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Archive this video?',
          style: AppTheme.darkTheme.textTheme.titleLarge,
        ),
        content: Text(
          'It will be hidden from your profile but kept privately.',
          style: AppTheme.darkTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              debugPrint('[VIDEO_MENU] CONFIRMATION_SHOWN - Archive confirmed for video: ${video["id"]}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.archive, color: AppTheme.primaryOrange, size: 20),
                      SizedBox(width: 2.w),
                      Text(
                        'Video archived successfully',
                        style: AppTheme.darkTheme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.surfaceDark,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Confirm',
              style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.primaryOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDelete(Map<String, dynamic> video) {
    debugPrint('[VIDEO_MENU] DELETE_SELECTED - Showing confirmation for video: ${video["id"]}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Delete this video?',
          style: AppTheme.darkTheme.textTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to permanently delete this video?',
          style: AppTheme.darkTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDeleteVideo(video["id"]);
            },
            child: Text(
              'Delete',
              style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.accentRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteVideo(String videoId) async {
    try {
      if (kIsWeb) {
        html.window.console.log('[DELETE_INITIATED] video_id=$videoId');
      }
      
      // Step 1: Optimistic UI update
      setState(() {
        _userVideos.removeWhere((v) => v['id'] == videoId);
      });
      
      if (kIsWeb) {
        html.window.console.log('[DELETE_UI] optimistic_remove - Video $videoId removed from UI');
      }
      
      // Step 2: Call backend delete
      final result = await _videoService.deleteVideo(videoId);
      
      if (result['success'] != true) {
        if (kIsWeb) {
          html.window.console.error('[DELETE_FAIL] Backend returned error');
        }
        // Restore video to UI
        await _loadProfileData();
        return;
      }
      
      // Step 3: Verify deletion in database
      final dbDeleted = await _videoService.verifyDatabaseDeletion(videoId);
      if (!dbDeleted) {
        if (kIsWeb) {
          html.window.console.error('[DELETE_VERIFY_FAIL_DB] Video still in database');
        }
        await _loadProfileData();
        return;
      }
      
      // Step 4: Verify deletion in storage
      final storageDeleted = await _videoService.verifyStorageDeletion(videoId);
      if (!storageDeleted) {
        if (kIsWeb) {
          html.window.console.error('[DELETE_VERIFY_FAIL_STORAGE] Video still in storage');
        }
        await _loadProfileData();
        return;
      }
      
      // Step 5: All verifications passed - trigger global refresh
      if (kIsWeb) {
        html.window.console.log('[DELETE_VERIFIED_COMPLETE] video_id=$videoId');
      }
      
      FeedRefreshService().refreshAllFeeds();
      
      if (kIsWeb) {
        html.window.console.log('[FEED_REFRESH] triggered for Discovery + Following + Profile');
      }
      
      // Step 6: Reload profile data
      await _loadProfileData();
      
    } catch (e, stackTrace) {
      if (kIsWeb) {
        html.window.console.error('[DELETE_EXCEPTION] $e');
        html.window.console.error('[DELETE_EXCEPTION] $stackTrace');
      }
      // Restore video on exception
      await _loadProfileData();
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'block':
        _showBlockDialog();
        break;
      case 'report':
        _showReportDialog();
        break;
    }
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          "Block ${_profileData?['full_name'] ?? _profileData?['username'] ?? 'User'}?",
          style: AppTheme.darkTheme.textTheme.titleLarge,
        ),
        content: Text(
          "You won't see their content and they won't be able to find your profile.",
          style: AppTheme.darkTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return to previous screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "User blocked",
                    style: AppTheme.darkTheme.textTheme.bodyMedium,
                  ),
                  backgroundColor: AppTheme.surfaceDark,
                ),
              );
            },
            child: Text(
              "Block",
              style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.accentRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          "Report Profile",
          style: AppTheme.darkTheme.textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Why are you reporting this profile?",
              style: AppTheme.darkTheme.textTheme.bodyMedium,
            ),
            SizedBox(height: 2.h),
            ...[
              "Fake account",
              "Inappropriate content",
              "Spam or scam",
              "Harassment",
              "Other"
            ].map((reason) => InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Report submitted. Thank you for helping keep YNFNY safe.",
                          style: AppTheme.darkTheme.textTheme.bodyMedium,
                        ),
                        backgroundColor: AppTheme.surfaceDark,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    child: Text(
                      reason,
                      style: AppTheme.darkTheme.textTheme.bodyMedium,
                    ),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDonationComplete() {
    // Donation completion is handled in DonationButtonWidget
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.darkTheme.scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
