import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../services/video_service.dart';
import '../../services/feed_refresh_service.dart';
import '../../widgets/feed_navigation_bottom_widget.dart';
import '../../widgets/feed_navigation_header_widget.dart';
import './widgets/following_context_menu_widget.dart';
import './widgets/following_empty_state_widget.dart';
import './widgets/following_video_player_widget.dart';
import '../performer_profile/performer_profile.dart';

class FollowingFeed extends StatefulWidget {
  const FollowingFeed({Key? key}) : super(key: key);

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<FollowingFeed>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final VideoService _videoService = VideoService();
  final SupabaseService _supabaseService = SupabaseService();

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _currentVideoIndex = 0;
  String? _currentUserRole;
  bool _isLoadingMore = false;
  bool _showContextMenu = false;
  int _unreadCount = 0;
  StreamSubscription<String>? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _refreshSubscription = FeedRefreshService().refreshStream.listen((feedName) {
      if (feedName == 'following') {
        _loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Get user role
      _currentUserRole = await _supabaseService.getUserRole();

      // Load following feed
      final videos = await _videoService.getFollowingFeed(limit: 20);

      if (mounted) {
        setState(() {
          _videos = videos.map((video) => _transformVideoData(video)).toList();
          _isLoading = false;
          _hasError = false;
          _unreadCount = 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading following feed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Map<String, dynamic> _transformVideoData(Map<String, dynamic> rawVideo) {
    final performer = rawVideo['performer'] as Map<String, dynamic>?;

    // [OMEGA_PILL_QUERY] Read performance_type from VIDEO record, not performer profile
    final performanceType = rawVideo['performance_type'] ?? '';
    debugPrint('[OMEGA_PILL_DATA] Following context video_id=${rawVideo['id']} db.performance_type=$performanceType');

    return {
      'id': rawVideo['id'],
      'title': rawVideo['title'] ?? 'Untitled Performance',
      'description': rawVideo['description'] ?? '',
      'thumbnail': rawVideo['thumbnail_url'] ?? '',
      'videoUrl': rawVideo['video_url'] ?? '',
      'duration': rawVideo['duration'] ?? 0,
      'likeCount': rawVideo['like_count'] ?? 0,
      'commentCount': rawVideo['comment_count'] ?? 0,
      'shareCount': rawVideo['share_count'] ?? 0,
      'viewCount': rawVideo['view_count'] ?? 0,
      'isLiked': false, // Will be updated based on user interactions
      'performerUsername': performer?['username'] ?? 'performer',
      'performerAvatar': performer?['profile_image_url'] ?? '',
      'performanceType': performanceType, // From video record, not performer
      'performance_type': performanceType, // Alias for compatibility
      'isVerified': performer?['is_verified'] ?? false,
      'location': rawVideo['location_name'] ?? rawVideo['borough'] ?? 'NYC',
      'caption': rawVideo['description'] ?? '',
      'createdAt': rawVideo['created_at'],
      'thumbnailUrl': rawVideo['thumbnail_url'] ?? '',
      'likesCount': rawVideo['like_count'] ?? 0,
      'commentsCount': rawVideo['comment_count'] ?? 0,
      'sharesCount': rawVideo['share_count'] ?? 0,
      'performerId': performer?['id'] ?? '', // Add performer ID for navigation
      'isFollowing': true, // Following feed specific
      'timestamp': _formatTimestamp(rawVideo['created_at']),
    };
  }

  String _formatTimestamp(String? createdAt) {
    if (createdAt == null) return 'Just now';

    final dateTime = DateTime.tryParse(createdAt);
    if (dateTime == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final newVideos = await _videoService.getFollowingFeed(
          limit: 10, offset: _videos.length);

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

  Future<void> _refreshFeed() async {
    HapticFeedback.mediumImpact();
    await _loadInitialData();
    HapticFeedback.lightImpact();
  }

  void _onVideoChanged(int index) {
    setState(() {
      _currentVideoIndex = index;
    });

    // Record video view
    if (index < _videos.length) {
      _videoService.recordVideoView(_videos[index]['id']);
    }

    // Load more videos when approaching end
    if (index >= _videos.length - 3 && !_isLoadingMore) {
      _loadMoreVideos();
    }
  }

  void _onVideoLike(String videoId) async {
    try {
      await _videoService.toggleVideoLike(videoId);

      // Update local state
      final videoIndex = _videos.indexWhere((v) => v['id'] == videoId);
      if (videoIndex != -1) {
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
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error liking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to like video. Please try again.'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _onVideoComment(String videoId) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
            height: 70.h,
            decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: AppTheme.borderSubtle,
                      borderRadius: BorderRadius.circular(2))),
              Expanded(
                  child: Center(
                      child: Text('Comments feature coming soon!',
                          style: Theme.of(context).textTheme.bodyLarge))),
            ])));
  }

  void _onVideoShare(String videoId) {
    HapticFeedback.selectionClick();
    debugPrint('Sharing video: $videoId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share feature coming soon!'),
        backgroundColor: AppTheme.primaryOrange,
      ),
    );
  }

  void _onProfileTap(String performerId) {
    if (performerId.isEmpty) return;

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
    final video = _videos.firstWhere((v) => v['id'] == videoId);
    final performerId = video['performerId'] ?? '';

    if (performerId.isNotEmpty) {
      Navigator.pushNamed(
        context,
        AppRoutes.donationFlow,
        arguments: {
          'performerId': performerId,
          'videoId': videoId,
        },
      );
    }
  }

  void _onLike(int videoIndex) {
    final videoId = _videos[videoIndex]['id'];
    _onVideoLike(videoId);
  }

  void _onComment() {
    final videoId = _videos[_currentVideoIndex]['id'];
    _onVideoComment(videoId);
  }

  void _onShare() {
    final videoId = _videos[_currentVideoIndex]['id'];
    _onVideoShare(videoId);
  }

  void _showContextMenuAction() {
    setState(() {
      _showContextMenu = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _hideContextMenu() {
    setState(() {
      _showContextMenu = false;
    });
  }

  void _onUnfollow() {
    setState(() {
      _videos.removeAt(_currentVideoIndex);
      if (_currentVideoIndex >= _videos.length && _videos.isNotEmpty) {
        _currentVideoIndex = _videos.length - 1;
        _pageController.animateToPage(
          _currentVideoIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
    HapticFeedback.mediumImpact();
  }

  void _onSave() {
    HapticFeedback.lightImpact();
  }

  void _onReport() {
    HapticFeedback.mediumImpact();
  }

  void _navigateToDiscovery() {
    Navigator.pushReplacementNamed(context, AppRoutes.discoveryFeed);
  }

  @override
  Widget build(BuildContext context) {
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
                          ? FollowingEmptyStateWidget(
                              onDiscoverTap: _navigateToDiscovery,
                            )
                          : RefreshIndicator(
                              onRefresh: _refreshFeed,
                              color: AppTheme.primaryOrange,
                              backgroundColor: AppTheme.surfaceDark,
                              child: RepaintBoundary(
                                child: PageView.builder(
                                  controller: _pageController,
                                  scrollDirection: Axis.vertical,
                                  onPageChanged: _onVideoChanged,
                                  itemCount: _videos.length,
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onLongPress: _showContextMenuAction,
                                      child: FollowingVideoPlayerWidget(
                                        videoData: _videos[index],
                                        onLike: () => _onLike(index),
                                        onComment: _onComment,
                                        onShare: _onShare,
                                        onDonate: () =>
                                            _onDonate(_videos[index]['id']),
                                        onProfileTap: () => _onProfileTap(
                                            _videos[index]['performerId'] ??
                                                ''),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
            ),

            // 👇 Top navigation overlay (Following | Discovery)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FeedNavigationHeaderWidget(
                currentFeed: 'following',
                showSearch: false,
                unreadCount: _unreadCount,
                onRefresh: _refreshFeed,
              ),
            ),

            // 👇 Bottom navigation overlay
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FeedNavigationBottomWidget(
                  currentFeed: 'following',
                  showSearch: false,
                  unreadCount: _unreadCount,
                  onRefresh: _refreshFeed,
                ),
              ),
            ),

            // Loading indicator for pagination
            if (_isLoadingMore)
              Positioned(
                bottom: 10.h,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundDark.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryOrange,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),

            // Context Menu Overlay
            if (_showContextMenu)
              FollowingContextMenuWidget(
                onUnfollow: _onUnfollow,
                onSave: _onSave,
                onReport: _onReport,
                onShare: () => _onShare(),
                onClose: _hideContextMenu,
              ),
          ],
        ));
  }

  Widget _buildLoadingState() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: AppTheme.primaryOrange),
      SizedBox(height: 16),
      Text('Loading your following feed...',
          style: Theme.of(context).textTheme.bodyLarge),
    ]));
  }

  Widget _buildErrorState() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 48, color: AppTheme.accentRed),
      SizedBox(height: 16),
      Text('Unable to load following feed',
          style: Theme.of(context).textTheme.headlineSmall),
      SizedBox(height: 8),
      Text('Check your connection and try again',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.textSecondary)),
      SizedBox(height: 24),
      ElevatedButton(onPressed: _loadInitialData, child: Text('Retry')),
    ]));
  }
}
