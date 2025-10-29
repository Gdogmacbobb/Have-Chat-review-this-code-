import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'platform_camera_controller.dart';

class WebCameraController {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isRecording = false;
  
  final StreamController<CameraState> _stateController = StreamController<CameraState>.broadcast();
  
  CameraState _currentState = CameraState(
    isInitialized: false,
    cameraIndex: 0,
    cameraCount: 0,
    zoomLevel: 1.0,
    minZoom: 1.0,
    maxZoom: 1.0,
    torchEnabled: false,
    torchSupported: false,
    lensDirection: 'back',
    resolution: Size.zero,
    fps: 30,
  );
  
  int? get textureId => null;
  bool get isInitialized => _isInitialized;
  CameraState get value => _currentState;
  Stream<CameraState> get stateStream => _stateController.stream;
  CameraController? get cameraController => _cameraController;
  
  Future<void> initialize({
    int cameraIndex = 0,
    int targetFps = 60,
    String quality = 'max',
  }) async {
    if (_isDisposed) throw Exception('Controller is disposed');
    if (_isInitialized) return;
    
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[ENV_MODE] Dev bridge active - using Flutter camera plugin for Replit/web');
      debugPrint('[CAMERA_SOURCE] WebCameraPlugin active');
      debugPrint('Target FPS: $targetFps (web may limit to 30fps)');
      debugPrint('Quality: $quality');
      
      final allCameras = await availableCameras();
      
      if (allCameras.isEmpty) {
        throw Exception('No cameras available');
      }
      
      // Collapse to ONE camera per lens direction (front/back toggle only)
      _cameras = [];
      
      final backCameras = allCameras.where((cam) => cam.lensDirection == CameraLensDirection.back).toList();
      final frontCameras = allCameras.where((cam) => cam.lensDirection == CameraLensDirection.front).toList();
      
      if (backCameras.isNotEmpty) {
        _cameras.add(backCameras.first);
        debugPrint('[CAMERA_SOURCE] Back camera selected: ${backCameras.first.name}');
      }
      
      if (frontCameras.isNotEmpty) {
        _cameras.add(frontCameras.first);
        debugPrint('[CAMERA_SOURCE] Front camera selected: ${frontCameras.first.name}');
      }
      
      // Fallback: If no front/back cameras, use any available camera (external webcams, etc)
      if (_cameras.isEmpty && allCameras.isNotEmpty) {
        _cameras.add(allCameras.first);
        debugPrint('⚠️ [CAMERA_SOURCE] No front/back cameras found, using fallback: ${allCameras.first.name} (${allCameras.first.lensDirection})');
      }
      
      if (_cameras.isEmpty) {
        debugPrint('❌ [CAMERA_SOURCE] No cameras available - SDK reported ${allCameras.length} cameras');
        throw Exception('No cameras available on this device');
      }
      
      debugPrint('[CAMERA_SOURCE] Found ${allCameras.length} total cameras, collapsed to ${_cameras.length} (back:${backCameras.isNotEmpty}, front:${frontCameras.isNotEmpty})');
      
      // Defensive assertion
      if (_cameras.length > 2) {
        debugPrint('⚠️ [CAMERA_SOURCE] WARNING: More than 2 cameras after filtering! Count: ${_cameras.length}');
      }
      
      _currentCameraIndex = cameraIndex.clamp(0, _cameras.length - 1);
      final camera = _cameras[_currentCameraIndex];
      
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: kIsWeb ? ImageFormatGroup.jpeg : ImageFormatGroup.yuv420,
      );
      
      await _cameraController!.initialize();
      
      final minZoom = await _cameraController!.getMinZoomLevel();
      final maxZoom = await _cameraController!.getMaxZoomLevel();
      
      _currentState = CameraState(
        isInitialized: true,
        cameraIndex: _currentCameraIndex,
        cameraCount: _cameras.length,
        zoomLevel: minZoom,
        minZoom: minZoom,
        maxZoom: maxZoom,
        torchEnabled: false,
        torchSupported: camera.lensDirection == CameraLensDirection.back,
        lensDirection: camera.lensDirection == CameraLensDirection.back ? 'back' : 'front',
        resolution: Size(
          _cameraController!.value.previewSize?.width ?? 1280,
          _cameraController!.value.previewSize?.height ?? 720,
        ),
        fps: 30,
      );
      
      _isInitialized = true;
      _stateController.add(_currentState);
      
      debugPrint('Camera initialized successfully');
      debugPrint('Camera Count: ${_cameras.length}');
      debugPrint('Lens Direction: ${_currentState.lensDirection}');
      debugPrint('Zoom Range: ${_currentState.minZoom.toStringAsFixed(2)}x - ${_currentState.maxZoom.toStringAsFixed(2)}x');
      debugPrint('Resolution: ${_currentState.resolution.width.toInt()}x${_currentState.resolution.height.toInt()}');
      debugPrint('[FLASH_STATE] torchSupported:${_currentState.torchSupported}, lens:${_currentState.lensDirection}');
      debugPrint('═══════════════════════════════════════');
      
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
      rethrow;
    }
  }
  
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _isInitialized = false;
    
    await _cameraController?.dispose();
    await _stateController.close();
    
    debugPrint('WebCameraController disposed');
  }
  
  Future<void> switchCamera() async {
    if (!_isInitialized || _isDisposed || _cameras.length < 2) return;
    
    try {
      debugPrint('[CAMERA_SWITCH] Starting switch...');
      
      // Store old controller to dispose AFTER new one is ready
      final oldController = _cameraController;
      
      // Toggle between front and back (0 and 1 since we filtered to 2 cameras)
      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
      final camera = _cameras[_currentCameraIndex];
      
      debugPrint('[CAMERA_LIFECYCLE] Creating new controller for ${camera.lensDirection}');
      
      // Create and initialize NEW controller FIRST
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: kIsWeb ? ImageFormatGroup.jpeg : ImageFormatGroup.yuv420,
      );
      
      await _cameraController!.initialize();
      
      debugPrint('[CAMERA_SWITCH] controllerReinit:success');
      
      // NOW safely dispose old controller
      await oldController?.dispose();
      debugPrint('[CAMERA_LIFECYCLE] disposeHandled:true');
      
      final minZoom = await _cameraController!.getMinZoomLevel();
      final maxZoom = await _cameraController!.getMaxZoomLevel();
      
      _currentState = CameraState(
        isInitialized: true,
        cameraIndex: _currentCameraIndex,
        cameraCount: _cameras.length,
        zoomLevel: minZoom,
        minZoom: minZoom,
        maxZoom: maxZoom,
        torchEnabled: false,
        torchSupported: camera.lensDirection == CameraLensDirection.back,
        lensDirection: camera.lensDirection == CameraLensDirection.back ? 'back' : 'front',
        resolution: Size(
          _cameraController!.value.previewSize?.width ?? 1280,
          _cameraController!.value.previewSize?.height ?? 720,
        ),
        fps: 30,
      );
      
      _stateController.add(_currentState);
      
      debugPrint('[CAMERA_SWITCH] Switched to: ${_currentState.lensDirection}, flash:${_currentState.torchSupported}');
      debugPrint('[ZOOM_EVENTS] resetAfterFlip:true (${minZoom.toStringAsFixed(2)}x)');
      
    } catch (e) {
      debugPrint('❌ [CAMERA_SWITCH] Failed to switch camera: $e');
      rethrow;
    }
  }
  
  Future<void> setTorch(bool enabled) async {
    if (!_isInitialized || _isDisposed) return;
    if (!_currentState.torchSupported) {
      debugPrint('[FLASH_STATE] Torch not supported on ${_currentState.lensDirection} camera');
      return;
    }
    
    try {
      await _cameraController?.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      _currentState = _currentState.copyWith(torchEnabled: enabled);
      _stateController.add(_currentState);
      
      debugPrint('[FLASH_STATE] Torch ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      debugPrint('❌ [FLASH_STATE] Failed to set torch: $e');
    }
  }
  
  Future<void> setFlashMode(FlashMode flashMode) async {
    if (!_isInitialized || _isDisposed) return;
    if (!_currentState.torchSupported) {
      debugPrint('[FLASH_STATE] Flash not supported on ${_currentState.lensDirection} camera');
      return;
    }
    
    try {
      await _cameraController?.setFlashMode(flashMode);
      _currentState = _currentState.copyWith(torchEnabled: flashMode == FlashMode.torch);
      _stateController.add(_currentState);
      
      debugPrint('[FLASH_STATE] Flash mode set to $flashMode');
    } catch (e) {
      debugPrint('❌ [FLASH_STATE] Failed to set flash mode: $e');
      rethrow;
    }
  }
  
  Future<void> setZoom(double level) async {
    if (!_isInitialized || _isDisposed) return;
    
    final clampedZoom = level.clamp(_currentState.minZoom, _currentState.maxZoom);
    
    try {
      await _cameraController?.setZoomLevel(clampedZoom);
      _currentState = _currentState.copyWith(zoomLevel: clampedZoom);
      _stateController.add(_currentState);
    } catch (e) {
      debugPrint('Failed to set zoom: $e');
    }
  }
  
  Future<void> tapToFocus(double x, double y) async {
    if (!_isInitialized || _isDisposed) return;
    
    try {
      await _cameraController?.setFocusPoint(Offset(x, y));
      debugPrint('Focus set to ($x, $y)');
    } catch (e) {
      debugPrint('Failed to set focus: $e');
    }
  }
  
  Future<void> lockExposure(bool lock) async {
    if (!_isInitialized || _isDisposed) return;
    
    try {
      if (lock) {
        await _cameraController?.setExposureMode(ExposureMode.locked);
      } else {
        await _cameraController?.setExposureMode(ExposureMode.auto);
      }
      debugPrint('Exposure ${lock ? "locked" : "unlocked"}');
    } catch (e) {
      debugPrint('Failed to lock exposure: $e');
    }
  }
  
  Future<void> startRecording() async {
    if (!_isInitialized || _isDisposed || _isRecording) return;
    
    try {
      if (kIsWeb) {
        // ========================================================================
        // HYBRID RECORDING: Check if we should use native file input
        // ========================================================================
        bool useNativeCapture = false;
        try {
          // Use js_util.callMethod with html.window for minified builds compatibility
          useNativeCapture = js_util.callMethod(html.window, 'shouldUseNativeCapture', []) as bool;
          debugPrint('[HYBRID_REC_DART] shouldUseNativeCapture: $useNativeCapture');
        } catch (e) {
          debugPrint('[HYBRID_REC_DART] Error checking native capture mode: $e');
          useNativeCapture = false;
        }
        
        if (useNativeCapture) {
          // ========================================================================
          // NATIVE FILE INPUT PATH (iOS/Replit)
          // ========================================================================
          debugPrint('[HYBRID_REC_DART] Using native file input path for iOS/Replit');
          
          // Get current camera facing direction
          final isBackCamera = _currentCameraIndex == 0; // First camera is typically back
          final cameraFacing = isBackCamera ? 'environment' : 'user';
          
          debugPrint('[HYBRID_REC_DART] Starting native recording, camera facing: $cameraFacing');
          
          // ========================================================================
          // CRITICAL FIX: Pause Flutter camera before launching native camera
          // This prevents "Recording video is not available while on a call" error
          // ========================================================================
          try {
            if (_cameraController != null) {
              debugPrint('[CAPTURE_READY] Pausing Flutter camera controller...');
              await _cameraController!.pausePreview();
              debugPrint('[CAPTURE_READY] ✅ Flutter camera paused');
            }
          } catch (e) {
            debugPrint('[CAPTURE_READY] Warning: Failed to pause camera: $e (continuing anyway)');
          }
          
          try {
            // Call the JavaScript hybrid recording function using js_util with html.window
            // This will trigger the file input and return a promise that resolves with the blob
            // The JS side will also stop all getUserMedia tracks for extra safety
            final promise = js_util.callMethod(html.window, 'startHybridRecording', [cameraFacing]);
            final blob = await js_util.promiseToFuture(promise) as html.Blob;
            
            debugPrint('[CAPTURE_FILE] ✅ Native recording completed, blob size: ${blob.size}');
            debugPrint('[CAPTURE_UPLOAD_BEGIN] Preparing to upload video');
            
            // Store the blob for stopRecording to retrieve
            js_util.setProperty(html.window, '_nativeCaptureBlob', blob);
            _isRecording = true;
            
            debugPrint('[HYBRID_REC_DART] Blob stored, marking as recording');
          } catch (e) {
            debugPrint('[CAPTURE_ABORT] ERROR: Native recording failed: $e');
            
            // Resume camera preview on error
            try {
              if (_cameraController != null) {
                await _cameraController!.resumePreview();
                debugPrint('[CAPTURE_READY] Camera preview resumed after error');
              }
            } catch (resumeError) {
              debugPrint('[CAPTURE_READY] Warning: Failed to resume camera: $resumeError');
            }
            
            throw Exception('Native recording failed: $e');
          }
        } else {
          // ========================================================================
          // MEDIARECORDER PATH (Desktop browsers)
          // ========================================================================
          debugPrint('[HYBRID_REC_DART] Using MediaRecorder path for desktop browsers');
          debugPrint('[RECORDER_DART] Getting media stream for custom recorder...');
          
          // Get the video element from camera preview
          final videoElements = html.document.querySelectorAll('video');
          if (videoElements.isEmpty) {
            throw Exception('No video element found');
          }
          
          final videoElement = videoElements.first as html.VideoElement;
          final stream = videoElement.srcObject;
          
          if (stream == null) {
            throw Exception('No media stream available');
          }
          
          debugPrint('[RECORDER_DART] Creating recorder via factory...');
          
          dynamic recorder;
          try {
            // Call the recorder factory directly using js_util with html.window
            final factory = js_util.callMethod(html.window, '__getRecorder', []);
            if (factory == null) {
              throw Exception('Recorder factory not found');
            }
            
            recorder = await js_util.promiseToFuture(
              js_util.callMethod(factory, 'call', [null, stream])
            );
            
            debugPrint('[RECORDER_DART] ✓ Recorder created successfully');
            debugPrint('[REC_START] MediaRecorder recording started');
            
            if (recorder == null) {
              throw Exception('Factory returned null recorder');
            }
            
            // Store recorder globally for stop() to access
            js_util.setProperty(html.window, '_activeRecorder', recorder);
            
            // Call start method
            await js_util.promiseToFuture(js_util.callMethod(recorder, 'start', []));
            _isRecording = true;
            debugPrint('[RECORDER_DART] ✓ Recording started successfully');
          } catch (jsError) {
            debugPrint('[RECORDER_DART] ERROR: $jsError');
            throw Exception('Failed to start recording: $jsError');
          }
        }
      } else {
        await _cameraController?.startVideoRecording();
        _isRecording = true;
        debugPrint('Recording started (mobile mode)');
      }
    } catch (e) {
      _isRecording = false;
      debugPrint('[RECORDER_DART_ERROR] Failed to start recording: $e');
      rethrow;
    }
  }
  
  Future<String> stopRecording() async {
    if (!_isInitialized || _isDisposed || !_isRecording) {
      throw Exception('Not recording');
    }
    
    try {
      if (kIsWeb) {
        // ========================================================================
        // Check if this was a native capture or MediaRecorder recording
        // ========================================================================
        final nativeBlob = js_util.getProperty(html.window, '_nativeCaptureBlob');
        
        if (nativeBlob != null) {
          // ========================================================================
          // NATIVE FILE INPUT PATH - Retrieve stored blob
          // ========================================================================
          debugPrint('[HYBRID_REC_DART] Retrieving native capture blob...');
          
          final blob = nativeBlob as html.Blob;
          
          // Clear the stored blob
          js_util.setProperty(html.window, '_nativeCaptureBlob', null);
          _isRecording = false;
          
          debugPrint('[CAPTURE_FILE] Native capture completed, blob size: ${blob.size}');
          debugPrint('[CAPTURE_UPLOAD_BEGIN] Processing native recorded video, size=${blob.size}');
          
          // Validate blob has data
          if (blob.size == 0) {
            throw Exception('Recording produced empty file (0 bytes)');
          }
          
          // ========================================================================
          // Resume camera preview after successful recording
          // ========================================================================
          try {
            if (_cameraController != null) {
              debugPrint('[CAPTURE_READY] Resuming Flutter camera controller...');
              await _cameraController!.resumePreview();
              debugPrint('[CAPTURE_READY] ✅ Flutter camera resumed');
            }
          } catch (e) {
            debugPrint('[CAPTURE_READY] Warning: Failed to resume camera: $e');
          }
          
          // Convert blob to File and save
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'video_$timestamp.${blob.type.contains('mp4') ? 'mp4' : blob.type.contains('quicktime') ? 'mov' : 'webm'}';
          
          // Create File from Blob
          final file = html.File([blob], fileName, {'type': blob.type});
          
          // Create object URL for the file
          final url = html.Url.createObjectUrlFromBlob(file);
          
          debugPrint('[CAPTURE_UPLOAD_DONE] Native recording complete. File: $fileName (${blob.size} bytes)');
          return url;  // Return the blob URL which can be used as a file path
        } else {
          // ========================================================================
          // MEDIARECORDER PATH - Stop active recorder
          // ========================================================================
          debugPrint('[RECORDER_DART] Stopping MediaRecorder...');
          
          // Get active recorder instance that was stored during start()
          final recorder = js_util.getProperty(html.window, '_activeRecorder');
          if (recorder == null) {
            throw Exception('No active recorder found');
          }
          
          // Validate recorder has stop method
          final hasStop = js_util.hasProperty(recorder, 'stop');
          if (!hasStop) {
            throw Exception('Recorder missing stop method');
          }
          
          // Call stop and get blob
          final blob = await js_util.promiseToFuture(js_util.callMethod(recorder, 'stop', [])) as html.Blob;
          
          // Clear the active recorder
          js_util.setProperty(html.window, '_activeRecorder', null);
          _isRecording = false;
          
          debugPrint('[REC_STOP] MediaRecorder stopped, blob size: ${blob.size}');
          debugPrint('[RECORDER_DART] Got blob: ${blob.size} bytes, type: ${blob.type}');
          
          // Validate blob has data
          if (blob.size == 0) {
            throw Exception('Recording produced empty file (0 bytes). Check browser console for [RECORDER_INVALID] logs.');
          }
          
          // Convert blob to File and save
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'video_$timestamp.${blob.type.contains('mp4') ? 'mp4' : 'webm'}';
          
          // Create File from Blob
          final file = html.File([blob], fileName, {'type': blob.type});
          
          // Create object URL for the file
          final url = html.Url.createObjectUrlFromBlob(file);
          
          debugPrint('[RECORDER_DART] Recording stopped. File: $fileName (${blob.size} bytes), URL: ${url.substring(0, 50)}...');
          return url;  // Return the blob URL which can be used as a file path
        }
      } else {
        final file = await _cameraController?.stopVideoRecording();
        _isRecording = false;
        
        if (file == null) throw Exception('No file returned');
        
        debugPrint('Recording stopped (mobile mode). File: ${file.path}');
        return file.path;
      }
    } catch (e) {
      _isRecording = false;
      debugPrint('[RECORDER_DART_ERROR] Failed to stop recording: $e');
      rethrow;
    }
  }
}
