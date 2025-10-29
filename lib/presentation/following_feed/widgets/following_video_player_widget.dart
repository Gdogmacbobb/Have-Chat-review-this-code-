import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/app_export.dart';
import '../../shared/unified_video_player.dart';
import '../../shared/video_overlay_info.dart';

class FollowingVideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDonate;
  final VoidCallback? onProfileTap;

  const FollowingVideoPlayerWidget({
    Key? key,
    required this.videoData,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onDonate,
    this.onProfileTap,
  }) : super(key: key);

  @override
  State<FollowingVideoPlayerWidget> createState() =>
      _FollowingVideoPlayerWidgetState();
}

class _FollowingVideoPlayerWidgetState
    extends State<FollowingVideoPlayerWidget> {
  bool _isLiked = false;
  bool _isVisible = false; // Track if video is visible in viewport
  final ValueNotifier<double> _scrubberBottomOffset = ValueNotifier<double>(120.0); // Safe fallback: 80px bottom + 40px height

  @override
  void initState() {
    super.initState();
    _isLiked = widget.videoData['isLiked'] ?? false;
  }

  @override
  void dispose() {
    _scrubberBottomOffset.dispose();
    super.dispose();
  }
  
  void _onVisibilityChanged(VisibilityInfo info) {
    // Consider video visible if >60% is in viewport
    final isVisible = info.visibleFraction > 0.6;
    if (isVisible != _isVisible) {
      setState(() {
        _isVisible = isVisible;
      });
      if (kDebugMode) {
        print('[VISIBILITY_DETECTOR] id=${widget.videoData['id']} fraction=${info.visibleFraction.toStringAsFixed(2)} visible=$isVisible');
      }
    }
  }

  @override
  void didUpdateWidget(FollowingVideoPlayerWidget oldWidget) {
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
    final avatarUrl = widget.videoData['performerAvatar'] ?? '';

    if (avatarUrl.isEmpty) {
      return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face';
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

    if (kDebugMode) {
      print('[FEED_BUILD] id=${widget.videoData['id']} videoUrl=$videoUrl');
    }

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
                    if (kDebugMode) {
                      print('[SCRUBBER_DYNAMIC] Updated offset to ${bottomOffset.toStringAsFixed(0)}px');
                    }
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

          // Top Overlay - Following Indicator
          Positioned(
            top: headerTopOffset,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withAlpha((0.5 * 255).round()),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Following',
                    style: AppTheme.darkTheme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dynamic Right Side Action Buttons
          ValueListenableBuilder<double>(
            valueListenable: _scrubberBottomOffset,
            builder: (context, scrubberOffset, child) {
              // Calculate explicit positions accounting for SafeArea
              final safeAreaHeight = screenHeight - topInset - bottomInset;
              final actionColumnTop = safeAreaHeight * actionButtonsTopPercent;
              final donationButtonBottom = scrubberOffset + donationButtonClearance;
              final donationButtonTop = donationButtonBottom + donationButtonSize;
              final columnGap = 20.0; // Gap between column bottom and donation button top
              final actionColumnHeight = (safeAreaHeight - actionColumnTop - donationButtonTop - columnGap).clamp(0.0, double.infinity);
              
              if (kDebugMode) {
                print('[DYNAMIC_LAYOUT] safeH=$safeAreaHeight top=$actionColumnTop height=$actionColumnHeight donateBottom=$donationButtonBottom gap=$columnGap');
              }
              
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
              );
            },
          ),

          // Donate Button (floating $ button, dynamically positioned above scrubber)
          ValueListenableBuilder<double>(
            valueListenable: _scrubberBottomOffset,
            builder: (context, scrubberOffset, child) {
              final donationButtonBottom = scrubberOffset + 70; // Scrubber offset + 70px buffer for full clearance
              if (kDebugMode) {
                print('[DONATION_BTN] Positioned at bottom=${donationButtonBottom.toStringAsFixed(0)}px (scrubberOffset=$scrubberOffset)');
              }
              
              return Positioned(
                right: 12,
                bottom: donationButtonBottom,
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
              );
            },
          ),

          // Bottom Overlay - Performer Info (Using Shared VideoOverlayInfo Widget)
          ValueListenableBuilder<double>(
            valueListenable: _scrubberBottomOffset,
            builder: (context, scrubberOffset, child) {
              final captionBottomOffset = scrubberOffset + 90; // Scrubber offset + 90px buffer
              
              return Positioned(
                bottom: captionBottomOffset,
                left: 16,
                right: 80,
                child: VideoOverlayInfo(
                  videoData: widget.videoData,
                  onProfileTap: widget.onProfileTap,
                ),
              );
            },
          ),
        ],
      ),
        ),
    );
  }
}
