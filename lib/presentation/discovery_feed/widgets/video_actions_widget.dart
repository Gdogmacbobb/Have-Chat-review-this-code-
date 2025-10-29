import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class VideoActionsWidget extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDonate;
  final VoidCallback? onPerformerTap;

  const VideoActionsWidget({
    Key? key,
    required this.videoData,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onDonate,
    this.onPerformerTap,
  }) : super(key: key);

  @override
  State<VideoActionsWidget> createState() => _VideoActionsWidgetState();
}

class _VideoActionsWidgetState extends State<VideoActionsWidget>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.videoData['isLiked'] ?? false;

    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _likeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(VideoActionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoData['isLiked'] != widget.videoData['isLiked']) {
      setState(() {
        _isLiked = widget.videoData['isLiked'] ?? false;
      });
    }
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });

    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
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

  String _getPerformerAvatarUrl() {
    final performer = widget.videoData['performer'] as Map<String, dynamic>?;
    return performer?['profileImageUrl'] ??
        widget.videoData['performerAvatar'] ??
        'https://cdn.pixabay.com/photo/2015/03/04/22/35/avatar-659652_640.png';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Performer avatar
        GestureDetector(
          onTap: widget.onPerformerTap,
          child: Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.textPrimary,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: CustomImageWidget(
                imageUrl: _getPerformerAvatarUrl(),
                width: 12.w,
                height: 12.w,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        SizedBox(height: 4.h),

        // Like button
        _buildActionButton(
          onTap: _handleLike,
          child: AnimatedBuilder(
            animation: _likeAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _likeAnimation.value,
                child: CustomIconWidget(
                  iconName: _isLiked ? 'favorite' : 'favorite_border',
                  color: _isLiked ? AppTheme.accentRed : AppTheme.textPrimary,
                  size: 7.w,
                ),
              );
            },
          ),
          count: widget.videoData['likeCount'] ?? 0,
        ),

        SizedBox(height: 3.h),

        // Comment button
        _buildActionButton(
          onTap: widget.onComment,
          child: CustomIconWidget(
            iconName: 'chat_bubble_outline',
            color: AppTheme.textPrimary,
            size: 7.w,
          ),
          count: widget.videoData['commentCount'] ?? 0,
        ),

        SizedBox(height: 3.h),

        // Share button
        _buildActionButton(
          onTap: widget.onShare,
          child: CustomIconWidget(
            iconName: 'arrow_outward',
            color: AppTheme.textPrimary,
            size: 7.w,
          ),
          count: widget.videoData['shareCount'] ?? 0,
        ),

        SizedBox(height: 4.h),

        // Donation button
        GestureDetector(
          onTap: widget.onDonate,
          child: Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CustomIconWidget(
              iconName: 'attach_money',
              color: AppTheme.backgroundDark,
              size: 6.w,
            ),
          ),
        ),

        SizedBox(height: 1.h),

        Text(
          'Tip',
          style: AppTheme.darkTheme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                color: AppTheme.backgroundDark.withOpacity(0.8),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onTap,
    required Widget child,
    required int count,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(child: child),
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          _formatCount(count),
          style: AppTheme.darkTheme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                color: AppTheme.videoOverlay,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
