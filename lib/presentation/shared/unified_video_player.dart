import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:video_player/video_player.dart';
import 'dart:async';

// EMERGENCY HOTFIX: Disable interactive scrubber to fix crash
// Interactive scrubber enabled - type safety issues resolved
const bool kEnableInteractiveScrubber = true;

class UnifiedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoplay;
  final bool muted;
  final bool loop;
  final bool showScrubber;
  final String postId;
  final Function(double scrubberBottomOffset)? onScrubberMeasured;
  final bool isVisible; // Track if video is visible in viewport
  final Function(bool isPlaying, Duration position, Duration duration)? onPlayerStateChanged;
  final double scrubberBottomPosition; // Distance from bottom edge (0 = flush to bottom, 60 = above nav bar)

  const UnifiedVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoplay = true,
    this.muted = true,
    this.loop = true,
    this.showScrubber = true,
    required this.postId,
    this.onScrubberMeasured,
    this.isVisible = true, // Default to visible
    this.onPlayerStateChanged,
    this.scrubberBottomPosition = 60.0, // Default: 60px above bottom (above nav bar for feeds)
  }) : super(key: key);

  @override
  State<UnifiedVideoPlayer> createState() => _UnifiedVideoPlayerState();
}

class _UnifiedVideoPlayerState extends State<UnifiedVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  int _initCounter = 0; // Race-condition guard: track initialization requests
  Timer? _playbackHeartbeat;
  Timer? _scrubberTimer;
  Timer? _seekThrottle; // Throttle seek updates to prevent render thread flood
  double _currentPosition = 0.0;
  double _pendingSeekValue = 0.0; // Store pending seek position during throttle
  bool _isDraggingScrubber = false;
  bool _wasPlayingBeforeDrag = false; // Track playback state before scrubbing
  bool _audioUnlocked = false; // Track if user has unlocked audio via gesture
  bool _isLandscape = false; // Track if video is landscape and needs rotation
  bool _isMuted = true; // Current mute state (independent of widget.muted prop)
  Timer? _muteIconTimer; // Timer to hide mute icon after showing it
  final GlobalKey _scrubberKey = GlobalKey(); // Track scrubber for dynamic positioning
  bool _showControls = true; // Show/hide play/pause controls with auto-hide
  Timer? _controlsTimer; // Timer for auto-hiding controls
  double? _scrubberValue; // Track scrubber position independently during drag

  @override
  void initState() {
    super.initState();
    _isMuted = widget.muted; // Initialize mute state from prop
    WidgetsBinding.instance.addObserver(this); // Observe app lifecycle
    _initializeVideo();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller != null && _controller!.value.isInitialized) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        // App went to background or became inactive - pause video
        debugPrint('[LIFECYCLE] App paused/inactive - pausing video id=${widget.postId}');
        _controller!.pause();
        _playbackHeartbeat?.cancel();
        _scrubberTimer?.cancel();
      } else if (state == AppLifecycleState.resumed && widget.isVisible) {
        // App resumed and video is visible - resume playback
        debugPrint('[LIFECYCLE] App resumed - resuming video id=${widget.postId}');
        _controller!.play();
        _startPlaybackHeartbeat();
        if (widget.showScrubber) {
          _startScrubberTimer();
        }
        // Start auto-hide timer for controls
        _startControlsAutoHide();
      }
    }
  }

  @override
  void didUpdateWidget(UnifiedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If postId changes, reinitialize video
    if (oldWidget.postId != widget.postId) {
      debugPrint('[CONTROLLER_SUPERSEDED] old=${oldWidget.postId} new=${widget.postId}');
      _disposeController();
      _initializeVideo();
      return;
    }
    
    // Handle visibility changes
    if (oldWidget.isVisible != widget.isVisible) {
      debugPrint('[VISIBILITY] Changed from ${oldWidget.isVisible} to ${widget.isVisible} id=${widget.postId}');
      _handleVisibilityChange(widget.isVisible);
    }
  }
  
  void _handleVisibilityChange(bool isVisible) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    if (isVisible && widget.autoplay) {
      // Video became visible - play it
      debugPrint('[VISIBILITY] Video visible - playing id=${widget.postId}');
      _controller!.play();
      _startPlaybackHeartbeat();
      if (widget.showScrubber) {
        _startScrubberTimer();
      }
      // Start auto-hide timer for controls
      _startControlsAutoHide();
    } else if (!isVisible) {
      // Video became invisible - pause it
      debugPrint('[VISIBILITY] Video hidden - pausing id=${widget.postId}');
      _controller!.pause();
      _playbackHeartbeat?.cancel();
      _scrubberTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _playbackHeartbeat?.cancel();
    _scrubberTimer?.cancel();
    _seekThrottle?.cancel();
    _muteIconTimer?.cancel();
    _controlsTimer?.cancel();
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _hasError = false;
  }

  void _unlockAudio() {
    if (!_audioUnlocked && _controller != null && !_isMuted) {
      debugPrint('[AUDIO_UNLOCKED] User gesture unlocked audio id=${widget.postId}');
      _controller!.setVolume(1.0);
      setState(() {
        _audioUnlocked = true;
      });
    }
  }
  
  void _toggleMute() {
    if (_controller != null && _controller!.value.isInitialized) {
      final newMuteState = !_isMuted;
      final newVolume = newMuteState ? 0.0 : 1.0;
      
      _controller!.setVolume(newVolume);
      debugPrint('[FEED_AUDIO] Volume toggled to: $newVolume (muted=$newMuteState) id=${widget.postId}');
      
      setState(() {
        _isMuted = newMuteState;
        if (!newMuteState) {
          _audioUnlocked = true; // Mark audio as unlocked when unmuting
        }
      });
    }
  }
  
  void _startControlsAutoHide() {
    _controlsTimer?.cancel();
    
    // Auto-hide controls after 3 seconds if video is playing
    if (_controller != null && _controller!.value.isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller != null && _controller!.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }
  
  void _toggleControlsVisibility() {
    _controlsTimer?.cancel();
    
    setState(() {
      _showControls = !_showControls;
    });
    
    // Start auto-hide timer if controls are now visible and video is playing
    if (_showControls) {
      _startControlsAutoHide();
    }
  }

  String _normalizeVideoUrl(String url) {
    if (url.isEmpty) return url;
    
    // Fix malformed URLs missing /objects/ prefix
    if (url.startsWith('/uploads/')) {
      final normalized = '/objects$url';
      debugPrint('[VIDEO_URL_NORMALIZE] Fixed malformed URL: $url → $normalized');
      return normalized;
    }
    
    return url;
  }

  void _initializeVideo() async {
    final videoUrl = _normalizeVideoUrl(widget.videoUrl);
    
    debugPrint('[VIDEO_SOURCE_BOUND] url=$videoUrl id=${widget.postId}');
    debugPrint('[CONTROLLER_INIT] id=${widget.postId}');
    
    if (videoUrl.isEmpty) {
      debugPrint('[PLAYBACK_ERROR] err=Empty video URL id=${widget.postId}');
      setState(() {
        _hasError = true;
        _isInitialized = false;
      });
      return;
    }

    // Track this initialization request to prevent stale controller overwrites
    final requestId = ++_initCounter;
    
    // Create a local controller to avoid race conditions
    final newController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    
    try {
      await newController.initialize();
      
      // After await, check if widget is still mounted and this request is still current
      if (!mounted || requestId != _initCounter) {
        // Widget updated or unmounted during initialization - dispose this controller
        debugPrint('[CONTROLLER_SUPERSEDED] Request $requestId superseded by ${_initCounter}');
        newController.dispose();
        return;
      }
      
      final durMs = newController.value.duration.inMilliseconds;
      final videoSize = newController.value.size;
      final videoWidth = videoSize.width.toInt();
      final videoHeight = videoSize.height.toInt();
      final isLandscape = videoWidth > videoHeight;
      
      debugPrint('[VIDEO_INITIALIZED] durMs=$durMs w=$videoWidth h=$videoHeight orientation=${isLandscape ? "landscape" : "portrait"} id=${widget.postId}');
      debugPrint('[ORIENTATION_META] w=$videoWidth h=$videoHeight ratio=${(videoWidth / videoHeight).toStringAsFixed(2)} id=${widget.postId}');
      
      // GUARD: Validate duration BEFORE setState - reject videos with invalid/corrupted metadata
      // Check for zero, negative, or absurdly large values (likely corrupted)
      if (durMs <= 0 || durMs.abs() > 86400000) {  // Reject if durMs > 24 hours (corrupted)
        debugPrint('[VIDEO_DURATION_INVALID] durMs=$durMs - Video has corrupted metadata, cannot play id=${widget.postId}');
        newController.dispose();
        if (mounted && requestId == _initCounter) {
          setState(() {
            _hasError = true;
            _isInitialized = false;
          });
        }
        return;
      }
      
      if (isLandscape) {
        debugPrint('[ORIENTATION_ROTATE] Detected landscape video, will rotate 90° for portrait display id=${widget.postId}');
      }
      
      // This is still the current request - swap controllers
      setState(() {
        final oldController = _controller;
        _controller = newController;
        _isInitialized = true;
        _hasError = false;
        _isLandscape = isLandscape;
        oldController?.dispose();
      });
      
      // Get readyState for web logging
      if (kIsWeb) {
        // Would need actual HTML video element access for precise readyState
        debugPrint('[VIDEO_INITIALIZED] readyState=4 (assumed HAVE_ENOUGH_DATA)');
      }
      
      // Configure for TikTok-style playback - only if controller is still valid
      if (_controller != null && _controller == newController) {
        final initialVolume = widget.muted ? 0.0 : 1.0;
        _controller!.setVolume(initialVolume);
        _controller!.setLooping(widget.loop);
        
        debugPrint('[AUDIO_CONTEXT] volume=$initialVolume muted=${widget.muted} loop=${widget.loop} id=${widget.postId}');
        
        // Only autoplay if video is visible - prevents off-screen videos from playing
        if (widget.autoplay && widget.isVisible) {
          debugPrint('[AUTOPLAY_POLICY] visible=${widget.isVisible} muted=${widget.muted} id=${widget.postId}');
          _controller!.play();
          debugPrint('[PLAYBACK_START] t=0.0 id=${widget.postId}');

          
          // Start heartbeat logging for playback verification
          _startPlaybackHeartbeat();
          
          // Start scrubber update timer if scrubber is shown
          if (widget.showScrubber) {
            _startScrubberTimer();
          }
          
          // Start auto-hide timer for controls
          _startControlsAutoHide();
        } else if (!widget.isVisible) {
          // Video initialized while off-screen - keep it paused
          debugPrint('[AUTOPLAY_POLICY] visible=${widget.isVisible} - keeping paused id=${widget.postId}');
        }
        
        // Add listener for TIMEUPDATE events
        _controller!.addListener(_onVideoPositionUpdate);
      }
    } catch (e, stackTrace) {
      debugPrint('[PLAYBACK_ERROR] err=$e id=${widget.postId}');
      debugPrint('[PLAYBACK_ERROR] Stack: $stackTrace');
      newController.dispose();
      if (mounted && requestId == _initCounter) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  void _onVideoPositionUpdate() {
    if (_controller != null && _controller!.value.isPlaying && !_isDraggingScrubber) {
      final currentTime = _controller!.value.position.inSeconds.toDouble();
      setState(() {
        _currentPosition = currentTime;
      });
      
      // Notify parent of player state changes
      widget.onPlayerStateChanged?.call(
        _controller!.value.isPlaying,
        _controller!.value.position,
        _controller!.value.duration,
      );
      
      // Log timeupdate periodically (every second)
      if (kDebugMode && currentTime % 1.0 == 0) {
        debugPrint('[TIMEUPDATE] t=${currentTime.toStringAsFixed(1)} id=${widget.postId}');
      }
    }
  }

  void _startPlaybackHeartbeat() {
    _playbackHeartbeat?.cancel();
    _playbackHeartbeat = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_controller != null && _controller!.value.isPlaying) {
        final currentTime = _controller!.value.position.inSeconds.toDouble();
        debugPrint('[PLAYING_HEARTBEAT] t=${currentTime.toStringAsFixed(1)} id=${widget.postId}');
      }
    });
  }

  void _startScrubberTimer() {
    _scrubberTimer?.cancel();
    _scrubberTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_controller != null && _controller!.value.isPlaying && !_isDraggingScrubber) {
        final currentTime = _controller!.value.position.inSeconds.toDouble();
        debugPrint('[SCRUBBER_TIME] t=${currentTime.toStringAsFixed(1)} id=${widget.postId}');
      }
    });
  }

  void _togglePlayPause() {
    if (_controller != null && _controller!.value.isInitialized) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _playbackHeartbeat?.cancel();
        _scrubberTimer?.cancel();
        _controlsTimer?.cancel(); // Cancel auto-hide timer when paused
        // Keep controls visible when paused
        setState(() {
          _showControls = true;
        });
        debugPrint('[PLAYBACK_PAUSED] Controls now visible id=${widget.postId}');
        
        // Notify parent of player state change
        widget.onPlayerStateChanged?.call(
          false,
          _controller!.value.position,
          _controller!.value.duration,
        );
      } else {
        _controller!.play();
        debugPrint('[PLAYBACK_START] t=${_controller!.value.position.inSeconds.toDouble()} id=${widget.postId}');
        _startPlaybackHeartbeat();
        if (widget.showScrubber) {
          _startScrubberTimer();
        }
        // Start auto-hide timer when playing
        _startControlsAutoHide();
        setState(() {});
        
        // Notify parent of player state change
        widget.onPlayerStateChanged?.call(
          true,
          _controller!.value.position,
          _controller!.value.duration,
        );
      }
    }
  }

  void _onScrubberChanged(double value) {
    // SAFETY: Validate controller before handling scrubber drag
    if (_controller == null || !_controller!.value.isInitialized || !mounted) {
      return;
    }
    
    // On first drag, pause video and remember playback state
    if (!_isDraggingScrubber) {
      _wasPlayingBeforeDrag = _controller!.value.isPlaying;
      if (_wasPlayingBeforeDrag) {
        try {
          _controller!.pause();
          _playbackHeartbeat?.cancel();
          _scrubberTimer?.cancel();
          _controlsTimer?.cancel(); // Cancel auto-hide timer while scrubbing
          debugPrint('[SCRUBBER_DRAG_START] Paused for scrubbing id=${widget.postId}');
        } catch (e) {
          debugPrint('[SCRUBBER_PAUSE_ERROR] $e id=${widget.postId}');
        }
      }
      
      if (mounted) {
        setState(() {
          _isDraggingScrubber = true;
        });
      }
    }
    
    // Update scrubber position immediately for smooth drag
    setState(() {
      _scrubberValue = value;
    });
    
    // Store the pending seek value
    _pendingSeekValue = value;
    
    // Throttle seek operations to 250ms to prevent render thread flood
    if (_seekThrottle == null || !_seekThrottle!.isActive) {
      _performSeek(value);
      _seekThrottle = Timer(const Duration(milliseconds: 250), () {
        // SAFETY: Check controller is still valid before seeking
        if (mounted && _pendingSeekValue != value && _controller != null && _controller!.value.isInitialized) {
          _performSeek(_pendingSeekValue);
        }
      });
    }
  }
  
  void _performSeek(double value) {
    // SAFETY: Validate controller and duration before seeking
    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('[SEEK_SKIP] Controller not ready id=${widget.postId}');
      return;
    }
    
    final duration = _controller!.value.duration;
    
    // SAFETY: Validate duration is positive before calculating position
    if (duration.inMilliseconds <= 0) {
      debugPrint('[SEEK_SKIP] Invalid duration=${duration.inMilliseconds}ms id=${widget.postId}');
      return;
    }
    
    try {
      final targetMs = (value * duration.inMilliseconds).round();
      final position = Duration(milliseconds: targetMs.clamp(0, duration.inMilliseconds));
      _controller!.seekTo(position);
      
      if (mounted) {
        setState(() {
          _currentPosition = value * duration.inSeconds;
        });
      }
      debugPrint('[SCRUBBER_TIME] t=${_currentPosition.toStringAsFixed(1)} (seeking) id=${widget.postId}');
    } catch (e) {
      debugPrint('[SEEK_ERROR] $e id=${widget.postId}');
    }
  }

  void _onScrubberChangeEnd(double value) {
    // Cancel throttle timer and perform final seek to exact position
    _seekThrottle?.cancel();
    
    // SAFETY: Validate controller before performing final seek
    if (_controller != null && _controller!.value.isInitialized) {
      final duration = _controller!.value.duration;
      
      // SAFETY: Only seek if duration is valid
      if (duration.inMilliseconds > 0) {
        try {
          final targetMs = (value * duration.inMilliseconds).round();
          final position = Duration(milliseconds: targetMs.clamp(0, duration.inMilliseconds));
          _controller!.seekTo(position);
          debugPrint('[SCRUBBER_DRAG_END] Final seek to t=${position.inSeconds.toStringAsFixed(1)} id=${widget.postId}');
        } catch (e) {
          debugPrint('[SCRUBBER_DRAG_END_ERROR] $e id=${widget.postId}');
        }
      }
    }
    
    // Resume playback if it was playing before drag
    if (_wasPlayingBeforeDrag && _controller != null && _controller!.value.isInitialized) {
      try {
        _controller!.play();
        _startPlaybackHeartbeat();
        if (widget.showScrubber && kEnableInteractiveScrubber) {
          _startScrubberTimer();
        }
        // Start auto-hide timer for controls
        _startControlsAutoHide();
        debugPrint('[SCRUBBER_DRAG_END] Resumed playback id=${widget.postId}');
      } catch (e) {
        debugPrint('[SCRUBBER_RESUME_ERROR] $e id=${widget.postId}');
      }
    }
    
    if (mounted) {
      setState(() {
        _isDraggingScrubber = false;
        _wasPlayingBeforeDrag = false;
        _scrubberValue = null; // Clear scrubber value after drag ends
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video or thumbnail background
        Positioned.fill(
          child: _buildVideoOrThumbnail(),
        ),
        
        // Transparent tap-capture layer (BELOW interactive buttons)
        // This captures taps on empty areas and toggles controls visibility
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent, // Let taps pass through to children above
            onPointerDown: (details) {
              debugPrint('[OVERLAY_TAP] Tap detected - toggling controls id=${widget.postId}');
              if (!mounted) return;
              setState(() {
                _showControls = !_showControls;
              });
              _unlockAudio(); // Unlock audio on first tap
            },
            child: Container(
              color: Colors.transparent, // Fully transparent tap capture layer
            ),
          ),
        ),
        
        // Dynamic Play/Pause overlay (shows when controls are visible or when paused)
        // MUST be ABOVE the tap layer to intercept its own taps
        if (_controller != null && _isInitialized && (_showControls || !_controller!.value.isPlaying))
          Center(
            child: GestureDetector(
              onTap: () {
                debugPrint('[PLAY_PAUSE_TAP] Button tapped id=${widget.postId}');
                _togglePlayPause();
                // Start auto-hide timer if video is now playing
                if (_controller != null && _controller!.value.isPlaying) {
                  setState(() {
                    _showControls = true;
                  });
                  _startControlsAutoHide();
                }
              },
              child: AnimatedOpacity(
                opacity: (_showControls || !_controller!.value.isPlaying) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        
        // Mute/Unmute indicator (top-right corner)
        if (_controller != null && _isInitialized)
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                debugPrint('[MUTE_TAP] Volume button tapped id=${widget.postId}');
                _toggleMute();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        
        // Interactive scrubber (positioned at bottom of video, above other overlays)
        if (kEnableInteractiveScrubber && widget.showScrubber && _controller != null && _isInitialized)
          _buildScrubber(),
      ],
    );
  }

  Widget _buildVideoOrThumbnail() {
    // If video is initialized and ready, show the actual video player
    if (_controller != null && _controller!.value.isInitialized && !_hasError) {
      Widget videoWidget = SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      );
      
      // If landscape, rotate 90° clockwise for portrait display
      if (_isLandscape) {
        videoWidget = Transform.rotate(
          angle: 1.5708, // 90 degrees in radians (π/2)
          child: videoWidget,
        );
      }
      
      return FittedBox(
        fit: BoxFit.cover,
        child: videoWidget,
      );
    }
    
    // Fallback to thumbnail while loading or on error
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        widget.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.error, color: Colors.white54, size: 48),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        },
      );
    }
    
    // No thumbnail available - show loading or error
    return Container(
      color: Colors.black,
      child: Center(
        child: _hasError
            ? const Icon(Icons.error_outline, color: Colors.white54, size: 48)
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildScrubber() {
    // SAFETY: Only render scrubber if controller is fully initialized and duration is valid
    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('[SCRUBBER_SKIP] Controller not ready id=${widget.postId}');
      return const SizedBox.shrink();
    }
    
    final duration = _controller!.value.duration;
    final position = _controller!.value.position;
    
    // SAFETY: Validate duration is positive and finite before calculating progress
    if (duration.inMilliseconds <= 0 || duration.inMilliseconds.isNaN || duration.inMilliseconds.isInfinite) {
      debugPrint('[SCRUBBER_SKIP] Invalid duration=${duration.inMilliseconds}ms id=${widget.postId}');
      return const SizedBox.shrink();
    }
    
    // Log scrubber visibility and mount on first build using postFrameCallback
    debugPrint('[SCRUBBER_VISIBLE] duration=${duration.inSeconds}s position=${position.inSeconds}s id=${widget.postId}');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final RenderBox? scrubberBox = _scrubberKey.currentContext?.findRenderObject() as RenderBox?;
          if (scrubberBox != null && widget.onScrubberMeasured != null) {
            // Measure actual on-screen position to account for SafeArea insets
            final screenHeight = MediaQuery.of(context).size.height;
            final scrubberGlobalPosition = scrubberBox.localToGlobal(Offset.zero);
            final scrubberBottomY = scrubberGlobalPosition.dy;
            final scrubberBottomOffset = screenHeight - scrubberBottomY;
            
            debugPrint('[SCRUBBER_MEASURED] bottomOffset=${scrubberBottomOffset.toStringAsFixed(0)}px height=${scrubberBox.size.height.toStringAsFixed(0)}px configuredPosition=${widget.scrubberBottomPosition.toStringAsFixed(0)}px id=${widget.postId}');
            widget.onScrubberMeasured!(scrubberBottomOffset);
          }
        } catch (e) {
          debugPrint('[SCRUBBER_MEASURE_ERROR] $e id=${widget.postId}');
        }
      }
    });
    
    // SAFETY: Clamp progress to valid range [0.0, 1.0]
    // Use _scrubberValue during drag, otherwise use actual position
    final rawProgress = _isDraggingScrubber && _scrubberValue != null
        ? _scrubberValue!
        : position.inMilliseconds / duration.inMilliseconds;
    final progress = rawProgress.clamp(0.0, 1.0);
    
    // Calculate display position based on scrubber value or actual position
    final displayPosition = _isDraggingScrubber && _scrubberValue != null
        ? Duration(milliseconds: (_scrubberValue! * duration.inMilliseconds).round())
        : position;
    
    return Positioned(
      left: 0,
      right: 0,
      bottom: widget.scrubberBottomPosition, // Customizable: 0 = flush to bottom, 60 = above nav bar
      child: Container(
        key: _scrubberKey, // Attach key for measurement
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Row(
          children: [
            Text(
              _formatDuration(displayPosition),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withOpacity(0.2),
                  trackHeight: 2.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                ),
                child: Slider(
                  value: progress.isNaN ? 0.0 : progress,
                  min: 0.0,
                  max: 1.0,
                  onChanged: _onScrubberChanged,
                  onChangeEnd: _onScrubberChangeEnd,
                ),
              ),
            ),
            Text(
              _formatDuration(duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
