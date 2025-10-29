import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart' show CameraPreview, FlashMode;
import 'package:file_picker/file_picker.dart';
import '../../platform/platform_camera_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/web_dom_stub.dart' if (dart.library.html) 'dart:html' as html;

class VideoRecordingScreen extends StatefulWidget {
  const VideoRecordingScreen({Key? key}) : super(key: key);

  @override
  State<VideoRecordingScreen> createState() => _VideoRecordingScreenState();
}

class _VideoRecordingScreenState extends State<VideoRecordingScreen> {
  PlatformCameraController? _controller;
  bool _isRecording = false;
  bool _isMuted = false;
  bool _isInitialized = false;
  
  StreamSubscription<CameraState>? _stateSubscription;
  
  // Timer for recording
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  
  // Zoom variables
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 5.0;
  bool _isFlashOn = false;
  bool _hasFlashSupport = false;
  String _lensDirection = 'back';
  
  // Zoom throttling with repeating timer (16ms for 60fps response)
  Timer? _zoomUpdateTimer;
  double? _pendingZoom;
  
  // Camera switch debounce (200ms cooldown)
  DateTime? _lastCameraSwitchTime;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 [UI_RENDER] VideoRecordingScreen initState - starting orientation lock and camera init');
    _lockOrientation();
    _initializeCamera();
  }

  Future<void> _lockOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = PlatformCameraController();
      
      // Listen to state stream for updates
      _stateSubscription = _controller!.stateStream.listen((state) {
        if (mounted) {
          debugPrint('🔄 [CAMERA_STATE] State update: lens=${state.lensDirection}, flash=${state.torchSupported}, zoom=${state.zoomLevel.toStringAsFixed(2)}x');
          setState(() {
            _currentZoom = state.zoomLevel;
            _minZoom = state.minZoom;
            _maxZoom = state.maxZoom;
            _baseZoom = state.zoomLevel;
            _isFlashOn = state.torchEnabled;
            _hasFlashSupport = state.torchSupported;
            _lensDirection = state.lensDirection;
          });
          debugPrint('✅ [FLASH_STATE] Flash support: $_hasFlashSupport, Flash on: $_isFlashOn');
        }
      });
      
      await _controller!.initialize(
        cameraIndex: 0,
        targetFps: 60,
        quality: 'max',
      );
      
      // Get initial state
      final state = _controller!.value;
      if (!mounted) return;
      
      setState(() {
        _isInitialized = true;
        _currentZoom = state.zoomLevel;
        _minZoom = state.minZoom;
        _maxZoom = state.maxZoom;
        _baseZoom = state.zoomLevel;
        _isFlashOn = state.torchEnabled;
        _hasFlashSupport = state.torchSupported;
        _lensDirection = state.lensDirection;
      });
      
      debugPrint('✅ [UI_RENDER] Camera initialized - overlay should be attached');
      debugPrint('📊 [FLASH_STATE] Initial flash support: $_hasFlashSupport on ${_lensDirection} camera');
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera not available: $e'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  Future<void> _toggleRecord() async {
    if (!_isInitialized || _controller == null) return;
    
    if (!_isRecording) {
      try {
        await _controller!.startRecording();
        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });
        
        // Enable torch if flash was turned ON before recording
        if (_isFlashOn) {
          debugPrint('🔦 [FLASH_LIFECYCLE] Flash enabled before recording - activating torch');
          
          // Web: Visual feedback only (no hardware torch)
          if (kIsWeb) {
            debugPrint('🌐 [FLASH_LIFECYCLE] Web mode - visual flash indication only');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Flash enabled for recording'),
                  backgroundColor: Colors.green.shade900,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          } else {
            // Native: Enable hardware torch (rear camera only)
            if (_hasFlashSupport && _lensDirection == 'back') {
              try {
                await _controller!.setFlashMode(FlashMode.torch);
                debugPrint('✅ [FLASH_LIFECYCLE] Torch enabled for recording duration');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Flash enabled for recording'),
                      backgroundColor: Colors.green.shade900,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('⚠️ [FLASH_LIFECYCLE] Failed to enable torch: $e');
              }
            } else {
              // Front camera or unsupported: Visual feedback only
              debugPrint('ℹ️ [FLASH_LIFECYCLE] Front camera or unsupported - visual flash indication only');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Flash enabled for recording'),
                    backgroundColor: Colors.green.shade900,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            }
          }
        }
        
        // Start timer
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordingSeconds++);
          }
        });
      } catch (e) {
        debugPrint('Failed to start recording: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start recording: $e'),
              backgroundColor: Colors.red.shade900,
            ),
          );
        }
      }
    } else {
      // Stop recording with proper null checks and state verification
      try {
        _recordingTimer?.cancel();
        
        // Verify controller is still valid and initialized before stopping
        if (_controller == null) {
          debugPrint('⚠️ [RECORD_LIFECYCLE] Controller is null, cannot stop recording');
          throw Exception('Camera controller not available');
        }
        
        if (!_isInitialized) {
          debugPrint('⚠️ [RECORD_LIFECYCLE] Controller not initialized, cannot stop recording');
          throw Exception('Camera not initialized');
        }
        
        debugPrint('🎬 [RECORD_LIFECYCLE] Stopping recording...');
        final filePath = await _controller!.stopRecording();
        debugPrint('✅ [RECORD_LIFECYCLE] Recording stopped successfully. File: $filePath');
        
        // Auto-turn off flash when recording stops
        if (_isFlashOn) {
          debugPrint('🔦 [FLASH_LIFECYCLE] Flash auto-disabled after recording stopped');
          
          // Web: Visual-only state update (no hardware call)
          if (kIsWeb) {
            debugPrint('🌐 [FLASH_LIFECYCLE] Web mode - visual flash state reset only');
            setState(() {
              _isFlashOn = false;
            });
          } else {
            // Native: Turn off hardware flash if supported
            if (_hasFlashSupport) {
              try {
                await _controller!.setFlashMode(FlashMode.off);
                debugPrint('✅ [FLASH_LIFECYCLE] Hardware torch disabled');
              } catch (e) {
                debugPrint('⚠️ [FLASH_LIFECYCLE] Failed to disable torch: $e');
              }
            }
            setState(() {
              _isFlashOn = false;
            });
          }
          
          debugPrint('✅ [FLASH_LIFECYCLE] Flash auto-off completed');
          
          // Always show flash disabled feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Flash disabled'),
                backgroundColor: Colors.green.shade900,
                duration: const Duration(milliseconds: 800),
              ),
            );
          }
        }
        
        setState(() {
          _isRecording = false;
          _recordingSeconds = 0;
        });
        
        if (!mounted) return;
        
        debugPrint('📍 [NAV_STATE] Navigating to video upload with file: $filePath, camera: $_lensDirection');
        Navigator.pushNamed(context, '/video-upload', arguments: {
          'videoPath': filePath,
          'cameraDirection': _lensDirection,
        });
      } catch (e) {
        debugPrint('❌ [RECORD_LIFECYCLE] Failed to stop recording: $e');
        
        // Reset recording state even if stop fails
        setState(() {
          _isRecording = false;
          _recordingSeconds = 0;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to stop recording: $e'),
              backgroundColor: Colors.red.shade900,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _switchCamera() async {
    debugPrint('📷 [CAMERA_SWITCH] Button tapped! controller=${_controller != null}, initialized=$_isInitialized');
    
    // Show immediate tap feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera flip button tapped'),
          backgroundColor: Colors.blue.shade900,
          duration: const Duration(milliseconds: 500),
        ),
      );
    }
    
    if (!_isInitialized || _controller == null) {
      debugPrint('⚠️ [CAMERA_SWITCH] Camera not ready');
      return;
    }
    if (_isRecording) {
      debugPrint('⚠️ [CAMERA_SWITCH] Cannot switch while recording');
      return;
    }
    
    // Debounce: Prevent rapid button presses
    final now = DateTime.now();
    if (_lastCameraSwitchTime != null) {
      final timeSinceLastSwitch = now.difference(_lastCameraSwitchTime!).inMilliseconds;
      if (timeSinceLastSwitch < 200) {
        debugPrint('⏸️ [CAMERA_SWITCH] Debounced (${timeSinceLastSwitch}ms < 200ms)');
        return;
      }
    }
    _lastCameraSwitchTime = now;
    
    try {
      final startTime = DateTime.now();
      debugPrint('🔄 [CAMERA_SWITCH] Starting camera switch from $_lensDirection...');
      
      await _controller!.switchCamera();
      
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('✅ [CAMERA_SWITCH] Switch completed in ${latency}ms');
      
      // State will be updated via stateStream listener
    } catch (e) {
      debugPrint('❌ [CAMERA_SWITCH] Failed to switch camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch camera: $e'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    debugPrint('💡 [FLASH_TOGGLE] Button tapped! controller=${_controller != null}');
    
    if (_controller == null) {
      debugPrint('⚠️ [FLASH_TOGGLE] Controller is null');
      return;
    }
    
    debugPrint('💡 [FLASH_TOGGLE] Attempting flash toggle...');
    debugPrint('   Current state: support=$_hasFlashSupport, on=$_isFlashOn, lens=$_lensDirection, recording=$_isRecording');
    
    // WEB MOCK: Visual-only flash toggle (browsers don't support torch/flash control)
    if (kIsWeb) {
      final newFlashState = !_isFlashOn;
      debugPrint('🌐 [FLASH_UI] WEB MOCK: Visual flash toggle $_isFlashOn → $newFlashState (no hardware call)');
      
      setState(() {
        _isFlashOn = newFlashState;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newFlashState ? 'Flash icon ON (web preview)' : 'Flash icon OFF (web preview)'),
            backgroundColor: Colors.blue.shade900,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
      debugPrint('✅ [FLASH_UI] Web mock complete - icon state updated visually');
      return;
    }
    
    // NATIVE: Real hardware flash control
    // Check if flash is supported
    if (!_hasFlashSupport) {
      debugPrint('⚠️ [FLASH_TOGGLE] Flash not supported - showing error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Flash not supported on this camera'),
            backgroundColor: Colors.orange.shade900,
          ),
        );
      }
      return;
    }
    
    try {
      final newFlashState = !_isFlashOn;
      debugPrint('🔦 [FLASH_STATE] User toggled flash: $_isFlashOn → $newFlashState');
      
      // Use setFlashMode for native platforms
      await _controller!.setFlashMode(newFlashState ? FlashMode.torch : FlashMode.off);
      
      // Update local state immediately
      setState(() {
        _isFlashOn = newFlashState;
      });
      
      debugPrint('✅ [FLASH_STATE] Flash mode set to ${newFlashState ? "torch" : "off"}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newFlashState ? 'Flash enabled' : 'Flash disabled'),
            backgroundColor: Colors.green.shade900,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [FLASH_STATE] Flash toggle failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Flash not available on this camera'),
            backgroundColor: Colors.orange.shade900,
          ),
        );
      }
    }
  }

  Future<void> _toggleMute() async {
    if (!_isInitialized || _controller == null) return;
    if (_isRecording) return; // Don't toggle while recording
    
    // Toggle mute state
    setState(() {
      _isMuted = !_isMuted;
    });
    
    debugPrint('Mute toggled: ${_isMuted ? "ON" : "OFF"}');
  }

  Future<void> _handleVideoUpload() async {
    if (_isRecording) {
      debugPrint('[VIDEO_UPLOAD] Cannot upload while recording');
      return;
    }

    try {
      debugPrint('[VIDEO_UPLOAD] Opening file picker...');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('[VIDEO_UPLOAD] No file selected');
        return;
      }

      final file = result.files.first;
      String? videoPath;

      if (kIsWeb) {
        // For web, create a blob URL from the file bytes
        if (file.bytes != null) {
          final blob = html.Blob([file.bytes!], 'video/mp4');
          videoPath = html.Url.createObjectUrlFromBlob(blob);
          debugPrint('[VIDEO_UPLOAD] Web blob URL created: $videoPath');
        }
      } else {
        // For mobile, use the file path
        videoPath = file.path;
        debugPrint('[VIDEO_UPLOAD] Mobile file selected: $videoPath');
      }

      if (videoPath == null) {
        debugPrint('[VIDEO_UPLOAD] Failed to get video path');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to load video file'),
              backgroundColor: Colors.red.shade900,
            ),
          );
        }
        return;
      }

      // Navigate to upload screen with the selected video
      // Use 'back' as camera direction since we don't know the original camera used
      debugPrint('[VIDEO_UPLOAD] Navigating to upload screen with: $videoPath');
      
      if (mounted) {
        Navigator.pushNamed(context, '/video-upload', arguments: {
          'videoPath': videoPath,
          'cameraDirection': 'back', // Default for uploaded videos
        });
      }
    } catch (e) {
      debugPrint('[VIDEO_UPLOAD] Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select video: $e'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    }
  }

  void _startZoomUpdateTimer() {
    // Only start if not already running
    if (_zoomUpdateTimer != null && _zoomUpdateTimer!.isActive) return;
    
    // Repeating timer fires every 16ms for 60fps zoom response
    _zoomUpdateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_pendingZoom != null && mounted && _controller != null) {
        final zoomToApply = _pendingZoom!;
        _pendingZoom = null; // Clear immediately to avoid re-applying
        
        // Use Future.microtask to offload from UI thread
        Future.microtask(() async {
          try {
            await _controller!.setZoom(zoomToApply);
          } catch (e) {
            debugPrint('Failed to set zoom: $e');
          }
        });
      }
    });
  }
  
  void _stopZoomUpdateTimer() {
    // Flush any pending zoom before stopping
    if (_pendingZoom != null && mounted && _controller != null) {
      final finalZoom = _pendingZoom!;
      _pendingZoom = null;
      
      // Apply final zoom immediately
      Future.microtask(() async {
        try {
          await _controller!.setZoom(finalZoom);
          debugPrint('Final zoom applied: $finalZoom');
        } catch (e) {
          debugPrint('Failed to set final zoom: $e');
        }
      });
    }
    
    _zoomUpdateTimer?.cancel();
    _zoomUpdateTimer = null;
    _pendingZoom = null;
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 [UI_RENDER] Building UI - initialized=$_isInitialized, flash=$_hasFlashSupport');
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen camera preview with RepaintBoundary for z-index isolation
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: RepaintBoundary(
                child: _buildCameraPreview(),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryOrange,
              ),
            ),

          // Top controls overlay with Material elevation to force above camera preview
          Builder(
            builder: (context) {
              debugPrint('🎨 [UI_OVERLAY] Building overlay - Flash: ${_isFlashOn ? "ON" : "OFF"}, Camera: $_lensDirection');
              final childrenCount = 4; // Back, Mute, Flash, Camera switch
              debugPrint('📊 [CAMERA_STACK] Rendering $childrenCount overlay children');
              return Material(
                color: Colors.transparent,
                elevation: 10, // Force overlay above camera preview
                child: SafeArea(
                  child: Stack(
                    children: [
                    // Back button - always visible for navigation
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _overlayIconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    
                    // Mute button - always visible, disabled when not ready
                    Positioned(
                      top: 12,
                      left: 72,
                      child: _overlayIconButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        onPressed: _toggleMute,
                        isDisabled: !_isInitialized,
                      ),
                    ),
                    
                    // Flash button - always visible, 40% opacity when unsupported
                    Builder(
                      builder: (context) {
                        debugPrint('🔦 [UI_OVERLAY] Flash icon rendering: support=$_hasFlashSupport, on=$_isFlashOn');
                        return Positioned(
                          top: 12,
                          right: 12,
                          child: _overlayIconButton(
                            icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            onPressed: _toggleFlash,
                            isDisabled: !_hasFlashSupport,
                          ),
                        );
                      },
                    ),
                    
                    // Camera switch button - always visible, disabled when not ready
                    Builder(
                      builder: (context) {
                        debugPrint('📷 [UI_OVERLAY] Camera flip icon rendering: initialized=$_isInitialized');
                        return Positioned(
                          top: 12,
                          right: 72,
                          child: _overlayIconButton(
                            icon: Icons.cameraswitch,
                            onPressed: _switchCamera,
                            isDisabled: !_isInitialized,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),

          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recording timer
                if (_isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(_recordingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Bottom control buttons (Upload + Record)
                // Stack ensures record button is centered, upload button positioned relative to it
                SizedBox(
                  height: 80,
                  child: Stack(
                    children: [
                      // Record button - centered horizontally
                      Align(
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: _isInitialized ? _toggleRecord : null,
                          child: Opacity(
                            opacity: _isInitialized ? 1.0 : 0.5,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryOrange,
                                  width: 5,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: _isRecording ? 32 : 64,
                                  height: _isRecording ? 32 : 64,
                                  decoration: BoxDecoration(
                                    color: _isRecording ? Colors.red : Colors.white,
                                    borderRadius: _isRecording
                                        ? BorderRadius.circular(8)
                                        : BorderRadius.circular(32),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Upload button - positioned 40px left of record button
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: const Offset(-109, 0), // -(80/2 + 40 + 58/2) = -109
                          child: GestureDetector(
                            onTap: _isInitialized ? _handleVideoUpload : null,
                            child: Opacity(
                              opacity: _isInitialized ? 1.0 : 0.5,
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0x80000000),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.upload_file,
                                  color: Colors.white,
                                  size: 29,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    
    return GestureDetector(
      onScaleStart: (details) {
        _baseZoom = _currentZoom;
        debugPrint('🔍 [ZOOM_EVENTS] Zoom gesture started at ${_currentZoom.toStringAsFixed(2)}x');
        _startZoomUpdateTimer();
      },
      onScaleUpdate: (details) {
        final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
        
        if (newZoom != _currentZoom && _controller != null && mounted) {
          final updateStart = DateTime.now();
          setState(() {
            _currentZoom = newZoom;
          });
          
          _pendingZoom = newZoom;
          
          final latency = DateTime.now().difference(updateStart).inMilliseconds;
          if (latency > 5) {
            debugPrint('⏱️ [ZOOM_EVENTS] UI update latency: ${latency}ms for ${newZoom.toStringAsFixed(2)}x');
          }
        }
      },
      onScaleEnd: (details) {
        debugPrint('✅ [ZOOM_EVENTS] Zoom gesture ended at ${_currentZoom.toStringAsFixed(2)}x');
        _stopZoomUpdateTimer();
      },
      child: kIsWeb && _controller!.webCameraController != null
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: CameraPreview(_controller!.webCameraController!),
                ),
              ),
            )
          : SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: _controller!.textureId != null
                      ? Texture(textureId: _controller!.textureId!)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
    );
  }

  Widget _overlayIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isDisabled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Opacity(
            opacity: isDisabled ? 0.4 : 1.0,
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _zoomUpdateTimer?.cancel();
    _stateSubscription?.cancel();
    _controller?.dispose();
    // Reset orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
}
