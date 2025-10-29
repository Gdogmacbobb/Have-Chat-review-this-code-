import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';
import 'dart:html' as html;

import '../../core/app_export.dart';
import '../shared/unified_video_player.dart';
import '../shared/diagnostic_overlay.dart';
import '../shared/video_overlay_info.dart';
import '../../services/supabase_service.dart';

class PerformerProfileVideoPlayer extends StatefulWidget {
  const PerformerProfileVideoPlayer({super.key});

  @override
  State<PerformerProfileVideoPlayer> createState() => _PerformerProfileVideoPlayerState();
}

class _PerformerProfileVideoPlayerState extends State<PerformerProfileVideoPlayer> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLiked = false;
  bool _isVisible = true;
  final ValueNotifier<double> _scrubberBottomOffset = ValueNotifier<double>(120.0);
  bool _showDiagnostics = false;
  Timer? _longPressTimer;
  
  Map<String, dynamic>? videoData;
  
  // Player state tracking
  bool? _isPlaying;
  Duration? _playerPosition;
  Duration? _playerDuration;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && mounted) {
        setState(() {
          videoData = args;
          _isLiked = (videoData?['isLiked'] as bool?) ?? false;
        });
        _logVideoData();
      }
    });
  }
  
  void _logVideoData() {
    if (videoData == null) {
      html.window.console.error('[VD_ERR] videoData is null!');
      return;
    }
    
    // First, print ALL fields to see what we're getting - use both print and console.log
    html.window.console.log('[VD_DEBUG] === PERFORMER PROFILE VIDEO DATA ===');
    html.window.console.log('[VD_DEBUG] All keys: ${videoData!.keys.toList()}');
    html.window.console.log('[VD_DEBUG] performerUsername: ${videoData?['performerUsername']}');
    html.window.console.log('[VD_DEBUG] performer_handle: ${videoData?['performer_handle']}');
    html.window.console.log('[VD_DEBUG] posterHandle: ${videoData?['posterHandle']}');
    html.window.console.log('[VD_DEBUG] performerAvatar: ${videoData?['performerAvatar']}');
    html.window.console.log('[VD_DEBUG] poster_profile_photo_url: ${videoData?['poster_profile_photo_url']}');
    html.window.console.log('[VD_DEBUG] location: ${videoData?['location']}');
    html.window.console.log('[VD_DEBUG] location_name: ${videoData?['location_name']}');
    html.window.console.log('[VD_DEBUG] description: ${videoData?['description']}');
    html.window.console.log('[VD_DEBUG] caption: ${videoData?['caption']}');
    html.window.console.log('[VD_DEBUG] ================================');
    
    final videoId = videoData?['id']?.toString() ?? 'unknown';
    final handle = videoData?['performerUsername'] ?? videoData?['performer_handle'] ?? '';
    final avatar = videoData?['performerAvatar'] ?? videoData?['poster_profile_photo_url'] ?? '';
    final caption = videoData?['description'] ?? videoData?['caption'] ?? '';
    final location = videoData?['location'] ?? '';
    
    // Check for missing critical fields
    final missingFields = <String>[];
    if (handle.isEmpty) missingFields.add('handle');
    if (avatar.isEmpty) missingFields.add('avatar');
    if (caption.isEmpty) missingFields.add('caption');
    if (location.isEmpty) missingFields.add('location');
    
    if (missingFields.isNotEmpty) {
      html.window.console.error('[VD_ERR] missing_field=${missingFields.join(',')} video_id=$videoId');
    }
    
    // Check for placeholder handle
    if (_isPlaceholderHandle(handle)) {
      html.window.console.error('[VD_ERR] placeholder_handle handle=$handle video_id=$videoId');
    }
    
    // Log successful data load
    if (missingFields.isEmpty && !_isPlaceholderHandle(handle)) {
      html.window.console.log('[VD_LIVE] handle=$handle, avatar=${avatar.isNotEmpty ? 'present' : 'missing'}, caption=${caption.isNotEmpty ? 'present' : 'missing'}, location=${location.isNotEmpty ? 'present' : 'missing'}');
    }
  }
  
  bool _isPlaceholderHandle(String handle) {
    final lower = handle.toLowerCase();
    return lower.contains('@performer') || 
           lower.contains('@user') || 
           lower.contains('@unknown') ||
           lower == 'performer' ||
           lower == 'user' ||
           lower == 'unknown';
  }

  @override
  void dispose() {
    _scrubberBottomOffset.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    HapticFeedback.lightImpact();
  }

  void _handleComment() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Comments coming soon!'),
        backgroundColor: AppTheme.surfaceDark,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleShare() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share link copied to clipboard'),
        backgroundColor: AppTheme.surfaceDark,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleDonate() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Donation flow coming soon!'),
        backgroundColor: AppTheme.primaryOrange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleProfileTap() {
    HapticFeedback.lightImpact();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _getPerformerAvatar() {
    final avatarUrl = videoData?['performerAvatar'] ?? 
                     videoData?['poster_profile_photo_url'] ?? '';
    if (avatarUrl.isEmpty) {
      // Return empty string to trigger error builder which shows default icon
      return '';
    }
    return avatarUrl;
  }

  String _formatPerformanceType(String type) {
    switch (type.toLowerCase()) {
      case 'singer':
        return '🎤 Singer';
      case 'dancer':
        return '💃 Dancer';
      case 'magician':
        return '🎩 Magician';
      case 'musician':
        return '🎵 Musician';
      case 'artist':
        return '🎨 Artist';
      default:
        return '🎭 Performer';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (videoData == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryOrange,
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const headerTopOffset = 40.0;
    const actionButtonsTopPercent = 0.18;
    const donationButtonSize = 48.0;
    const donationButtonClearance = 70.0;

    final videoUrl = videoData?['videoUrl'] ?? videoData?['video_url'] ?? '';
    final thumbnailUrl = videoData?['thumbnailUrl'] ?? videoData?['thumbnail'] ?? '';
    final performerHandle = videoData?['performerUsername'] ?? videoData?['performer_handle'] ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        width: screenWidth,
        height: screenHeight,
        color: AppTheme.backgroundDark,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Unified Video Player (full screen background with scrubber)
              Positioned.fill(
                child: VisibilityDetector(
                  key: Key('profile_video_${videoData?['id']}'),
                  onVisibilityChanged: (info) {
                    final isVisible = info.visibleFraction > 0.6;
                    if (isVisible != _isVisible && mounted) {
                      setState(() {
                        _isVisible = isVisible;
                      });
                    }
                  },
                  child: UnifiedVideoPlayer(
                    key: ValueKey(videoData?['id']),
                    videoUrl: videoUrl,
                    thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : null,
                    autoplay: true,
                    muted: false,
                    loop: true,
                    showScrubber: true,
                    postId: videoData?['id']?.toString() ?? 'unknown',
                    isVisible: _isVisible,
                    scrubberBottomPosition: 0, // Flush to bottom edge for full-screen profile videos
                    onScrubberMeasured: (bottomOffset) {
                      if (mounted) {
                        _scrubberBottomOffset.value = bottomOffset;
                      }
                    },
                    onPlayerStateChanged: (isPlaying, position, duration) {
                      if (mounted) {
                        setState(() {
                          _isPlaying = isPlaying;
                          _playerPosition = position;
                          _playerDuration = duration;
                        });
                      }
                    },
                  ),
                ),
              ),

              // Gradient overlay for better text visibility (pointer-transparent)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.backgroundDark.withAlpha((0.3 * 255).round()),
                          AppTheme.backgroundDark.withAlpha((0.7 * 255).round()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Top Overlay - Back Button and Handle (Top-Left aligned) with Long-Press Detector (1.5 seconds)
              Positioned(
                top: topInset + 8,
                left: 12,
                child: GestureDetector(
                  onTapDown: (details) {
                    _longPressTimer = Timer(Duration(milliseconds: 1500), () {
                      if (mounted) {
                        setState(() {
                          _showDiagnostics = !_showDiagnostics;
                        });
                      }
                    });
                  },
                  onTapUp: (details) {
                    _longPressTimer?.cancel();
                  },
                  onTapCancel: () {
                    _longPressTimer?.cancel();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      // Handle text (only show if data exists and not a placeholder)
                      if (performerHandle.isNotEmpty && !_isPlaceholderHandle(performerHandle))
                        Text(
                          '@$performerHandle',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Dynamic Right Side Action Buttons (Matching Discovery Feed)
              ValueListenableBuilder<double>(
                valueListenable: _scrubberBottomOffset,
                builder: (context, scrubberOffset, child) {
                  final safeAreaHeight = screenHeight - topInset - bottomInset;
                  final actionColumnTop = safeAreaHeight * actionButtonsTopPercent;
                  final donationButtonBottom = scrubberOffset + donationButtonClearance;
                  final donationButtonTop = donationButtonBottom + donationButtonSize;
                  final columnGap = 20.0;
                  final actionColumnHeight = (safeAreaHeight - actionColumnTop - donationButtonTop - columnGap).clamp(0.0, double.infinity);

                  // Log layout positions
                  debugPrint('[VD_LAYOUT] headerTop=${headerTopOffset.toStringAsFixed(0)}px railY=${actionColumnTop.toStringAsFixed(0)}px donateY=${donationButtonBottom.toStringAsFixed(0)}px scrubberY=${scrubberOffset.toStringAsFixed(0)}px');

                  return Positioned(
                    right: 12,
                    top: actionColumnTop,
                    height: actionColumnHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Profile Avatar
                        GestureDetector(
                          onTap: _handleProfileTap,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryOrange,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                _getPerformerAvatar(),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 48,
                                    height: 48,
                                    color: AppTheme.surfaceDark,
                                    child: Icon(
                                      Icons.person,
                                      color: AppTheme.textSecondary,
                                      size: 24,
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 48,
                                    height: 48,
                                    color: AppTheme.surfaceDark,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primaryOrange,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // Like Button
                        GestureDetector(
                          onTap: _toggleLike,
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _isLiked ? AppTheme.accentRed : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: _isLiked ? AppTheme.textPrimary : AppTheme.textPrimary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCount(videoData?['likesCount'] ?? videoData?['likeCount'] ?? 0),
                                style: AppTheme.videoOverlayStyle(),
                              ),
                            ],
                          ),
                        ),

                        // Comment Button
                        GestureDetector(
                          onTap: _handleComment,
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppTheme.textPrimary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCount(videoData?['commentsCount'] ?? videoData?['commentCount'] ?? 0),
                                style: AppTheme.videoOverlayStyle(),
                              ),
                            ],
                          ),
                        ),

                        // Share Button
                        GestureDetector(
                          onTap: _handleShare,
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.share,
                                  color: AppTheme.textPrimary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCount(videoData?['sharesCount'] ?? videoData?['shareCount'] ?? 0),
                                style: AppTheme.videoOverlayStyle(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Donation Button (positioned separately with scrubber awareness)
              ValueListenableBuilder<double>(
                valueListenable: _scrubberBottomOffset,
                builder: (context, scrubberOffset, child) {
                  final donationButtonBottom = scrubberOffset + 70;
                  
                  return Positioned(
                    right: 12,
                    bottom: donationButtonBottom,
                    child: GestureDetector(
                      onTap: _handleDonate,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.attach_money,
                          color: AppTheme.backgroundDark,
                          size: 28,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Bottom Overlay - Performer Info (Using Shared VideoOverlayInfo Widget)
              ValueListenableBuilder<double>(
                valueListenable: _scrubberBottomOffset,
                builder: (context, scrubberOffset, child) {
                  final captionBottomOffset = scrubberOffset + 90;
                  
                  return Positioned(
                    bottom: captionBottomOffset,
                    left: 16,
                    right: 80,
                    child: VideoOverlayInfo(
                      videoData: videoData ?? {},
                      onProfileTap: _handleProfileTap,
                    ),
                  );
                },
              ),

              // Diagnostic Overlay
              if (videoData != null)
                DiagnosticOverlay(
                  videoData: videoData!,
                  isVisible: _showDiagnostics,
                  isPlaying: _isPlaying,
                  position: _playerPosition,
                  duration: _playerDuration,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
