import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class ThumbnailFrameExtractor {
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement;
  bool _isInitialized = false;
  String _debugStatus = '';
  String _cameraDirection = 'back'; // 'front' or 'back'
  double _orientationRadians = 0.0; // Calculated orientation from video metadata
  
  String get debugStatus => _debugStatus;
  bool get isInitialized => _isInitialized;

  Future<void> initializeVideo(String videoUrl, {String cameraDirection = 'back', double orientationRadians = 0.0}) async {
    _cameraDirection = cameraDirection;
    _orientationRadians = orientationRadians;
    if (kDebugMode) print('[CAMERA_META] Thumbnail extractor initialized for $_cameraDirection camera, orientation=${(orientationRadians * 180 / 3.14159).round()}°');
    try {
      _debugStatus = '[THUMB] Initializing video...';
      debugPrint(_debugStatus);

      _videoElement = html.VideoElement()
        ..src = videoUrl
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..setAttribute('preload', 'auto')
        ..style.display = 'none';

      html.document.body?.append(_videoElement!);

      final completer = Completer<void>();
      
      _videoElement!.onLoadedMetadata.listen((event) {
        _debugStatus = '[THUMB] Video metadata loaded';
        debugPrint(_debugStatus);
        completer.complete();
      });

      _videoElement!.onError.listen((event) {
        _debugStatus = '[THUMB] Video load error';
        debugPrint(_debugStatus);
        if (!completer.isCompleted) {
          completer.completeError('Failed to load video');
        }
      });

      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Video metadata load timeout');
        },
      );

      await _videoElement!.play();
      await Future.delayed(const Duration(milliseconds: 100));
      _videoElement!.pause();

      _debugStatus = '[THUMB] readyState=${_videoElement!.readyState}';
      debugPrint(_debugStatus);

      _isInitialized = true;
      _debugStatus = '[THUMB] Initialization complete';
      debugPrint(_debugStatus);
    } catch (e) {
      _debugStatus = '[THUMB] Init failed: $e';
      debugPrint(_debugStatus);
      rethrow;
    }
  }

  Future<Uint8List?> captureFrameAtPosition(double seconds) async {
    if (!_isInitialized || _videoElement == null) {
      _debugStatus = '[THUMB] Not initialized';
      debugPrint(_debugStatus);
      return null;
    }

    try {
      _debugStatus = '[THUMB] Seeking to ${seconds.toStringAsFixed(2)}s';
      debugPrint(_debugStatus);

      await _seekToPosition(seconds);

      if (_videoElement!.readyState < 2) {
        _debugStatus = '[THUMB] Video not ready, readyState=${_videoElement!.readyState}';
        debugPrint(_debugStatus);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final videoWidth = _videoElement!.videoWidth;
      final videoHeight = _videoElement!.videoHeight;

      if (videoWidth == 0 || videoHeight == 0) {
        _debugStatus = '[THUMB] Invalid video dimensions: ${videoWidth}x${videoHeight}';
        debugPrint(_debugStatus);
        return null;
      }

      final isFrontCamera = _cameraDirection == 'front';
      
      // Use the orientation passed from video metadata analysis
      final double rotationAngle = _orientationRadians;
      
      if (kDebugMode) {
        print('[VIDEO_META] Camera=$_cameraDirection, Video=${videoWidth}x${videoHeight}, OrientationAngle=${(rotationAngle * 180 / 3.14159).round()}°');
      }

      // Simple approach: Canvas dimensions match video dimensions
      // If rotation is applied, dimensions will swap naturally via canvas transform
      int canvasWidth = videoWidth;
      int canvasHeight = videoHeight;
      
      // Only swap canvas dimensions if we're applying a 90° or 270° rotation
      final isNinetyDegreeRotation = (rotationAngle.abs() - 1.5708).abs() < 0.1 || 
                                      (rotationAngle.abs() - 4.7124).abs() < 0.1; // 90° or 270°
      
      if (isNinetyDegreeRotation) {
        // Swap canvas dimensions to account for rotation
        final temp = canvasWidth;
        canvasWidth = canvasHeight;
        canvasHeight = temp;
        if (kDebugMode) {
          print('[CANVAS_DIMS] Swapped canvas for ${(rotationAngle * 180 / 3.14159).round()}° rotation: ${canvasWidth}x${canvasHeight}');
        }
      } else {
        if (kDebugMode) {
          print('[CANVAS_DIMS] Canvas matches video: ${canvasWidth}x${canvasHeight}');
        }
      }

      _canvasElement = html.CanvasElement(width: canvasWidth, height: canvasHeight);
      final context = _canvasElement!.context2D;

      context.save();

      // Apply rotation if needed
      if (rotationAngle.abs() > 0.01) {
        // Center the canvas, apply rotation, draw video
        context.translate(canvasWidth / 2, canvasHeight / 2);
        context.rotate(rotationAngle);
        
        if (kDebugMode) print('[THUMB_ROTATE] ${isFrontCamera ? "Front" : "Rear"} camera: ${(rotationAngle * 180 / 3.14159).round()}° rotation');
        
        // Draw video centered at origin (no flip - match video playback orientation)
        context.drawImageScaled(_videoElement!, -videoWidth / 2, -videoHeight / 2, videoWidth, videoHeight);
      } else {
        // No rotation - just draw directly
        if (kDebugMode) print('[THUMB_ROTATE] ${isFrontCamera ? "Front" : "Rear"} camera: No rotation needed - drawing directly');
        
        // Draw directly without any flip to match video playback
        context.drawImageScaled(_videoElement!, 0, 0, canvasWidth, canvasHeight);
      }
      
      context.restore();
      
      if (kDebugMode) {
        print('[THUMB_OK] ✅ Canvas=${canvasWidth}x${canvasHeight} (portrait 9:16), Rotation=${(rotationAngle * 180 / 3.14159).round()}°');
      }
      
      _debugStatus = '[THUMB] drawImage success (${canvasWidth}x${canvasHeight})';
      debugPrint(_debugStatus);

      final blob = await _canvasElement!.toBlob('image/jpeg', 0.85);
      final reader = html.FileReader();
      
      final completer = Completer<Uint8List>();
      reader.onLoadEnd.listen((event) {
        final result = reader.result as Uint8List;
        _debugStatus = '[THUMB] Blob bytes=${(result.length / 1024).toStringAsFixed(1)} KB';
        debugPrint(_debugStatus);
        completer.complete(result);
      });

      reader.onError.listen((event) {
        _debugStatus = '[THUMB] Blob read error';
        debugPrint(_debugStatus);
        completer.completeError('Failed to read blob');
      });

      reader.readAsArrayBuffer(blob);
      return await completer.future;
    } catch (e) {
      _debugStatus = '[THUMB] Capture failed: $e';
      debugPrint(_debugStatus);
      return null;
    }
  }

  Future<void> _seekToPosition(double seconds) async {
    final completer = Completer<void>();
    
    void onSeeked(html.Event event) {
      _debugStatus = '[THUMB] Seeked to ${_videoElement!.currentTime.toStringAsFixed(2)}s';
      debugPrint(_debugStatus);
      completer.complete();
    }

    _videoElement!.onSeeked.listen(onSeeked).onData((event) {
      if (!completer.isCompleted) {
        onSeeked(event);
      }
    });

    _videoElement!.currentTime = seconds;

    await completer.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {
        _debugStatus = '[THUMB] Seek timeout, continuing anyway';
        debugPrint(_debugStatus);
      },
    );
  }

  void dispose() {
    _debugStatus = '[THUMB] Disposing resources';
    debugPrint(_debugStatus);
    
    _videoElement?.remove();
    _videoElement = null;
    _canvasElement = null;
    _isInitialized = false;
  }
}
