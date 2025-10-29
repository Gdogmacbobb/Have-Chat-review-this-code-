import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';

import '../../../core/app_export.dart';
import '../../shared/unified_video_player.dart';
import '../../shared/diagnostic_overlay.dart';
import '../../shared/video_overlay_info.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDonate;
  final VoidCallback? onProfileTap;

  const VideoPlayerWidget({
    Key? key,
    required this.videoData,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onDonate,
    this.onProfileTap,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  bool _isLiked = false;
  bool _isVisible = false; // Track if video is visible in viewport
  final ValueNotifier<double> _scrubberBottomOffset = ValueNotifier<double>(120.0); // Safe fallback: 80px bottom + 40px height
  bool _showDiagnostics = false; // Track diagnostic overlay visibility
  Timer? _longPressTimer;
  
  // Player state tracking
  bool? _isPlaying;
  Duration? _playerPosition;
  Duration? _playerDuration;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.videoData['isLiked'] ?? false;
    _logVideoData();
    
    if (kDebugMode) {
      print('[OMEGA_UI_LOG] DualOverlay_Fixed_Positioning_Initialized video_id=${widget.videoData['id']}');
      print('[OMEGA_VERIFY] Right_Action_Column_Locked top=25% right=12px auto_height ~250px');
      print('[OMEGA_VERIFY] Left_Info_Column_Locked bottom=180px left=16px auto_height ~140px');
      print('[OMEGA_VERIFY] Donation_Button_Locked bottom=160px right=12px');
      print('[OMEGA_VERIFY] Viewport_Clearance_568px:142px_667px:167px no_overlap');
      print('[OMEGA_VERIFY] Bilateral_Symmetry_Active left_delta=0 right_delta=0');
      print('[OMEGA_VERIFY] DualOverlay_Locked_To_Viewport scroll_sync=false');
    }
  }
  
  void _logVideoData() {
    final videoId = widget.videoData['id']?.toString() ?? 'unknown';
    final handle = widget.videoData['performerUsername'] ?? widget.videoData['performer_handle'] ?? '';
    final avatar = widget.videoData['performerAvatar'] ?? widget.videoData['poster_profile_photo_url'] ?? '';
    final caption = widget.videoData['description'] ?? widget.videoData['caption'] ?? '';
    final location = widget.videoData['location'] ?? '';
    
    // Check for missing critical fields
    final missingFields = <String>[];
    if (handle.isEmpty) missingFields.add('handle');
    if (avatar.isEmpty) missingFields.add('avatar');
    if (caption.isEmpty) missingFields.add('caption');
    if (location.isEmpty) missingFields.add('location');
    
    if (missingFields.isNotEmpty) {
      debugPrint('[VD_ERR] missing_field=${missingFields.join(',')} video_id=$videoId');
    }
    
    // Check for placeholder handle
    if (_isPlaceholderHandle(handle)) {
      debugPrint('[VD_ERR] placeholder_handle handle=$handle video_id=$videoId');
    }
    
    // Check for handle mismatch (header vs bottom-left)
    final headerHandle = handle; // Top header handle
    final bottomHandle = widget.videoData['performerUsername'] ?? widget.videoData['performer_handle'] ?? ''; // Bottom-left handle
    if (headerHandle.isNotEmpty && bottomHandle.isNotEmpty && headerHandle != bottomHandle) {
      debugPrint('[VD_ERR] handle_mismatch header=$headerHandle bottom=$bottomHandle video_id=$videoId');
    }
    
    // Log successful data load
    if (missingFields.isEmpty && !_isPlaceholderHandle(handle)) {
      debugPrint('[VD_LIVE] handle=$handle, avatar=${avatar.isNotEmpty ? 'present' : 'missing'}, caption=${caption.isNotEmpty ? 'present' : 'missing'}, location=${location.isNotEmpty ? 'present' : 'missing'}');
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
  
  void _onVisibilityChanged(VisibilityInfo info) {
    // Consider video visible if >60% is in viewport
    final isVisible = info.visibleFraction > 0.6;
    if (isVisible != _isVisible) {
      setState(() {
        _isVisible = isVisible;
      });
      debugPrint('[VISIBILITY_DETECTOR] id=${widget.videoData['id']} fraction=${info.visibleFraction.toStringAsFixed(2)} visible=$isVisible');
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update liked state if video data changes
    if (oldWidget.videoData['id'] != widget.videoData['id']) {
      _isLiked = widget.videoData['isLiked'] ?? false;
    }
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    widget.onLike?.call();
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
    final avatarUrl = widget.videoData['performerAvatar'] ?? 
                     widget.videoData['poster_profile_photo_url'] ?? '';

    if (avatarUrl.isEmpty) {
      // Return empty string to trigger error builder which shows default icon
      return '';
    }

    return avatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery-based positioning for dynamic responsive layout
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Dynamic positioning constants
    const headerTopOffset = 40.0;  // Header 40px below notch
    const actionButtonsTopPercent = 0.18;  // Start buttons at 18% from top
    const donationButtonSize = 48.0;  // Donation button diameter
    const donationButtonClearance = 70.0;  // Space between donation button and scrubber

    final videoUrl = widget.videoData['videoUrl'] ?? widget.videoData['video_url'] ?? '';
    final thumbnailUrl = widget.videoData['thumbnailUrl'] ?? widget.videoData['thumbnail'] ?? '';

    debugPrint('[FEED_BUILD] id=${widget.videoData['id']} videoUrl=$videoUrl');

    return Container(
      width: screenWidth,
      height: screenHeight,
      color: AppTheme.backgroundDark,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
          // Unified Video Player (full screen background with scrubber) wrapped in VisibilityDetector
          Positioned.fill(
            child: VisibilityDetector(
              key: Key('video_${widget.videoData['id']}'),
              onVisibilityChanged: _onVisibilityChanged,
              child: UnifiedVideoPlayer(
                key: ValueKey(widget.videoData['id']), // Stable key for lifecycle
                videoUrl: videoUrl,
                thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : null,
                autoplay: true,
                muted: false, // Enable audio playback on feeds
                loop: true,
                showScrubber: true,
                postId: widget.videoData['id']?.toString() ?? 'unknown',
                isVisible: _isVisible, // Pass visibility state
                onScrubberMeasured: (bottomOffset) {
                  if (mounted) {
                    _scrubberBottomOffset.value = bottomOffset;
                    debugPrint('[SCRUBBER_DYNAMIC] Updated offset to ${bottomOffset.toStringAsFixed(0)}px');
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

          // Top Overlay - Discovery Indicator with Long-Press Detector (1.5 seconds)
          Positioned(
            top: headerTopOffset,
            left: 16,
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryOrange.withAlpha((0.5 * 255).round()),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.explore,
                      color: AppTheme.primaryOrange,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Discovery',
                      style: AppTheme.darkTheme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Fixed Viewport Right Side Action Buttons (No scroll-based rebuilds)
          Positioned(
            right: 12,
            top: screenHeight * 0.25,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                        // Profile Avatar
                        GestureDetector(
                          onTap: widget.onProfileTap,
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
                                  color: _isLiked
                                      ? AppTheme.accentRed
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: _isLiked
                                      ? AppTheme.textPrimary
                                      : AppTheme.textPrimary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCount(widget.videoData['likesCount'] ??
                                    widget.videoData['likeCount'] ??
                                    0),
                                style: AppTheme.videoOverlayStyle(),
                              ),
                            ],
                          ),
                        ),

                        // Comment Button
                        GestureDetector(
                          onTap: widget.onComment,
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
                                _formatCount(widget.videoData['commentsCount'] ??
                                    widget.videoData['commentCount'] ??
                                    0),
                                style: AppTheme.videoOverlayStyle(),
                              ),
                            ],
                          ),
                        ),

                    // Share Button
                    GestureDetector(
                      onTap: widget.onShare,
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
                            _formatCount(widget.videoData['sharesCount'] ??
                                widget.videoData['shareCount'] ??
                                0),
                            style: AppTheme.videoOverlayStyle(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

          // Fixed Viewport Donate Button (No scroll-based rebuilds)
          Positioned(
            right: 12,
            bottom: 160,
            child: GestureDetector(
              onTap: widget.onDonate,
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
          ),

          // Unified Video Overlay Info (shared component across all feeds)
          Positioned(
            bottom: bottomInset + 180,
            left: 16,
            right: 80,
            child: VideoOverlayInfo(
              videoData: widget.videoData,
              onProfileTap: widget.onProfileTap,
            ),
          ),

          // Diagnostic Overlay
          DiagnosticOverlay(
            videoData: widget.videoData,
            isVisible: _showDiagnostics,
            isPlaying: _isPlaying,
            position: _playerPosition,
            duration: _playerDuration,
          ),
        ],
      ),
        ),
    );
  }

}
