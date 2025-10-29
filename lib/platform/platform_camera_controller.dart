import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_camera_controller.dart';
import 'package:camera/camera.dart' show CameraController;

class PlatformCameraController {
  static const MethodChannel _channel = MethodChannel('com.ynfny/camera');
  static const EventChannel _previewChannel = EventChannel('com.ynfny/camera/preview');
  
  final WebCameraController? _webController;
  final bool _isWebMode;
  
  factory PlatformCameraController() {
    if (kIsWeb) {
      debugPrint('[ENV_MODE] Dev bridge active - creating WebCameraController');
      return PlatformCameraController._(webController: WebCameraController(), isWebMode: true);
    } else {
      debugPrint('[ENV_MODE] Native mode - using platform channels (CameraX/AVFoundation)');
      return PlatformCameraController._(isWebMode: false);
    }
  }
  
  PlatformCameraController._({WebCameraController? webController, required bool isWebMode})
      : _webController = webController,
        _isWebMode = isWebMode;
  
  int? _textureId;
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  StreamSubscription? _previewSubscription;
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
    fps: 0,
  );
  
  int? get textureId => _isWebMode ? _webController?.textureId : _textureId;
  bool get isInitialized => _isWebMode ? (_webController?.isInitialized ?? false) : _isInitialized;
  CameraState get value => _isWebMode ? (_webController?.value ?? _currentState) : _currentState;
  Stream<CameraState> get stateStream => _isWebMode ? (_webController?.stateStream ?? _stateController.stream) : _stateController.stream;
  CameraController? get webCameraController => _isWebMode ? _webController?.cameraController : null;
  
  Future<void> initialize({
    int cameraIndex = 0,
    int targetFps = 60,
    String quality = 'max',
  }) async {
    if (_isWebMode) {
      debugPrint('[CAMERA_SOURCE] WebCameraPlugin active');
      return await _webController!.initialize(
        cameraIndex: cameraIndex,
        targetFps: targetFps,
        quality: quality,
      );
    }
    
    if (_isDisposed) throw Exception('Controller is disposed');
    if (_isInitialized) return;
    
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('[CAMERA_SOURCE] Native CameraX/AVFoundation active');
      debugPrint('PlatformCameraController: Initializing...');
      debugPrint('Camera Index: $cameraIndex');
      debugPrint('Target FPS: $targetFps');
      debugPrint('Quality: $quality');
      
      final result = await _channel.invokeMethod<Map>('initialize', {
        'cameraIndex': cameraIndex,
        'fps': targetFps,
        'quality': quality,
      });
      
      if (result == null) throw Exception('Failed to initialize camera');
      
      _textureId = result['textureId'] as int?;
      _currentState = CameraState(
        isInitialized: true,
        cameraIndex: result['cameraIndex'] as int,
        cameraCount: result['cameraCount'] as int,
        zoomLevel: (result['currentZoom'] as num).toDouble(),
        minZoom: (result['minZoom'] as num).toDouble(),
        maxZoom: (result['maxZoom'] as num).toDouble(),
        torchEnabled: result['torchEnabled'] as bool,
        torchSupported: result['torchSupported'] as bool,
        lensDirection: result['lensDirection'] as String,
        resolution: Size(
          (result['width'] as num).toDouble(),
          (result['height'] as num).toDouble(),
        ),
        fps: result['fps'] as int,
      );
      
      _isInitialized = true;
      _stateController.add(_currentState);
      
      debugPrint('Camera initialized successfully');
      debugPrint('Texture ID: $_textureId');
      debugPrint('Camera Count: ${_currentState.cameraCount}');
      debugPrint('Lens Direction: ${_currentState.lensDirection}');
      debugPrint('Zoom Range: ${_currentState.minZoom.toStringAsFixed(2)}x - ${_currentState.maxZoom.toStringAsFixed(2)}x');
      debugPrint('Starting Zoom: ${_currentState.zoomLevel.toStringAsFixed(2)}x (widest view)');
      debugPrint('Resolution: ${_currentState.resolution.width.toInt()}x${_currentState.resolution.height.toInt()}');
      debugPrint('FPS: ${_currentState.fps}');
      debugPrint('Torch Support: ${_currentState.torchSupported}');
      debugPrint('═══════════════════════════════════════');
      
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
      rethrow;
    }
  }
  
  Future<void> dispose() async {
    if (_isWebMode) {
      return await _webController!.dispose();
    }
    
    if (_isDisposed) return;
    _isDisposed = true;
    _isInitialized = false;
    
    await _previewSubscription?.cancel();
    await _stateController.close();
    
    try {
      await _channel.invokeMethod('dispose');
      debugPrint('PlatformCameraController disposed');
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    }
  }
  
  Future<void> switchCamera() async {
    if (_isWebMode) {
      return await _webController!.switchCamera();
    }
    
    if (!_isInitialized || _isDisposed) return;
    
    try {
      debugPrint('Switching camera...');
      final result = await _channel.invokeMethod<Map>('switchCamera');
      
      if (result == null) throw Exception('Failed to switch camera');
      
      _currentState = CameraState(
        isInitialized: true,
        cameraIndex: result['cameraIndex'] as int,
        cameraCount: result['cameraCount'] as int,
        zoomLevel: (result['currentZoom'] as num).toDouble(),
        minZoom: (result['minZoom'] as num).toDouble(),
        maxZoom: (result['maxZoom'] as num).toDouble(),
        torchEnabled: result['torchEnabled'] as bool,
        torchSupported: result['torchSupported'] as bool,
        lensDirection: result['lensDirection'] as String,
        resolution: Size(
          (result['width'] as num).toDouble(),
          (result['height'] as num).toDouble(),
        ),
        fps: result['fps'] as int,
      );
      
      _stateController.add(_currentState);
      
      debugPrint('Camera switched to: ${_currentState.lensDirection}');
      debugPrint('Zoom Range: ${_currentState.minZoom.toStringAsFixed(2)}x - ${_currentState.maxZoom.toStringAsFixed(2)}x');
      debugPrint('Torch Support: ${_currentState.torchSupported}');
      
    } catch (e) {
      debugPrint('Failed to switch camera: $e');
      rethrow;
    }
  }
  
  Future<void> setTorch(bool enabled) async {
    if (_isWebMode) {
      return await _webController!.setTorch(enabled);
    }
    
    if (!_isInitialized || _isDisposed) return;
    if (!_currentState.torchSupported) {
      debugPrint('Torch not supported on this camera');
      return;
    }
    
    try {
      await _channel.invokeMethod('setTorch', {'enabled': enabled});
      _currentState = _currentState.copyWith(torchEnabled: enabled);
      _stateController.add(_currentState);
      
      debugPrint('Torch ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      debugPrint('Failed to set torch: $e');
      rethrow;
    }
  }
  
  Future<void> setFlashMode(dynamic flashMode) async {
    // For web, delegate to web controller which handles FlashMode
    if (_isWebMode) {
      return await _webController!.setFlashMode(flashMode);
    }
    
    // For native, convert FlashMode to boolean and use setTorch
    // FlashMode.torch = true, FlashMode.off = false
    if (!_isInitialized || _isDisposed) return;
    
    bool enabled = flashMode.toString() == 'FlashMode.torch';
    return await setTorch(enabled);
  }
  
  Future<void> setZoom(double level) async {
    if (_isWebMode) {
      return await _webController!.setZoom(level);
    }
    
    if (!_isInitialized || _isDisposed) return;
    
    final clampedZoom = level.clamp(_currentState.minZoom, _currentState.maxZoom);
    
    try {
      await _channel.invokeMethod('setZoom', {'level': clampedZoom});
      _currentState = _currentState.copyWith(zoomLevel: clampedZoom);
      _stateController.add(_currentState);
    } catch (e) {
      debugPrint('Failed to set zoom: $e');
    }
  }
  
  Future<void> tapToFocus(double x, double y) async {
    if (_isWebMode) {
      return await _webController!.tapToFocus(x, y);
    }
    
    if (!_isInitialized || _isDisposed) return;
    
    try {
      await _channel.invokeMethod('tapToFocus', {'x': x, 'y': y});
      debugPrint('Focus set to ($x, $y)');
    } catch (e) {
      debugPrint('Failed to set focus: $e');
    }
  }
  
  Future<void> lockExposure(bool lock) async {
    if (_isWebMode) {
      return await _webController!.lockExposure(lock);
    }
    
    if (!_isInitialized || _isDisposed) return;
    
    try {
      await _channel.invokeMethod('lockExposure', {'lock': lock});
      debugPrint('Exposure ${lock ? "locked" : "unlocked"}');
    } catch (e) {
      debugPrint('Failed to lock exposure: $e');
    }
  }
  
  Future<void> startRecording() async {
    if (_isWebMode) {
      return await _webController!.startRecording();
    }
    
    if (!_isInitialized || _isDisposed) return;
    
    try {
      await _channel.invokeMethod('startRecording');
      debugPrint('Recording started');
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      rethrow;
    }
  }
  
  Future<String> stopRecording() async {
    if (_isWebMode) {
      return await _webController!.stopRecording();
    }
    
    if (!_isInitialized || _isDisposed) throw Exception('Camera not initialized');
    
    try {
      final filePath = await _channel.invokeMethod<String>('stopRecording');
      debugPrint('Recording stopped. File: $filePath');
      
      if (filePath == null) throw Exception('No file path returned');
      return filePath;
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
      rethrow;
    }
  }
}

class CameraState {
  final bool isInitialized;
  final int cameraIndex;
  final int cameraCount;
  final double zoomLevel;
  final double minZoom;
  final double maxZoom;
  final bool torchEnabled;
  final bool torchSupported;
  final String lensDirection;
  final Size resolution;
  final int fps;
  
  const CameraState({
    required this.isInitialized,
    required this.cameraIndex,
    required this.cameraCount,
    required this.zoomLevel,
    required this.minZoom,
    required this.maxZoom,
    required this.torchEnabled,
    required this.torchSupported,
    required this.lensDirection,
    required this.resolution,
    required this.fps,
  });
  
  CameraState copyWith({
    bool? isInitialized,
    int? cameraIndex,
    int? cameraCount,
    double? zoomLevel,
    double? minZoom,
    double? maxZoom,
    bool? torchEnabled,
    bool? torchSupported,
    String? lensDirection,
    Size? resolution,
    int? fps,
  }) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      cameraIndex: cameraIndex ?? this.cameraIndex,
      cameraCount: cameraCount ?? this.cameraCount,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      torchEnabled: torchEnabled ?? this.torchEnabled,
      torchSupported: torchSupported ?? this.torchSupported,
      lensDirection: lensDirection ?? this.lensDirection,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
    );
  }
}
