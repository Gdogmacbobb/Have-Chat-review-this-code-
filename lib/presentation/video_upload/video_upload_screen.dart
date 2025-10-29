import 'dart:io' show File;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../../theme/app_theme.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/profile_service.dart';
import '../../services/video_upload_service.dart';
import '../../utils/web_dom_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'dart:js' if (dart.library.html) 'dart:js' as js;
import '../../utils/ui_web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../widgets/performance_type_badge.dart';
import '../../services/thumbnail_frame_extractor_web.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({Key? key}) : super(key: key);

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isPlaying = false;
  String? _caption;
  String _performanceType = 'Music';
  String _location = 'Washington Square Park';
  String _privacy = 'Public';
  String? _videoPath;
  String? _cameraDirection; // 'front' or 'back'
  String _userHandle = '@user';
  String? _userProfileImageUrl;
  
  // Inline thumbnail selection
  bool _showThumbnailScrubber = false; // Toggle inline scrubber UI
  double _thumbnailScrubPosition = 0.0; // Current scrubber position (0.0 to 1.0)
  Uint8List? _thumbnailBytes; // Canvas-extracted thumbnail bytes
  int? _selectedFrameMs; // Selected frame timestamp in milliseconds
  bool _hasDisplayedInitialFrame = false; // Track if we've shown first frame
  bool _isCapturingFrame = false; // Track frame capture state
  String _debugThumbnailStatus = ''; // Debug status for inline capture
  final ThumbnailFrameExtractor _thumbnailExtractor = ThumbnailFrameExtractor();
  bool _extractorInitialized = false;
  
  // Video texture refresh mechanism (kept for compatibility)
  int _videoWidgetKey = 0;
  bool _isDecodingFrame = false;
  String _debugFrameStatus = '';
  
  // Shared orientation state - single source of truth
  double _orientationRadians = 0.0; // Rotation angle in radians (0 for portrait, 1.5708 for landscape)
  
  final ProfileService _profileService = ProfileService();
  final VideoUploadService _uploadService = VideoUploadService();
  bool _isUploading = false;
  String _uploadDebugStatus = ''; // On-screen debug status for mobile testing

  /// Normalize UI performance type labels to database values
  /// Converts title-case UI labels ('Visual Arts') to lowercase database values ('visual_arts')
  String _normalizePerformanceType(String uiLabel) {
    switch (uiLabel) {
      case 'Music':
        return 'music';
      case 'Dance':
        return 'dance';
      case 'Visual Arts':
        return 'visual_arts'; // Critical: underscore for database
      case 'Comedy':
        return 'comedy';
      case 'Magic':
        return 'magic';
      case 'Other':
        return 'other';
      default:
        // Fallback: convert to lowercase with underscores
        return uiLabel.toLowerCase().replaceAll(' ', '_');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SAFETY: Use safe null check instead of force unwrap
    final args = ModalRoute.of(context)?.settings.arguments;
    
    // Skip if args is null (can happen during navigation transitions)
    if (args == null) {
      if (kDebugMode) print('[ROUTE_ARGS] No arguments provided to VideoUploadScreen');
      return;
    }
    
    // Handle both old String format and new Map format for backwards compatibility
    if (args is String && _videoPath == null) {
      _videoPath = args;
      _cameraDirection = 'back'; // Default to back camera for old format
      _initializeVideoPlayerFuture = _initializeVideoController(args);
      _loadUserProfile();
      if (kDebugMode) print('[BUTTON_STATE] New upload screen initialized - button reset to DEFAULT (orange)');
    } else if (args is Map<String, dynamic> && _videoPath == null) {
      _videoPath = args['videoPath'] as String?;
      _cameraDirection = args['cameraDirection'] as String? ?? 'back';
      if (kDebugMode) {
        print('[CAMERA_META] Video recorded with $_cameraDirection camera');
        print('[BUTTON_STATE] New upload screen initialized - button reset to DEFAULT (orange)');
      }
      if (_videoPath != null) {
        _initializeVideoPlayerFuture = _initializeVideoController(_videoPath!);
        _loadUserProfile();
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return;
      }

      final profile = await _profileService.getUserProfile(user.id);
      if (profile != null && profile['username'] != null) {
        if (mounted) {
          setState(() {
            _userHandle = '@${profile['username']}';
            _userProfileImageUrl = profile['profile_image_url'] as String?;
          });
        }
      }
    } catch (e) {
      // Silently fail for profile loading
    }
  }

  Future<void> _initializeVideoController(String videoPath) async {
    try {
      // Platform-specific video controller creation
      final VideoPlayerController controller;
      if (kIsWeb) {
        controller = VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else {
        controller = VideoPlayerController.file(File(videoPath));
      }
      
      _controller = controller;
      
      await _controller!.initialize();
      
      // Calculate orientation once from video metadata - single source of truth
      // Use rotationCorrection from metadata, not just dimensions
      final videoSize = _controller!.value.size;
      final rotationCorrection = _controller!.value.rotationCorrection.toDouble();
      final isPortraitByDimensions = videoSize.height > videoSize.width;
      final deviceIsPortrait = true; // Assume portrait device for upload screen
      final videoIsLandscape = videoSize.width > videoSize.height;
      
      // Determine if rotation is needed based on metadata and dimensions
      final needsRotation = deviceIsPortrait && videoIsLandscape && rotationCorrection == 0;
      _orientationRadians = needsRotation ? 1.5708 : rotationCorrection; // Use metadata or apply 90° if needed
      
      final orientationType = needsRotation ? "landscape (needs rotation)" : (rotationCorrection > 0 ? "portrait with correction" : "portrait");
      if (kDebugMode) print('[THUMBNAIL] orientation calculated from metadata: $orientationType (${(_orientationRadians * 180 / 3.14159).round()}°)');
      
      // Don't prime here - let the FutureBuilder build the VideoPlayer widget first
      // Priming will happen in a postFrameCallback after the widget is built
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load video: $e')),
        );
      }
      rethrow;
    }
  }

  Future<void> _primeThumbnail(Duration position, {int retryCount = 0}) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      if (kDebugMode) print('[THUMBNAIL] prime:skip - controller not ready');
      return;
    }
    
    if (kDebugMode) print('[THUMBNAIL] prime:start ${position.inMilliseconds}ms (attempt ${retryCount + 1})');
    
    try {
      // Seek to target frame
      await _controller!.seekTo(position);
      
      // Mute to avoid audio blip during paint
      _controller!.setVolume(0.0);
      
      // Play briefly to force texture rendering (critical for web) - increased to 200ms per spec
      await _controller!.play();
      await Future.delayed(const Duration(milliseconds: 200));
      await _controller!.pause();
      
      // Re-seek to target position to ensure we're at the exact frame (playback may have overshot)
      await _controller!.seekTo(position);
      await Future.delayed(const Duration(milliseconds: 50)); // Brief delay for seek to settle
      
      // Verify that we're at the correct position and controller is ready
      final actualPosition = _controller!.value.position;
      final positionDiff = (actualPosition - position).abs();
      final isAtPosition = positionDiff < const Duration(milliseconds: 80); // ±80ms tolerance per spec
      final isReady = _controller!.value.isInitialized && !_controller!.value.isPlaying;
      
      // Web-specific: check video element readyState if available
      bool webReady = true;
      if (kIsWeb) {
        try {
          final videoElements = html.document.querySelectorAll('video');
          if (videoElements.isNotEmpty) {
            final videoElement = videoElements.first as html.VideoElement;
            webReady = videoElement.readyState >= 2; // HAVE_CURRENT_DATA or better
            if (kDebugMode) print('[THUMBNAIL] web readyState: ${videoElement.readyState}');
          }
        } catch (e) {
          // Silently fail web check
        }
      }
      
      // Restore volume
      _controller!.setVolume(1.0);
      
      // If verification fails and we haven't retried yet, try once more
      if (!isAtPosition || !isReady || !webReady) {
        if (retryCount < 1) {
          if (kDebugMode) print('[THUMBNAIL] prime:retry - pos:$isAtPosition ready:$isReady web:$webReady (diff:${positionDiff.inMilliseconds}ms)');
          await Future.delayed(const Duration(milliseconds: 150)); // 150ms delay per spec
          await _primeThumbnail(position, retryCount: retryCount + 1);
          return;
        } else {
          if (kDebugMode) print('[THUMBNAIL] prime:failed after retry - pos:$isAtPosition ready:$isReady web:$webReady');
        }
      } else {
        if (kDebugMode) print('[THUMBNAIL] prime:verify ok ${position.inMilliseconds}ms');
      }
      
      // Update UI after texture is ready
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (kDebugMode) print('[THUMBNAIL] prime:error $e');
    }
  }
  

  Future<void> _startThumbnailSelection() async {
    if (_videoPath == null || _controller == null) return;
    
    if (kDebugMode) print('[ROUTE_TRACE] _startThumbnailSelection called - NO navigation, inline toggle only');
    
    // Initialize thumbnail extractor if not already done
    if (!_extractorInitialized && kIsWeb) {
      try {
        setState(() {
          _debugThumbnailStatus = '[THUMB_INLINE] Initializing extractor...';
        });
        
        await _thumbnailExtractor.initializeVideo(
          _videoPath!,
          cameraDirection: _cameraDirection ?? 'back',
          orientationRadians: _orientationRadians,
        );
        _extractorInitialized = true;
        
        if (kDebugMode) print('[THUMB_INLINE] Extractor initialized successfully for $_cameraDirection camera');
      } catch (e) {
        if (kDebugMode) print('[THUMB_INLINE] Failed to initialize extractor: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to initialize thumbnail picker')),
          );
        }
        return;
      }
    }
    
    // Toggle inline scrubber UI
    setState(() {
      _showThumbnailScrubber = !_showThumbnailScrubber;
    });
    
    if (kDebugMode) {
      print('[INLINE_PICKER_ACTIVE] Scrubber visibility toggled: $_showThumbnailScrubber');
      print('[BUTTON_STATE] Button state: ${_thumbnailBytes != null ? "SELECTED (gray)" : "DEFAULT (orange)"}, Scrubber: ${_showThumbnailScrubber ? "VISIBLE" : "HIDDEN"}');
    }
    
    // Auto-capture first frame when opening scrubber
    if (_showThumbnailScrubber && _thumbnailBytes == null) {
      await _captureFrameAtScrubPosition(0.0);
    }
  }

  Future<void> _captureFrameAtScrubPosition(double position) async {
    if (_isCapturingFrame || !_extractorInitialized) return;
    
    setState(() {
      _isCapturingFrame = true;
      _thumbnailScrubPosition = position;
      _debugThumbnailStatus = '[THUMB_INLINE] Capturing frame at ${(position * 100).toStringAsFixed(0)}%...';
    });
    
    try {
      final durationMs = _controller!.value.duration.inMilliseconds;
      final targetSeconds = (position * durationMs) / 1000.0;
      
      if (kDebugMode) print('[THUMB_INLINE] Seeking to ${targetSeconds.toStringAsFixed(2)}s (position=$position)');
      
      // Capture frame using extractor
      final frameBytes = await _thumbnailExtractor.captureFrameAtPosition(targetSeconds);
      
      if (frameBytes != null && mounted) {
        setState(() {
          _thumbnailBytes = frameBytes;
          _selectedFrameMs = (targetSeconds * 1000).round();
          _debugThumbnailStatus = '[THUMB_INLINE] Frame captured: ${(frameBytes.length / 1024).toStringAsFixed(1)} KB at ${targetSeconds.toStringAsFixed(1)}s';
        });
        
        if (kDebugMode) {
          print('[THUMBNAIL_CAPTURE] Captured ${(frameBytes.length / 1024).toStringAsFixed(1)} KB at ${targetSeconds.toStringAsFixed(1)}s (position=$position)');
          print('[BUTTON_STATE] Transition to SELECTED state - Button should now be gray with checkmark');
        }
        
        // Clear debug message after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _debugThumbnailStatus = '');
        });
      } else {
        if (kDebugMode) print('[THUMB_INLINE] Frame capture failed');
        setState(() {
          _debugThumbnailStatus = '[THUMB_INLINE] Failed to capture frame';
        });
      }
    } catch (e) {
      if (kDebugMode) print('[THUMB_INLINE] Error capturing frame: $e');
      if (mounted) {
        setState(() {
          _debugThumbnailStatus = '[THUMB_INLINE] Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingFrame = false;
        });
      }
    }
  }


  Future<void> _showFullScreenPreview() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => _FullScreenVideoPreview(
        controller: _controller!,
        caption: _caption ?? '',
        performanceType: _performanceType,
        location: _location,
        userHandle: _userHandle,
        profileImageUrl: _userProfileImageUrl,
        orientationRadians: _orientationRadians, // Pass shared orientation state
      ),
    );
    
    // After preview closes, refresh thumbnail to ensure correct orientation
    if (mounted && _controller != null && _controller!.value.isInitialized) {
      if (kDebugMode) print('[ROTATION] preview closed — refreshing thumbnail');
      
      // DOM-level transform cleanup (web only) - remove CSS transforms that preview applied
      if (kIsWeb) {
        try {
          final videoElements = html.document.querySelectorAll('video');
          for (var i = 0; i < videoElements.length; i++) {
            final videoEl = videoElements[i] as html.VideoElement;
            videoEl.style.removeProperty('transform');
            videoEl.style.removeProperty('rotate');
            videoEl.style.removeProperty('will-change');
            videoEl.style.removeProperty('position');
            videoEl.style.removeProperty('top');
            videoEl.style.removeProperty('left');
            videoEl.style.removeProperty('width');
            videoEl.style.removeProperty('height');
            videoEl.style.removeProperty('object-fit');
            videoEl.style.transform = 'none';
          }
          if (kDebugMode) print('[ROTATION] DOM transform cleared, current wrapper rotation = ${(_orientationRadians * 180 / 3.14159).round()}°');
        } catch (e) {
          if (kDebugMode) print('[ROTATION] DOM cleanup error: $e');
        }
      }
      
      // Determine thumbnail position: if video was at end, use last frame; otherwise use selected or first frame
      final currentPosition = _controller!.value.position;
      final duration = _controller!.value.duration;
      final videoWasAtEnd = currentPosition >= duration - const Duration(milliseconds: 100);
      
      Duration thumbnailPosition;
      if (videoWasAtEnd) {
        // Video completed - use last visible frame
        thumbnailPosition = duration - const Duration(milliseconds: 33);
        if (kDebugMode) print('[END_FRAME] Re-priming with last frame position: ${thumbnailPosition.inMilliseconds}ms');
      } else if (_selectedFrameMs != null) {
        // User has selected a custom thumbnail
        thumbnailPosition = Duration(milliseconds: _selectedFrameMs!);
      } else {
        // Default to first frame
        thumbnailPosition = Duration.zero;
      }
      
      await _primeThumbnail(thumbnailPosition);
      if (kDebugMode) print('[ROTATION] re-applied orientation ${(_orientationRadians * 180 / 3.14159).round()}°');
      setState(() {}); // Force rebuild with correct orientation
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _thumbnailExtractor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Post", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unified thumbnail-preview button
            FutureBuilder<void>(
              future: _initializeVideoPlayerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && 
                    snapshot.hasError) {
                  return Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Video failed to load',
                        style: TextStyle(color: Colors.red.shade400),
                      ),
                    ),
                  );
                } else if (snapshot.connectionState == ConnectionState.done &&
                           _controller != null &&
                           _controller!.value.isInitialized) {
                  // Auto-capture first frame as default thumbnail
                  if (!_hasDisplayedInitialFrame) {
                    _hasDisplayedInitialFrame = true; // Set flag immediately to prevent re-scheduling
                    if (kDebugMode) print('[THUMB_INLINE] scheduling auto-capture of first frame');
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (mounted && kIsWeb && _videoPath != null) {
                        if (kDebugMode) print('[THUMB_INLINE] Auto-capturing first frame');
                        try {
                          // Initialize extractor
                          if (!_extractorInitialized) {
                            await _thumbnailExtractor.initializeVideo(
                              _videoPath!,
                              cameraDirection: _cameraDirection ?? 'back',
                              orientationRadians: _orientationRadians,
                            );
                            _extractorInitialized = true;
                          }
                          // Auto-capture first frame
                          await _captureFrameAtScrubPosition(0.0);
                        } catch (e) {
                          if (kDebugMode) print('[THUMB_INLINE] Auto-capture failed: $e');
                        }
                      }
                    });
                  }
                  
                  // Unified thumbnail-preview element
                  return Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      child: AspectRatio(
                        aspectRatio: 9 / 16, // Portrait 9:16 aspect ratio
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Video frame as thumbnail background (with rotation from shared state)
                                Builder(
                                  builder: (context) {
                                    final videoSize = _controller!.value.size;
                                    
                                    // Use shared orientation state - single source of truth
                                    // Check absolute value to handle both positive and negative rotations
                                    if (_orientationRadians.abs() > 1e-3) {
                                      return Transform.rotate(
                                        angle: _orientationRadians,
                                        child: FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: videoSize.width,
                                            height: videoSize.height,
                                            // Key forces widget rebuild when seeking
                                            child: VideoPlayer(
                                              _controller!,
                                              key: ValueKey(_videoWidgetKey),
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      return FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: videoSize.width,
                                          height: videoSize.height,
                                          // Key forces widget rebuild when seeking
                                          child: VideoPlayer(
                                            _controller!,
                                            key: ValueKey(_videoWidgetKey),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                
                                // Thumbnail overlay - shows selected frame on top of video
                                if (_thumbnailBytes != null)
                                  Positioned.fill(
                                    child: Builder(
                                      builder: (context) {
                                        if (kDebugMode) {
                                          print('[OVERLAY_VISIBLE] Image.memory rendering thumbnail (${(_thumbnailBytes!.length / 1024).toStringAsFixed(1)} KB) on top of VideoPlayer');
                                        }
                                        return Image.memory(
                                          _thumbnailBytes!,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                        );
                                      },
                                    ),
                                  ),
                                
                                // Loading overlay during frame capture
                                if (_isCapturingFrame)
                                  Container(
                                    color: Colors.black.withOpacity(0.5),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primaryOrange,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                
                                // Debug overlay showing inline thumbnail status
                                if (_debugThumbnailStatus.isNotEmpty)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _debugThumbnailStatus,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                
                                // Transparent tap overlay (above video on web, intercepts pointer events)
                                PointerInterceptor(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _showFullScreenPreview,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Transparent container
                                          Container(color: Colors.transparent),
                                          
                                          // Centered play icon overlay (non-interactive, just visual)
                                          IgnorePointer(
                                            child: Center(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.3),
                                                  shape: BoxShape.circle,
                                                ),
                                                padding: const EdgeInsets.all(12),
                                                child: Icon(
                                                  Icons.play_circle_filled,
                                                  color: Colors.white.withOpacity(0.75),
                                                  size: 56,
                                                ),
                                              ),
                                            ),
                                          ),
                                          
                                          // Duration badge (bottom-right, non-interactive visual)
                                          Positioned(
                                            right: 10,
                                            bottom: 10,
                                            child: IgnorePointer(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  _formatDuration(_controller!.value.duration),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  // Loading state
                  return Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // Inline Thumbnail Selection UI
            if (_controller != null && _controller!.value.isInitialized) ...[
              // Select Thumbnail button (toggles inline scrubber) - Animated transition
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _thumbnailBytes != null 
                        ? const Color(0xFF3C3C3C) // Gray when selected
                        : const Color(0xFFFF8C00), // Orange when not selected
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(
                    _thumbnailBytes != null ? Icons.check_circle : Icons.image,
                    color: Colors.white,
                  ),
                  label: Text(
                    _thumbnailBytes != null 
                        ? 'Thumbnail Selected'
                        : 'Select Thumbnail',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: _startThumbnailSelection,
                ),
              ),
              
              // Inline scrubber UI (shown when active)
              if (_showThumbnailScrubber) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryOrange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scrub to select thumbnail frame',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            _formatDuration(Duration(
                              milliseconds: (_thumbnailScrubPosition * 
                                  _controller!.value.duration.inMilliseconds).round(),
                            )),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppTheme.primaryOrange,
                                inactiveTrackColor: Colors.grey[700],
                                thumbColor: AppTheme.primaryOrange,
                                overlayColor: AppTheme.primaryOrange.withOpacity(0.2),
                                trackHeight: 3.0,
                              ),
                              child: Slider(
                                value: _thumbnailScrubPosition,
                                min: 0.0,
                                max: 1.0,
                                onChanged: _isCapturingFrame
                                    ? null
                                    : (value) {
                                        _captureFrameAtScrubPosition(value);
                                      },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(_controller!.value.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (_thumbnailBytes != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Frame captured at ${(_selectedFrameMs! / 1000).toStringAsFixed(1)}s (${(_thumbnailBytes!.length / 1024).toStringAsFixed(1)} KB)',
                                style: TextStyle(
                                  color: Colors.green[400],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showThumbnailScrubber = false;
                                });
                                if (kDebugMode) {
                                  print('[BUTTON_STATE] Done pressed - closing scrubber, keeping selection');
                                  print('[UI_VALIDATION] Button remains gray (SELECTED), scrubber hidden');
                                }
                              },
                              child: const Text(
                                'Done',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),

            // Caption
            Text("Caption", style: _labelStyle()),
            const SizedBox(height: 8),
            TextField(
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Share your performance story... #StreetArt #NYC",
                hintStyle: const TextStyle(color: Colors.white54),
                fillColor: AppTheme.inputBackground,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _caption = value),
            ),

            const SizedBox(height: 24),
            Text("Performance Type", style: _labelStyle()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ["Music", "Dance", "Visual Arts", "Comedy", "Magic", "Other"].map((type) {
                final selected = _performanceType == type;
                return PerformanceTypeBadge(
                  label: type,
                  isActive: selected,
                  isSelectable: true,
                  onTap: () {
                    setState(() => _performanceType = type);
                    if (kDebugMode) print('[OMEGA_PILL_STATE] User selected: "$type" → _performanceType="$_performanceType"');
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            Text("Location", style: _labelStyle()),
            const SizedBox(height: 8),
            _locationCard(),

            const SizedBox(height: 24),
            Text("Privacy Settings", style: _labelStyle()),
            const SizedBox(height: 8),
            _privacyOptions(),

            const SizedBox(height: 24),
            // On-screen debug status for mobile testing
            if (_uploadDebugStatus.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryOrange, width: 1),
                ),
                child: Text(
                  _uploadDebugStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isUploading 
                ? const SizedBox(
                    width: 20, 
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white, 
                      strokeWidth: 2,
                    )
                  )
                : const Icon(Icons.upload, color: Colors.white),
              label: Text(_isUploading ? "Uploading..." : "Drop Content", 
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              onPressed: _isUploading ? null : _uploadVideo,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadVideo() async {
    if (_videoPath == null || _caption == null || _caption!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a caption for your video'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (kDebugMode) print('[UPLOAD_INITIATED] Starting upload process...');
    
    setState(() {
      _isUploading = true;
      _uploadDebugStatus = '🚀 Upload started...';
    });
    
    if (kDebugMode) print('[UPLOAD_INITIATED] UI state set to uploading, button disabled');

    try {
      setState(() => _uploadDebugStatus = '📁 Getting video file...');
      
      // Get video file
      dynamic videoFile;
      if (kIsWeb) {
        // For web, we need to get the blob from the video URL
        try {
          final response = await html.HttpRequest.request(
            _videoPath!,
            responseType: 'blob',
          );
          videoFile = response.response as html.Blob;
          if (kDebugMode) print('[VIDEO_FILE] Got blob: ${(videoFile as html.Blob).size} bytes');
        } catch (e) {
          if (kDebugMode) print('[VIDEO_FILE] ❌ Failed to get video blob: $e');
          setState(() => _uploadDebugStatus = '❌ Failed to get video file: $e');
          throw Exception('Failed to load video file: $e');
        }
      } else {
        videoFile = File(_videoPath!);
      }

      setState(() => _uploadDebugStatus = '🖼️ Uploading thumbnail...');
      
      // Upload thumbnail if selected, or auto-generate from first frame
      String? thumbnailUrl;
      if (_thumbnailBytes != null) {
        // Use the canvas-extracted thumbnail from the picker
        if (kDebugMode) print('[THUMBNAIL_UPLOAD_START] Uploading selected thumbnail (${(_thumbnailBytes!.length / 1024).toStringAsFixed(1)} KB)');
        thumbnailUrl = await _uploadService.uploadThumbnailBytes(_thumbnailBytes!);
        if (thumbnailUrl != null) {
          if (kDebugMode) print('[THUMBNAIL_UPLOAD_SUCCESS] Thumbnail uploaded: $thumbnailUrl');
        } else {
          if (kDebugMode) print('[THUMBNAIL_UPLOAD_ERROR] Failed to upload selected thumbnail');
        }
      } else if (kIsWeb) {
        // Auto-generate thumbnail from first frame
        try {
          if (kDebugMode) print('[THUMBNAIL_AUTO_GEN] Auto-generating thumbnail from first frame');
          await _controller?.seekTo(Duration.zero);
          await Future.delayed(const Duration(milliseconds: 200));
          
          final videoElements = html.document.querySelectorAll('video');
          if (videoElements.isNotEmpty) {
            final videoElement = videoElements.first as html.VideoElement;
            final canvas = html.CanvasElement(
              width: videoElement.videoWidth,
              height: videoElement.videoHeight,
            );
            final ctx = canvas.context2D;
            ctx.drawImageScaled(videoElement, 0, 0, canvas.width!, canvas.height!);
            
            final blob = await canvas.toBlob('image/jpeg', 0.85);
            final reader = html.FileReader();
            reader.readAsArrayBuffer(blob);
            await reader.onLoadEnd.first;
            final bytes = reader.result as Uint8List;
            
            thumbnailUrl = await _uploadService.uploadThumbnailBytes(bytes);
            if (kDebugMode) print('[THUMBNAIL_AUTO_GEN_SUCCESS] Auto-generated thumbnail uploaded: $thumbnailUrl');
          }
        } catch (e) {
          if (kDebugMode) print('[THUMBNAIL_AUTO_GEN_ERROR] Failed to auto-generate thumbnail: $e');
        }
      }

      // Get video duration
      final duration = _controller?.value.duration.inSeconds ?? 0;
      
      // Validate performance type is set
      if (_performanceType.isEmpty) {
        if (kDebugMode) print('[OMEGA_PILL_STATE] ERROR: _performanceType is empty!');
        throw Exception('Performance type not selected');
      }
      
      if (kDebugMode) print('[OMEGA_PILL_STATE] Before normalization: _performanceType="$_performanceType"');
      
      // Normalize performance type from UI label to database value
      final normalizedPerformanceType = _normalizePerformanceType(_performanceType);
      if (kDebugMode) {
        print('[VIDEO_META] Duration: ${duration}s, Caption: "${_caption}", Type: $_performanceType');
        print('[OMEGA_PILL_UPLOAD] UI_Label="$_performanceType" → DB_Value="$normalizedPerformanceType"');
      }

      // Step-by-step upload with detailed status for mobile debugging
      if (kDebugMode) print('[VIDEO_UPLOAD_START] Starting video upload to backend API...');
      
      // Step 1 & 2: Upload video file via proxy (no CORS issues)
      setState(() => _uploadDebugStatus = '📤 Uploading video file...');
      final videoPath = await _uploadService.uploadVideoViaProxy(videoFile);
      if (videoPath == null) {
        throw Exception('Failed to upload video file to storage');
      }
      if (kDebugMode) print('[VIDEO_UPLOAD] Video uploaded successfully: $videoPath');
      
      // Step 3: Create metadata
      setState(() => _uploadDebugStatus = '💾 Creating metadata...');
      if (kDebugMode) print('[OMEGA_PILL_UPLOAD] Sending to API: performance_type="$normalizedPerformanceType"');
      final metadata = await _uploadService.createVideoMetadata(
        videoUrl: videoPath,
        thumbnailUrl: thumbnailUrl,
        caption: _caption!,
        performanceType: normalizedPerformanceType,
        duration: duration,
        location: null, // Location check temporarily disabled
        title: _caption,
      );
      
      final success = metadata != null;
      if (kDebugMode) print('[VIDEO_UPLOAD] Metadata creation: ${success ? "SUCCESS" : "FAILED"}');
      
      // Update video metadata with thumbnail URL if we have one
      if (success && thumbnailUrl != null) {
        if (kDebugMode) print('[UPLOAD_COMPLETE] Video upload complete with thumbnail');
      } else if (success) {
        if (kDebugMode) print('[UPLOAD_COMPLETE] Video upload complete (no thumbnail)');
      }

      if (success) {
        if (mounted) {
          if (kDebugMode) print('[UPLOAD_SUCCESS] Showing success message to user');
          setState(() => _uploadDebugStatus = '✅ Upload complete!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to discovery feed
          if (kDebugMode) print('[NAVIGATE_DISCOVERY] Navigating to Discovery Feed...');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/discovery-feed',
            (route) => false,
          );
          if (kDebugMode) print('[NAVIGATE_DISCOVERY] Navigation command executed');
        }
      } else {
        if (kDebugMode) print('[UPLOAD_ERROR] Upload returned false - likely metadata or file upload issue');
        setState(() => _uploadDebugStatus = '❌ Upload failed - check logs');
        throw Exception('Upload process failed');
      }
    } catch (e) {
      if (kDebugMode) print('[UPLOAD_ERROR] Exception caught: $e');
      if (mounted) {
        setState(() => _uploadDebugStatus = '❌ Error: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        if (kDebugMode) print('[UPLOAD_ERROR] Error message shown to user');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        if (kDebugMode) print('[UPLOAD_FINALIZE] Upload state reset, button re-enabled');
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  TextStyle _labelStyle() => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  Widget _locationCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.inputBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Manhattan, NYC",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(_location, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ],
        ),
      );

  Widget _privacyOptions() => Column(
        children: [
          _privacyCard("Public", "Anyone can see your performance", true),
          const SizedBox(height: 8),
          _privacyCard("Followers Only", "Only your followers can see this video", false),
        ],
      );

  Widget _privacyCard(String title, String desc, bool selected) => GestureDetector(
        onTap: () => setState(() => _privacy = title),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _privacy == title ? AppTheme.primaryOrange : Colors.grey.shade700,
              width: 2,
            ),
            color: _privacy == title ? AppTheme.primaryOrange.withOpacity(0.1) : Colors.black26,
          ),
          child: Row(
            children: [
              Icon(
                _privacy == title ? Icons.check_circle : Icons.radio_button_unchecked,
                color: _privacy == title ? AppTheme.primaryOrange : Colors.white54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// Full-screen video preview modal
class _FullScreenVideoPreview extends StatefulWidget {
  final VideoPlayerController controller;
  final String caption;
  final String performanceType;
  final String location;
  final String userHandle;
  final String? profileImageUrl;
  final double orientationRadians; // Shared orientation state

  const _FullScreenVideoPreview({
    required this.controller,
    required this.caption,
    required this.performanceType,
    required this.location,
    required this.userHandle,
    this.profileImageUrl,
    required this.orientationRadians,
  });

  @override
  State<_FullScreenVideoPreview> createState() => _FullScreenVideoPreviewState();
}

class _FullScreenVideoPreviewState extends State<_FullScreenVideoPreview> {
  bool _isPlaying = false;
  bool _showPlayOverlay = false;
  
  bool _isReplitSandbox = false;
  String _platformViewId = 'video-preview-${DateTime.now().millisecondsSinceEpoch}';
  bool _useFallbackView = false;
  html.VideoElement? _htmlVideoElement;
  
  String _textureKey = 'video_player_${DateTime.now().millisecondsSinceEpoch}';
  String? _videoDataSource; // Store video path for controller recreation
  VideoPlayerController? _currentController; // Track current controller for proper disposal

  @override
  void initState() {
    super.initState();
    
    // Store video data source for controller recreation on replay
    _videoDataSource = widget.controller.dataSource;
    _currentController = widget.controller;
    
    if (kIsWeb) {
      try {
        final hostname = js.context['location']['hostname'].toString();
        _isReplitSandbox = hostname.contains('replit');
        if (_isReplitSandbox) {
          _registerPlatformView(widget.controller);
        }
      } catch (e) {
        // Silently fail hostname detection
      }
    }
    
    // Disable auto-looping to fix audio sync - we'll handle replay manually
    widget.controller.setLooping(false);
    widget.controller.addListener(_updatePlaybackState);
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _waitForTextureAndStartPlayback());
  }
  
  void _registerPlatformView(VideoPlayerController controller) {
    if (!kIsWeb) return;
    
    try {
      ui_web.platformViewRegistry.registerViewFactory(
        _platformViewId,
        (int viewId) {
          final videoElement = html.VideoElement()
            ..src = controller.dataSource
            ..setAttribute('playsinline', 'true')
            ..setAttribute('autoplay', 'true')
            ..setAttribute('muted', 'false')
            ..controls = false;
          
          // Store reference for manual replay
          _htmlVideoElement = videoElement;
          
          // Handle video end - pause and show play overlay
          videoElement.onEnded.listen((_) {
            if (mounted) {
              setState(() {
                _showPlayOverlay = true;
                _isPlaying = false;
              });
            }
          });
          
          videoElement.onLoadedMetadata.listen((_) {
            // Use shared orientation state - single source of truth
            // Check absolute value to handle both positive and negative rotations
            final needsRotation = widget.orientationRadians.abs() > 1e-3;
            final rotateDeg = (widget.orientationRadians * 180 / 3.14159).round();
            
            if (needsRotation) {
              if (kDebugMode) print('[THUMBNAIL] rotate:apply ${rotateDeg}deg using shared state (Replit sandbox)');
              videoElement.style.position = 'fixed';
              videoElement.style.top = '50%';
              videoElement.style.left = '50%';
              videoElement.style.transform = 'translate(-50%, -50%) rotate(${rotateDeg}deg)';
              videoElement.style.width = '100vh';
              videoElement.style.height = '100vw';
              videoElement.style.objectFit = 'cover';
              videoElement.style.pointerEvents = 'none';
            } else {
              if (kDebugMode) print('[THUMBNAIL] rotate:apply ${rotateDeg}deg using shared state (Replit sandbox)');
              videoElement.style.position = 'fixed';
              videoElement.style.top = '50%';
              videoElement.style.left = '50%';
              videoElement.style.transform = 'translate(-50%, -50%)';
              videoElement.style.width = '100vw';
              videoElement.style.height = '100vh';
              videoElement.style.objectFit = 'cover';
              videoElement.style.pointerEvents = 'none';
            }
          });
          
          videoElement.play();
          
          return videoElement;
        },
      );
      
      setState(() {
        _useFallbackView = true;
      });
      
      _scheduleRotationCheck();
    } catch (e) {
      // Silently fail platform view registration
    }
  }

  Future<void> _waitForTextureAndStartPlayback() async {
    if (!mounted || _currentController == null || !_currentController!.value.isInitialized) {
      return;
    }

    setState(() {});
    
    if (kIsWeb) {
      _startDomVisibilityCheck();
    } else {
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) _startPlayback();
    }
  }
  
  void _applyDomRotation() {
    if (!kIsWeb) return;
    
    try {
      final videoElements = html.document.querySelectorAll('video');
      if (kDebugMode) print('[THUMBNAIL] rotate:apply checking ${videoElements.length} video elements (standard web)');
      
      // Use shared orientation state - single source of truth
      // Check absolute value to handle both positive and negative rotations
      final needsRotation = widget.orientationRadians.abs() > 1e-3;
      final rotateDeg = (widget.orientationRadians * 180 / 3.14159).round();
      
      if (kDebugMode) print('[THUMBNAIL] rotate:apply ${rotateDeg}deg using shared state (standard web)');
      
      for (var i = 0; i < videoElements.length; i++) {
        final dynamic videoElement = videoElements[i];
        
        if (videoElement.videoWidth == 0 || videoElement.videoHeight == 0) {
          continue;
        }
        
        videoElement.style.removeProperty('position');
        videoElement.style.removeProperty('top');
        videoElement.style.removeProperty('left');
        videoElement.style.removeProperty('width');
        videoElement.style.removeProperty('height');
        videoElement.style.removeProperty('transform');
        
        if (needsRotation) {
          videoElement.style.position = 'fixed';
          videoElement.style.top = '50%';
          videoElement.style.left = '50%';
          videoElement.style.transform = 'translate(-50%, -50%) rotate(${rotateDeg}deg)';
          videoElement.style.width = '100vh';
          videoElement.style.height = '100vw';
          videoElement.style.objectFit = 'cover';
          videoElement.style.pointerEvents = 'none';
        } else {
          videoElement.style.position = 'fixed';
          videoElement.style.top = '50%';
          videoElement.style.left = '50%';
          videoElement.style.transform = 'translate(-50%, -50%)';
          videoElement.style.width = '100vw';
          videoElement.style.height = '100vh';
          videoElement.style.objectFit = 'cover';
          videoElement.style.pointerEvents = 'none';
        }
      }
    } catch (e) {
      if (kDebugMode) print('[THUMBNAIL] rotate:apply error: $e');
    }
  }
  
  void _startDomVisibilityCheck() {
    Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final videoElements = html.document.getElementsByTagName('video');
        
        if (videoElements.length > 0) {
          timer.cancel();
          
          await Future.delayed(const Duration(milliseconds: 100));
          _applyDomRotation();
          
          _startPlayback();
        }
      } catch (e) {
        // Silently fail DOM check
      }
    });
  }
  
  Future<void> _startPlayback() async {
    if (!mounted || _currentController == null) return;
    
    try {
      await _currentController!.play();
      await Future.delayed(const Duration(milliseconds: 32));
      await _currentController!.pause();
      await _currentController!.seekTo(Duration.zero);
    } catch (e) {
      // Silently fail frame decode
    }
    
    if (!mounted) return;
    
    _currentController!.setVolume(1.0);
    await _currentController!.play();
    
    setState(() {
      _isPlaying = true;
    });
    
    if (kIsWeb) {
      _scheduleRotationCheck();
    }
  }
  
  void _scheduleRotationCheck() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _applyDomRotation();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _applyDomRotation();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _applyDomRotation();
    });
  }
  
  Future<void> _replayVideo() async {
    if (!mounted || _videoDataSource == null) return;
    
    setState(() {
      _showPlayOverlay = false;
    });
    
    if (_useFallbackView && _htmlVideoElement != null) {
      // HtmlElementView replay: use load() to force browser to reload entire media stream
      _htmlVideoElement!.load();
      _htmlVideoElement!.play();
      
      // Recreate controller to fully reinitialize audio context
      if (_currentController != null) {
        _currentController!.removeListener(_updatePlaybackState);
        await _currentController!.dispose();
      }
      
      // Create fresh controller with same video source
      final newController = VideoPlayerController.networkUrl(Uri.parse(_videoDataSource!));
      await newController.initialize();
      newController.setLooping(false);
      newController.setVolume(1.0);
      newController.addListener(_updatePlaybackState);
      await newController.play();
      
      _currentController = newController;
      
      setState(() {
        _isPlaying = true;
      });
    } else {
      // VideoPlayer replay: dispose and recreate controller for full audio/video reinitialization
      if (_currentController != null) {
        _currentController!.removeListener(_updatePlaybackState);
        await _currentController!.dispose();
      }
      
      // Create fresh controller from stored data source
      final newController = VideoPlayerController.networkUrl(Uri.parse(_videoDataSource!));
      await newController.initialize();
      newController.setLooping(false);
      newController.setVolume(1.0);
      newController.addListener(_updatePlaybackState);
      await newController.play();
      
      _currentController = newController;
      
      setState(() {
        _isPlaying = true;
      });
      
      if (kIsWeb) {
        _scheduleRotationCheck();
      }
    }
  }

  void _updatePlaybackState() {
    if (mounted && _currentController != null) {
      final position = _currentController!.value.position;
      final duration = _currentController!.value.duration;
      final isPlaying = _currentController!.value.isPlaying;
      
      // Detect video end - capture final frame and show play overlay for manual replay
      if (position >= duration && duration > Duration.zero && !isPlaying) {
        if (kDebugMode) print('[END_FRAME] Video reached end — capturing final frame');
        
        // Seek to last visible frame (duration - 1 frame at 30fps = 33ms)
        final lastFramePosition = duration - const Duration(milliseconds: 33);
        _currentController!.seekTo(lastFramePosition).then((_) {
          _currentController!.pause();
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _showPlayOverlay = true;
              });
            }
          });
        });
      } else {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_currentController != null) {
      _currentController!.removeListener(_updatePlaybackState);
      _currentController!.pause();
      _currentController!.setLooping(false);
    }
    
    // Clean up transforms to prevent rotation persistence
    if (kIsWeb) {
      try {
        if (_htmlVideoElement != null) {
          // Replit sandbox: clean up HTML element view
          if (kDebugMode) print('[THUMBNAIL] rotate:clear (Replit sandbox)');
          _htmlVideoElement!.style.removeProperty('transform');
          _htmlVideoElement!.style.removeProperty('will-change');
          _htmlVideoElement!.style.removeProperty('object-fit');
          if (kDebugMode) print('[THUMBNAIL] rotate:clear done');
        } else {
          // Standard Flutter web: remove all transforms from video elements
          // The upload screen uses Transform.rotate wrapper, so elements should have no inline transform
          if (kDebugMode) print('[THUMBNAIL] rotate:clear (standard web)');
          final videoElements = html.document.querySelectorAll('video');
          if (kDebugMode) print('[THUMBNAIL] rotate:clear cleaning ${videoElements.length} video elements');
          for (var i = 0; i < videoElements.length; i++) {
            final videoElement = videoElements[i] as html.VideoElement;
            videoElement.style.removeProperty('transform');
            videoElement.style.removeProperty('will-change');
            videoElement.style.removeProperty('object-fit');
            videoElement.style.removeProperty('position');
            videoElement.style.removeProperty('top');
            videoElement.style.removeProperty('left');
            videoElement.style.removeProperty('width');
            videoElement.style.removeProperty('height');
          }
          if (kDebugMode) print('[THUMBNAIL] rotate:clear done');
        }
      } catch (e) {
        if (kDebugMode) print('[THUMBNAIL] rotate:clear error: $e');
      }
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use current controller for all video state
    final controller = _currentController ?? widget.controller;
    final videoSize = controller.value.size;
    
    // Use shared orientation state - single source of truth
    final double finalRotation = widget.orientationRadians;
    final isPortrait = finalRotation.abs() > 0.01 || videoSize.height > videoSize.width;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        color: Colors.black,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Black background layer (bottom-most)
            Positioned.fill(
              child: Container(color: Colors.black),
            ),
            
            // VIDEO LAYER with conditional rendering (HtmlElementView fallback in sandbox)
            Positioned.fill(
              child: controller.value.isInitialized
                  ? (_useFallbackView
                      ? // 3️⃣ HtmlElementView Fallback (Replit sandbox)
                        Container(
                          color: Colors.black,
                          child: HtmlElementView(
                            viewType: _platformViewId,
                          ),
                        )
                      : // Normal GPU-accelerated rendering (production)
                        RepaintBoundary(
                          key: ValueKey(_textureKey),
                          child: Container(
                            clipBehavior: Clip.none,
                            color: Colors.black,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: isPortrait 
                                    ? (videoSize.height / videoSize.width) 
                                    : controller.value.aspectRatio,
                                child: isPortrait
                                    ? Transform.rotate(
                                        angle: finalRotation,
                                        child: AspectRatio(
                                          aspectRatio: controller.value.aspectRatio,
                                          child: VideoPlayer(controller),
                                        ),
                                      )
                                    : VideoPlayer(controller),
                              ),
                            ),
                          ),
                        ))
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    ),
            ),

            // PRODUCTION_VIDEO_PLAYER & SANDBOX_HTML_ELEMENT_VIEW: Close button (top-right)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  controller.pause();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // Play overlay button (centered) - shows when video ends
            if (_showPlayOverlay)
              Positioned.fill(
                child: Center(
                  child: GestureDetector(
                    onTap: _replayVideo,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xCC000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),

            // PRODUCTION_VIDEO_PLAYER & SANDBOX_HTML_ELEMENT_VIEW: TikTok-style overlay chrome (bottom)
            Positioned(
              bottom: 40,
              left: 16,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile image and handle
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryOrange,
                        backgroundImage: widget.profileImageUrl != null 
                            ? NetworkImage(widget.profileImageUrl!)
                            : null,
                        child: widget.profileImageUrl == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.userHandle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Performance type
                  Text(
                    '🎵 ${widget.performanceType}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(0, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Caption
                  if (widget.caption.isNotEmpty)
                    Text(
                      widget.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.location,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Full-width video scrubber timeline (edge-to-edge, positioned below location text)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, VideoPlayerValue value, child) {
                  final position = value.position.inMilliseconds.toDouble();
                  final duration = value.duration.inMilliseconds.toDouble();
                  final progress = duration > 0 ? position / duration : 0.0;
                  
                  if (kDebugMode) {
                    print('[SCRUBBAR_PREVIEW] Full-width layout applied - Width: ${MediaQuery.of(context).size.width}px');
                  }
                  
                  return SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: const Color(0xFFFF8C00),
                      inactiveTrackColor: const Color(0xFF444444),
                      thumbColor: const Color(0xFFFF8C00),
                      overlayColor: Colors.transparent,
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (newValue) {
                        if (duration > 0) {
                          final seekPosition = Duration(milliseconds: (newValue * duration).toInt());
                          controller.seekTo(seekPosition);
                          
                          // For HtmlElementView fallback, also update HTML video element with sub-second precision
                          if (_useFallbackView && _htmlVideoElement != null) {
                            _htmlVideoElement!.currentTime = seekPosition.inMilliseconds / 1000.0;
                          }
                        }
                      },
                      onChangeEnd: (newValue) {
                        // Resume playback after seeking
                        controller.play();
                        if (_useFallbackView && _htmlVideoElement != null) {
                          _htmlVideoElement!.play();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
