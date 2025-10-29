import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../services/video_service.dart';
import '../../services/feed_refresh_service.dart';
import '../../widgets/feed_navigation_bottom_widget.dart';
import '../../widgets/feed_navigation_header_widget.dart';
import './widgets/video_player_widget.dart';
import '../performer_profile/performer_profile.dart';

class DiscoveryFeed extends StatefulWidget {
  const DiscoveryFeed({Key? key}) : super(key: key);

  @override
  State<DiscoveryFeed> createState() => _DiscoveryFeedState();
}

class _DiscoveryFeedState extends State<DiscoveryFeed>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final VideoService _videoService = VideoService();
  final SupabaseService _supabaseService = SupabaseService();

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentVideoIndex = 0;
  String? _currentUserRole;
  bool _isLoadingMore = false;
  bool _isInitialized = false;
  StreamSubscription<String>? _refreshSubscription;

  // Add video management state
  final Set<int> _loadedVideoIndices = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _refreshSubscription = FeedRefreshService().refreshStream.listen((feedName) {
      if (feedName == 'discovery') {
        _retryLoading();
      }
    });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    if (_isInitialized) return;

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      await _loadInitialData();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    try {
      // Get user role with timeout and error handling
      try {
        _currentUserRole =
            await _supabaseService.getUserRole().timeout(Duration(seconds: 5));
      } catch (e) {
        debugPrint('User role fetch error: $e');
        _currentUserRole = null; // Continue without user role
      }

      // Load discovery feed with fallback to mock data
      List<Map<String, dynamic>> videos = [];
      try {
        videos = await _videoService
            .getDiscoveryFeed(limit: 20)
            .timeout(Duration(seconds: 10));
      } catch (e) {
        debugPrint('Video service error: $e');
        // On error, show empty state instead of mock data
        videos = [];
      }

      // Handle empty response gracefully with real empty state
      if (videos.isEmpty) {
        debugPrint('No videos available from service');
      }

      if (mounted) {
        setState(() {
          _videos = videos.map((video) => _transformVideoData(video)).toList();
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading discovery feed: $e');
      // Handle error state gracefully
      if (mounted) {
        setState(() {
          _videos = []; // Show empty state instead of mock data
          _hasError = true;
          _errorMessage = 'Failed to load videos. Please try again.';
          _isLoading = false;
          _hasError = false;
        });
      }
    }
  }


  Map<String, dynamic> _transformVideoData(Map<String, dynamic> rawVideo) {
    final performer = rawVideo['performer'] as Map<String, dynamic>?;

    // [OMEGA_PILL_QUERY] Read performance_type from VIDEO record, not performer profile
    final performanceType = rawVideo['performance_type'] ?? '';
    debugPrint('[OMEGA_PILL_DATA] Discovery context video_id=${rawVideo['id']} db.performance_type=$performanceType');

    return {
      'id': rawVideo['id'] ?? 'unknown',
      'title': rawVideo['title'] ?? 'Untitled Performance',
      'description': rawVideo['description'] ?? 'Street performance in NYC',
      'thumbnail': rawVideo['thumbnail_url'] ??
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=800&fit=crop',
      'videoUrl': rawVideo['video_url'] ?? '',
      'duration': rawVideo['duration'] ?? 0,
      'likeCount': rawVideo['like_count'] ?? 0,
      'commentCount': rawVideo['comment_count'] ?? 0,
      'shareCount': rawVideo['share_count'] ?? 0,
      'viewCount': rawVideo['view_count'] ?? 0,
      'isLiked': false,
      'performerUsername': performer?['username'] ?? '',
      'performerAvatar': performer?['profile_image_url'] ?? '',
      'performanceType': performanceType, // From video record, not performer
      'performance_type': performanceType, // Alias for compatibility
      'isVerified': performer?['is_verified'] ?? false,
      'location': rawVideo['location_name'] ?? rawVideo['borough'] ?? 'NYC',
      'caption': rawVideo['description'] ?? 'Street performance in NYC',
      'createdAt': rawVideo['created_at'] ?? DateTime.now().toIso8601String(),
      'thumbnailUrl': rawVideo['thumbnail_url'] ??
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=800&fit=crop',
      'likesCount': rawVideo['like_count'] ?? 0,
      'commentsCount': rawVideo['comment_count'] ?? 0,
      'sharesCount': rawVideo['share_count'] ?? 0,
      'performerId': performer?['id'] ?? 'performer-unknown',
    };
  }

  void _retryLoading() {
    _isInitialized = false;
    _initializeScreen();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 👇 Video content fills the background (full screen)
          Positioned.fill(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                    ? _buildErrorState()
                    : _videos.isEmpty
                        ? _buildEmptyState()
                        : RepaintBoundary(
                            child: PageView.builder(
                              controller: _pageController,
                              scrollDirection: Axis.vertical,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentVideoIndex = index;
                                });
                                _onVideoChanged(index);
                              },
                              itemCount: _videos.length,
                              itemBuilder: (context, index) {
                                if (index < 0 || index >= _videos.length) {
                                  return Container(
                                    color: AppTheme.backgroundDark,
                                    child: Center(
                                      child: Text(
                                        'Loading...',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: AppTheme.textPrimary,
                                            ),
                                      ),
                                    ),
                                  );
                                }

                                return VideoPlayerWidget(
                                  videoData: _videos[index],
                                  onLike: () => _onLike(index),
                                  onComment: _onComment,
                                  onShare: _onShare,
                                  onDonate: () =>
                                      _onDonate(_videos[index]['id']),
                                  onProfileTap: () => _onProfileTap(
                                      _videos[index]['performerId'] ?? ''),
                                );
                              },
                            ),
                          ),
          ),

          // 👇 Top navigation overlay (Following | Discovery)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FeedNavigationHeaderWidget(
              currentFeed: 'discovery',
              showSearch: true,
            ),
          ),

          // 👇 Bottom navigation overlay
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FeedNavigationBottomWidget(
                currentFeed: 'discovery',
                showSearch: true,
              ),
            ),
          ),

          // Loading indicator for pagination
          if (_isLoadingMore)
            Positioned(
              bottom: 12.h,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundDark
                        .withAlpha((0.8 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: 100.w,
      height: 100.h,
      color: AppTheme.backgroundDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.primaryOrange,
              strokeWidth: 3,
            ),
            SizedBox(height: 3.h),
            Text(
              'Loading amazing performances...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Discovering the best street talent in NYC',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: 100.w,
      height: 100.h,
      color: AppTheme.backgroundDark,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 16.w,
                color: AppTheme.accentRed,
              ),
              SizedBox(height: 3.h),
              Text(
                'Unable to Load Videos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'Check your connection and try again',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              ElevatedButton.icon(
                onPressed: _retryLoading,
                icon: Icon(Icons.refresh, size: 5.w),
                label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: AppTheme.backgroundDark,
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: 100.w,
      height: 100.h,
      color: AppTheme.backgroundDark,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 20.w,
                color: AppTheme.textSecondary,
              ),
              SizedBox(height: 3.h),
              Text(
                'No Videos Available',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              Text(
                'Check back later for new amazing street performances from NYC artists',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              ElevatedButton.icon(
                onPressed: _retryLoading,
                icon: Icon(Icons.refresh, size: 5.w),
                label: Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: AppTheme.backgroundDark,
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !mounted) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      List<Map<String, dynamic>> newVideos = [];
      try {
        newVideos = await _videoService
            .getDiscoveryFeed(limit: 10, offset: _videos.length)
            .timeout(Duration(seconds: 10));
      } catch (e) {
        debugPrint('Load more videos error: $e');
      }

      if (mounted && newVideos.isNotEmpty) {
        setState(() {
          _videos.addAll(
              newVideos.map((video) => _transformVideoData(video)).toList());
        });
      }
    } catch (e) {
      debugPrint('Error loading more videos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onVideoChanged(int index) {
    if (!mounted || index < 0 || index >= _videos.length) return;

    // Record video view with error handling
    try {
      _videoService.recordVideoView(_videos[index]['id']).catchError((error) {
        debugPrint('Record view error: $error');
      });
    } catch (e) {
      debugPrint('Record view error: $e');
    }

    // Load more videos when approaching end
    if (index >= _videos.length - 3 && !_isLoadingMore) {
      _loadMoreVideos();
    }

    // Mark video as loaded for performance tracking
    _loadedVideoIndices.add(index);
  }

  void _onVideoLike(String videoId) async {
    if (!mounted || videoId.isEmpty) return;

    try {
      final videoIndex = _videos.indexWhere((v) => v['id'] == videoId);
      if (videoIndex != -1 && mounted) {
        setState(() {
          final currentVideo = _videos[videoIndex];
          final isCurrentlyLiked = currentVideo['isLiked'] ?? false;
          final currentLikes = currentVideo['likeCount'] ?? 0;

          _videos[videoIndex]['isLiked'] = !isCurrentlyLiked;
          _videos[videoIndex]['likeCount'] =
              isCurrentlyLiked ? currentLikes - 1 : currentLikes + 1;
          _videos[videoIndex]['likesCount'] = _videos[videoIndex]['likeCount'];
        });
      }

      await _videoService.toggleVideoLike(videoId);
    } catch (e) {
      debugPrint('Error liking video: $e');

      // Revert optimistic update
      final videoIndex = _videos.indexWhere((v) => v['id'] == videoId);
      if (videoIndex != -1 && mounted) {
        setState(() {
          final currentVideo = _videos[videoIndex];
          final isCurrentlyLiked = currentVideo['isLiked'] ?? false;
          final currentLikes = currentVideo['likeCount'] ?? 0;

          _videos[videoIndex]['isLiked'] = !isCurrentlyLiked;
          _videos[videoIndex]['likeCount'] =
              isCurrentlyLiked ? currentLikes - 1 : currentLikes + 1;
          _videos[videoIndex]['likesCount'] = _videos[videoIndex]['likeCount'];
        });
      }
    }
  }

  void _onVideoComment(String videoId) {
    if (!mounted || videoId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 70.h,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 16.w,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Comments Coming Soon!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Join the conversation when comments are available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onVideoShare(String videoId) {
    if (!mounted || videoId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 3.h),
              decoration: BoxDecoration(
                color: AppTheme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.share_outlined,
                  color: AppTheme.primaryOrange,
                  size: 8.w,
                ),
                SizedBox(width: 3.w),
                Text(
                  'Share Feature Coming Soon!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              'Share amazing performances with your friends',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 3.h),
          ],
        ),
      ),
    );
  }

  void _onProfileTap(String performerId) {
    if (!mounted || performerId.isEmpty) return;

    // Find the video data to get performer handle
    final video = _videos.firstWhere(
      (v) => v['performerId'] == performerId,
      orElse: () => <String, dynamic>{},
    );
    
    final performerHandle = video['performerUsername'] ?? '';
    
    debugPrint('[NAV_FEED] Navigating to profile of performer=$performerHandle id=$performerId');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PerformerProfile(
          performerId: performerId,
          performerHandle: performerHandle,
        ),
      ),
    ).catchError((error) {
      debugPrint('Navigation error: $error');
    });
  }

  void _onDonate(String videoId) {
    if (!mounted || videoId.isEmpty) return;

    final video = _videos.firstWhere((v) => v['id'] == videoId,
        orElse: () => <String, dynamic>{});

    if (video.isEmpty) return;

    final performerId = video['performerId'] ?? '';

    if (performerId.isNotEmpty) {
      Navigator.pushNamed(
        context,
        AppRoutes.donationFlow,
        arguments: {
          'performerId': performerId,
          'videoId': videoId,
        },
      ).catchError((error) {
        debugPrint('Donation navigation error: $error');
      });
    }
  }

  void _onLike(int videoIndex) {
    if (videoIndex < 0 || videoIndex >= _videos.length) return;
    final videoId = _videos[videoIndex]['id'];
    _onVideoLike(videoId);
  }

  void _onComment() {
    if (_currentVideoIndex < 0 || _currentVideoIndex >= _videos.length) return;
    final videoId = _videos[_currentVideoIndex]['id'];
    _onVideoComment(videoId);
  }

  void _onShare() {
    if (_currentVideoIndex < 0 || _currentVideoIndex >= _videos.length) return;
    final videoId = _videos[_currentVideoIndex]['id'];
    _onVideoShare(videoId);
  }
}
