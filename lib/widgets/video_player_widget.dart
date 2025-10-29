import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String? videoUrl;
  final String? thumbnailUrl;
  final bool isVisible;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.isVisible = false,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = true;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
    }
    
    if (widget.videoUrl != oldWidget.videoUrl) {
      _disposeController();
      if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
        _initializeVideo();
      }
    }
  }

  void _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        
        // Configure for TikTok-style playback
        _controller!.setVolume(0.0); // Muted by default
        _controller!.setLooping(true); // Loop videos
        
        if (widget.isVisible) {
          _controller!.play();
        }
      }
    } catch (e) {
      print('[VIDEO] Failed to initialize: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _hasError = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      // Fallback to thumbnail or placeholder
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.withOpacity(0.3),
              Colors.purple.withOpacity(0.5),
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: widget.thumbnailUrl != null
            ? Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => 
                    Center(child: Icon(Icons.play_circle_outline, size: 80, color: Colors.white)),
              )
            : Center(
                child: Icon(Icons.play_circle_outline, size: 80, color: Colors.white),
              ),
      );
    }

    if (!_isInitialized) {
      // Loading state
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.withOpacity(0.3),
              Colors.purple.withOpacity(0.5),
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
              ),
              SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // Toggle play/pause on tap
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
        // Show controls briefly
        setState(() {
          _showControls = true;
        });
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showControls = false;
            });
          }
        });
      },
      child: Stack(
        children: [
          // Full-bleed video with cover scaling
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          
          // Volume control overlay (top-right)
          if (_showControls)
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    _controller!.setVolume(_isMuted ? 0.0 : 1.0);
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          
          // Progress indicator (bottom, subtle)
          Positioned(
            bottom: 4,
            left: 16,
            right: 16,
            child: AnimatedBuilder(
              animation: _controller!,
              builder: (context, child) {
                final progress = _controller!.value.position.inMilliseconds / 
                    _controller!.value.duration.inMilliseconds;
                return Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.isFinite ? progress : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        color: Color(0xFFFF8C00),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Play/pause overlay (center, when paused)
          if (!_controller!.value.isPlaying)
            Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.6),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Color(0xFFFF8C00),
                  size: 48,
                ),
              ),
            ),
        ],
      ),
    );
  }
}