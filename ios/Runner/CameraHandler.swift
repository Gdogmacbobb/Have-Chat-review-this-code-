import Flutter
import UIKit
import AVFoundation

class CameraHandler: NSObject, FlutterMethodCallHandler {
    
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var textureRegistry: FlutterTextureRegistry
    private var textureId: Int64?
    
    private var currentCameraIndex = 0
    private var availableCameras: [AVCaptureDevice] = []
    private var isRecording = false
    private var recordingURL: URL?
    
    init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        super.init()
        
        discoverCameras()
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call, result: result)
        case "dispose":
            dispose(result: result)
        case "switchCamera":
            switchCamera(result: result)
        case "setTorch":
            setTorch(call, result: result)
        case "setZoom":
            setZoom(call, result: result)
        case "tapToFocus":
            tapToFocus(call, result: result)
        case "lockExposure":
            lockExposure(call, result: result)
        case "startRecording":
            startRecording(result: result)
        case "stopRecording":
            stopRecording(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func discoverCameras() {
        availableCameras.removeAll()
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .unspecified
        )
        
        availableCameras = discoverySession.devices
        print("Discovered \(availableCameras.count) cameras")
    }
    
    private func initialize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        let cameraIndex = args["cameraIndex"] as? Int ?? 0
        let targetFps = args["fps"] as? Int ?? 60
        let quality = args["quality"] as? String ?? "max"
        
        print("═══════════════════════════════════════")
        print("Initializing camera...")
        print("Camera Index: \(cameraIndex)")
        print("Target FPS: \(targetFps)")
        print("Quality: \(quality)")
        
        currentCameraIndex = min(cameraIndex, availableCameras.count - 1)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.startCamera(targetFps: targetFps, quality: quality) { cameraInfo in
                    DispatchQueue.main.async {
                        result(cameraInfo)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INIT_ERROR", message: "Failed to initialize camera: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }
    
    private func startCamera(targetFps: Int, quality: String, completion: @escaping ([String: Any]) -> Void) throws {
        
        guard currentCameraIndex < availableCameras.count else {
            throw NSError(domain: "CameraHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid camera index"])
        }
        
        // Clean up existing session
        captureSession?.stopRunning()
        captureSession = nil
        
        // Create new session
        let session = AVCaptureSession()
        
        // Set quality preset
        switch quality {
        case "max":
            if session.canSetSessionPreset(.hd4K3840x2160) {
                session.sessionPreset = .hd4K3840x2160
            } else if session.canSetSessionPreset(.hd1920x1080) {
                session.sessionPreset = .hd1920x1080
            } else {
                session.sessionPreset = .high
            }
        case "high":
            session.sessionPreset = .hd1920x1080
        case "medium":
            session.sessionPreset = .hd1280x720
        default:
            session.sessionPreset = .high
        }
        
        // Get camera device
        videoDevice = availableCameras[currentCameraIndex]
        
        guard let device = videoDevice else {
            throw NSError(domain: "CameraHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera device not found"])
        }
        
        // Configure device
        try device.lockForConfiguration()
        
        // Set frame rate
        if let format = device.activeFormat.videoSupportedFrameRateRanges.first {
            let fps = Double(min(targetFps, Int(format.maxFrameRate)))
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        }
        
        // Set zoom to minimum (widest view)
        let minZoom = device.minAvailableVideoZoomFactor
        device.videoZoomFactor = minZoom
        
        // Enable video stabilization if available
        if device.activeFormat.isVideoStabilizationModeSupported(.auto) {
            // Will be set on connection
        }
        
        device.unlockForConfiguration()
        
        // Capture actual achieved FPS after configuration
        let actualFrameDuration = device.activeVideoMinFrameDuration
        let actualFps = actualFrameDuration.seconds > 0 
            ? Int(1.0 / actualFrameDuration.seconds) 
            : targetFps
        
        // Add video input
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }
        
        // Add video output
        let output = AVCaptureVideoDataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            videoOutput = output
            
            // Enable video stabilization on connection
            if let connection = output.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }
        
        // Add movie output for recording
        let movieOut = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOut) {
            session.addOutput(movieOut)
            movieOutput = movieOut
        }
        
        captureSession = session
        
        // Start session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        // Get camera info
        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor
        let currentZoom = device.videoZoomFactor
        let torchSupported = device.hasTorch
        let lensDirection = device.position == .back ? "back" : "front"
        
        // Get resolution
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)
        
        print("Camera started successfully")
        print("Lens Direction: \(lensDirection)")
        print("Zoom Range: \(String(format: "%.2f", minZoom))x - \(String(format: "%.2f", maxZoom))x")
        print("Starting Zoom: \(String(format: "%.2f", minZoom))x (widest view)")
        print("Resolution: \(width)x\(height)")
        print("Torch Support: \(torchSupported)")
        print("Target FPS: \(targetFps), Actual: \(actualFps)\(actualFps < targetFps ? " (graceful fallback)" : "")")
        print("═══════════════════════════════════════")
        
        // Create texture (mock for now - in production, you'd render the preview to a texture)
        let textureId = Int64(arc4random())
        self.textureId = textureId
        
        completion([
            "textureId": textureId,
            "cameraIndex": currentCameraIndex,
            "cameraCount": availableCameras.count,
            "currentZoom": currentZoom,
            "minZoom": minZoom,
            "maxZoom": maxZoom,
            "torchEnabled": false,
            "torchSupported": torchSupported,
            "lensDirection": lensDirection,
            "width": width,
            "height": height,
            "fps": actualFps
        ])
    }
    
    private func dispose(result: @escaping FlutterResult) {
        captureSession?.stopRunning()
        captureSession = nil
        videoDevice = nil
        videoInput = nil
        videoOutput = nil
        movieOutput = nil
        previewLayer = nil
        
        print("Camera disposed")
        result(nil)
    }
    
    private func switchCamera(result: @escaping FlutterResult) {
        print("Switching camera...")
        
        currentCameraIndex = (currentCameraIndex + 1) % availableCameras.count
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.startCamera(targetFps: 60, quality: "max") { cameraInfo in
                    DispatchQueue.main.async {
                        result(cameraInfo)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SWITCH_ERROR", message: "Failed to switch camera: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }
    
    private func setTorch(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let device = videoDevice, device.hasTorch else {
            print("Torch not supported on this camera")
            result(nil)
            return
        }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
            
            print("Torch \(enabled ? "enabled" : "disabled")")
            result(nil)
        } catch {
            result(FlutterError(code: "TORCH_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func setZoom(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let level = args["level"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let device = videoDevice else {
            result(nil)
            return
        }
        
        do {
            try device.lockForConfiguration()
            let clampedZoom = min(max(CGFloat(level), device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.videoZoomFactor = clampedZoom
            device.unlockForConfiguration()
            
            result(nil)
        } catch {
            result(FlutterError(code: "ZOOM_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func tapToFocus(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let x = args["x"] as? Double,
              let y = args["y"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let device = videoDevice else {
            result(nil)
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: x, y: y)
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: x, y: y)
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            
            print("Focus set to (\(x), \(y))")
            result(nil)
        } catch {
            result(FlutterError(code: "FOCUS_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func lockExposure(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lock = args["lock"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        guard let device = videoDevice else {
            result(nil)
            return
        }
        
        do {
            try device.lockForConfiguration()
            device.exposureMode = lock ? .locked : .autoExpose
            device.unlockForConfiguration()
            
            print("Exposure \(lock ? "locked" : "unlocked")")
            result(nil)
        } catch {
            result(FlutterError(code: "EXPOSURE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func startRecording(result: @escaping FlutterResult) {
        guard let movieOutput = movieOutput, !isRecording else {
            result(FlutterError(code: "RECORDING_ERROR", message: "Already recording or output not available", details: nil))
            return
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "video_\(Date().timeIntervalSince1970).mov"
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        recordingURL = fileURL
        
        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        isRecording = true
        
        print("Recording started")
        result(nil)
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        guard let movieOutput = movieOutput, isRecording else {
            result(FlutterError(code: "STOP_RECORDING_ERROR", message: "Not recording", details: nil))
            return
        }
        
        movieOutput.stopRecording()
        isRecording = false
        
        // Result will be returned in delegate callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let url = self?.recordingURL {
                print("Recording stopped. File: \(url.path)")
                result(url.path)
            } else {
                result("")
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraHandler: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error.localizedDescription)")
        } else {
            print("Video saved: \(outputFileURL.path)")
        }
    }
}
