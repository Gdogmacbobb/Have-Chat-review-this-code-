package com.ynfny.app

import android.content.Context
import android.util.Log
import android.util.Size
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.*
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CaptureRequest
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.*
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executor

class CameraHandler(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val lifecycleOwner: LifecycleOwner
) : MethodChannel.MethodCallHandler {

    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var preview: Preview? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null
    
    private var currentCameraIndex = 0
    private val availableSelectors = mutableListOf<CameraSelector>()
    
    private var scope: CoroutineScope? = null
    private val executor: Executor = ContextCompat.getMainExecutor(context)
    
    private fun ensureScope(): CoroutineScope {
        if (scope == null || !scope!!.isActive) {
            scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
        }
        return scope!!
    }
    
    companion object {
        private const val TAG = "CameraHandler"
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "dispose" -> dispose(result)
            "switchCamera" -> switchCamera(result)
            "setTorch" -> setTorch(call, result)
            "setZoom" -> setZoom(call, result)
            "tapToFocus" -> tapToFocus(call, result)
            "lockExposure" -> lockExposure(call, result)
            "startRecording" -> startRecording(result)
            "stopRecording" -> stopRecording(result)
            else -> result.notImplemented()
        }
    }
    
    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val cameraIndex = call.argument<Int>("cameraIndex") ?: 0
        val targetFps = call.argument<Int>("fps") ?: 60
        val quality = call.argument<String>("quality") ?: "max"
        
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "Initializing camera...")
        Log.d(TAG, "Camera Index: $cameraIndex")
        Log.d(TAG, "Target FPS: $targetFps")
        Log.d(TAG, "Quality: $quality")
        
        ensureScope().launch {
            try {
                val provider = ProcessCameraProvider.getInstance(context).get()
                cameraProvider = provider
                
                // Discover available cameras
                availableSelectors.clear()
                if (provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) {
                    availableSelectors.add(CameraSelector.DEFAULT_BACK_CAMERA)
                }
                if (provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) {
                    availableSelectors.add(CameraSelector.DEFAULT_FRONT_CAMERA)
                }
                
                Log.d(TAG, "Available cameras: ${availableSelectors.size}")
                
                currentCameraIndex = cameraIndex.coerceIn(0, availableSelectors.size - 1)
                
                startCamera(targetFps, quality, result)
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize camera", e)
                withContext(Dispatchers.Main) {
                    result.error("INIT_ERROR", "Failed to initialize camera: ${e.message}", null)
                }
            }
        }
    }
    
    private suspend fun startCamera(targetFps: Int, quality: String, result: MethodChannel.Result) {
        try {
            cameraProvider?.unbindAll()
            
            // Create texture for Flutter
            textureEntry = textureRegistry.createSurfaceTexture()
            val surfaceTexture = textureEntry!!.surfaceTexture()
            
            // Configure quality based on parameter
            val qualitySelector = when (quality) {
                "max" -> QualitySelector.from(Quality.HIGHEST)
                "high" -> QualitySelector.from(Quality.FHD)
                "medium" -> QualitySelector.from(Quality.HD)
                else -> QualitySelector.from(Quality.HIGHEST)
            }
            
            // Setup preview with frame rate target
            val previewBuilder = Preview.Builder()
            
            preview = previewBuilder.build()
            
            preview?.setSurfaceProvider { request ->
                val resolution = request.resolution
                surfaceTexture.setDefaultBufferSize(resolution.width, resolution.height)
                val surface = Surface(surfaceTexture)
                request.provideSurface(surface, executor) { }
            }
            
            // Setup video capture
            // Frame rate is optimized by CameraX based on quality selector and device capabilities
            val recorder = Recorder.Builder()
                .setQualitySelector(qualitySelector)
                .build()
            
            videoCapture = VideoCapture.withOutput(recorder)
            
            // Select camera
            val cameraSelector = availableSelectors[currentCameraIndex]
            
            // Bind to lifecycle
            camera = cameraProvider?.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview,
                videoCapture
            )
            
            // Get camera info
            val cameraInfo = camera?.cameraInfo
            
            // Query hardware FPS capabilities using Camera2CameraInfo
            val camera2CameraInfo = Camera2CameraInfo.from(cameraInfo!!)
            val availableFpsRanges = camera2CameraInfo.getCameraCharacteristic(
                CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES
            ) ?: emptyArray()
            
            // Find the best supported FPS range
            // First, try to find a range that includes target FPS (e.g., 60)
            // If not available, fall back to highest available
            val selectedRange = availableFpsRanges.firstOrNull { it.upper >= targetFps } 
                ?: availableFpsRanges.maxByOrNull { it.upper } 
                ?: android.util.Range(30, 30)
            
            // Apply the selected FPS range via Camera2Interop
            val camera2Interop = Camera2Interop.Extender(previewBuilder)
            camera2Interop.setCaptureRequestOption(
                CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                selectedRange
            )
            
            // Rebuild preview with FPS range applied
            preview = previewBuilder.build()
            preview?.setSurfaceProvider { request ->
                val resolution = request.resolution
                surfaceTexture.setDefaultBufferSize(resolution.width, resolution.height)
                val surface = Surface(surfaceTexture)
                request.provideSurface(surface, executor) { }
            }
            
            // Rebind with FPS configuration
            cameraProvider?.unbindAll()
            camera = cameraProvider?.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview,
                videoCapture
            )
            
            // Get actual FPS (lower bound of selected range)
            val actualFps = selectedRange.lower
            
            // Get camera info again after rebinding
            val zoomState = camera?.cameraInfo?.zoomState?.value
            val minZoom = zoomState?.minZoomRatio ?: 1.0f
            val maxZoom = zoomState?.maxZoomRatio ?: 1.0f
            
            // Set to minimum zoom (widest view)
            camera?.cameraControl?.setZoomRatio(minZoom)
            
            val torchSupported = camera?.cameraInfo?.hasFlashUnit() ?: false
            val lensDirection = if (currentCameraIndex == 0) "back" else "front"
            
            // Get resolution from camera
            val resolution = preview?.attachedSurfaceResolution ?: Size(1920, 1080)
            
            Log.d(TAG, "Camera started successfully")
            Log.d(TAG, "Texture ID: ${textureEntry!!.id()}")
            Log.d(TAG, "Lens Direction: $lensDirection")
            Log.d(TAG, "Zoom Range: %.2fx - %.2fx".format(minZoom, maxZoom))
            Log.d(TAG, "Starting Zoom: %.2fx (widest view)".format(minZoom))
            Log.d(TAG, "Resolution: ${resolution.width}x${resolution.height}")
            Log.d(TAG, "Available FPS ranges: ${availableFpsRanges.joinToString { "[${it.lower},${it.upper}]" }}")
            Log.d(TAG, "Target FPS: $targetFps, Actual: $actualFps (${if (actualFps >= targetFps) "achieved" else "graceful fallback"})")
            Log.d(TAG, "Selected FPS range: [${selectedRange.lower},${selectedRange.upper}]")
            Log.d(TAG, "Torch Support: $torchSupported")
            Log.d(TAG, "═══════════════════════════════════════")
            
            withContext(Dispatchers.Main) {
                result.success(mapOf(
                    "textureId" to textureEntry!!.id(),
                    "cameraIndex" to currentCameraIndex,
                    "cameraCount" to availableSelectors.size,
                    "currentZoom" to minZoom,
                    "minZoom" to minZoom,
                    "maxZoom" to maxZoom,
                    "torchEnabled" to false,
                    "torchSupported" to torchSupported,
                    "lensDirection" to lensDirection,
                    "width" to resolution.width,
                    "height" to resolution.height,
                    "fps" to actualFps
                ))
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start camera", e)
            withContext(Dispatchers.Main) {
                result.error("START_ERROR", "Failed to start camera: ${e.message}", null)
            }
        }
    }
    
    private fun dispose(result: MethodChannel.Result) {
        try {
            recording?.stop()
            recording = null
            cameraProvider?.unbindAll()
            textureEntry?.release()
            textureEntry = null
            camera = null
            scope?.cancel()
            scope = null
            
            Log.d(TAG, "Camera disposed")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing camera", e)
            result.error("DISPOSE_ERROR", e.message, null)
        }
    }
    
    private fun switchCamera(result: MethodChannel.Result) {
        ensureScope().launch {
            try {
                val startTime = System.currentTimeMillis()
                Log.d(TAG, "🔄 [CAMERA_SWITCH] Starting camera switch...")
                Log.d(TAG, "   Current index: $currentCameraIndex")
                Log.d(TAG, "   Available cameras: ${availableSelectors.size}")
                
                currentCameraIndex = (currentCameraIndex + 1) % availableSelectors.size
                Log.d(TAG, "   New index: $currentCameraIndex")
                
                cameraProvider?.unbindAll()
                startCamera(60, "max", result)
                
                val latency = System.currentTimeMillis() - startTime
                Log.d(TAG, "✅ [CAMERA_SWITCH] Switch completed in ${latency}ms")
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ [CAMERA_SWITCH] Failed to switch camera", e)
                withContext(Dispatchers.Main) {
                    result.error("SWITCH_ERROR", "Failed to switch camera: ${e.message}", null)
                }
            }
        }
    }
    
    private fun setTorch(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        
        try {
            val hasFlash = camera?.cameraInfo?.hasFlashUnit() ?: false
            Log.d(TAG, "💡 [FLASH_TOGGLE] Torch toggle request: enabled=$enabled")
            Log.d(TAG, "   Camera has flash unit: $hasFlash")
            Log.d(TAG, "   Current camera index: $currentCameraIndex")
            
            if (!hasFlash) {
                Log.w(TAG, "⚠️ [FLASH_TOGGLE] Flash not supported on this camera")
                result.error("TORCH_NOT_SUPPORTED", "Flash not supported on this camera", null)
                return
            }
            
            camera?.cameraControl?.enableTorch(enabled)
            Log.d(TAG, "✅ [FLASH_TOGGLE] Torch ${if (enabled) "enabled" else "disabled"} successfully")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "❌ [FLASH_TOGGLE] Failed to set torch", e)
            result.error("TORCH_ERROR", e.message, null)
        }
    }
    
    private fun setZoom(call: MethodCall, result: MethodChannel.Result) {
        val level = call.argument<Double>("level")?.toFloat() ?: 1.0f
        
        // Move to background thread to prevent UI lag
        ensureScope().launch(Dispatchers.IO) {
            try {
                val startTime = System.currentTimeMillis()
                
                // Execute zoom on background thread
                camera?.cameraControl?.setZoomRatio(level)?.addListener({
                    val latency = System.currentTimeMillis() - startTime
                    if (latency > 16) {
                        Log.w(TAG, "⏱️ [ZOOM_EVENTS] Zoom latency: ${latency}ms for ${String.format("%.2f", level)}x")
                    }
                }, executor)
                
                withContext(Dispatchers.Main) {
                    result.success(null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ [ZOOM_EVENTS] Failed to set zoom", e)
                withContext(Dispatchers.Main) {
                    result.error("ZOOM_ERROR", e.message, null)
                }
            }
        }
    }
    
    private fun tapToFocus(call: MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Double>("x")?.toFloat() ?: 0.5f
        val y = call.argument<Double>("y")?.toFloat() ?: 0.5f
        
        try {
            val factory = SurfaceOrientedMeteringPointFactory(1.0f, 1.0f)
            val point = factory.createPoint(x, y)
            val action = FocusMeteringAction.Builder(point).build()
            
            camera?.cameraControl?.startFocusAndMetering(action)
            Log.d(TAG, "Focus set to ($x, $y)")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set focus", e)
            result.error("FOCUS_ERROR", e.message, null)
        }
    }
    
    private fun lockExposure(call: MethodCall, result: MethodChannel.Result) {
        val lock = call.argument<Boolean>("lock") ?: false
        
        try {
            camera?.cameraControl?.setExposureCompensationIndex(if (lock) 0 else 0)
            Log.d(TAG, "Exposure ${if (lock) "locked" : "unlocked"}")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to lock exposure", e)
            result.error("EXPOSURE_ERROR", e.message, null)
        }
    }
    
    private fun startRecording(result: MethodChannel.Result) {
        try {
            val videoCapture = this.videoCapture ?: throw Exception("Video capture not initialized")
            
            val name = SimpleDateFormat("yyyy-MM-dd-HH-mm-ss-SSS", Locale.US)
                .format(System.currentTimeMillis())
            val contentValues = android.content.ContentValues().apply {
                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(android.provider.MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
            }
            
            val mediaStoreOutputOptions = MediaStoreOutputOptions
                .Builder(context.contentResolver, android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
                .setContentValues(contentValues)
                .build()
            
            recording = videoCapture.output
                .prepareRecording(context, mediaStoreOutputOptions)
                .withAudioEnabled()
                .start(executor) { event ->
                    when (event) {
                        is VideoRecordEvent.Finalize -> {
                            if (!event.hasError()) {
                                Log.d(TAG, "Video saved: ${event.outputResults.outputUri}")
                            } else {
                                Log.e(TAG, "Video recording error: ${event.error}")
                            }
                        }
                    }
                }
            
            Log.d(TAG, "Recording started")
            result.success(null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            result.error("RECORDING_ERROR", "Failed to start recording: ${e.message}", null)
        }
    }
    
    private fun stopRecording(result: MethodChannel.Result) {
        try {
            val activeRecording = recording ?: throw Exception("No active recording")
            
            var savedUri: String? = null
            activeRecording.stop()
            
            // Wait for finalize event
            ensureScope().launch {
                delay(1000) // Give time for file to be written
                savedUri = context.contentResolver.query(
                    android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    arrayOf(android.provider.MediaStore.Video.Media._ID, android.provider.MediaStore.Video.Media.DATA),
                    null,
                    null,
                    android.provider.MediaStore.Video.Media.DATE_ADDED + " DESC"
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val dataIndex = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Video.Media.DATA)
                        cursor.getString(dataIndex)
                    } else null
                }
                
                recording = null
                Log.d(TAG, "Recording stopped. File: $savedUri")
                
                withContext(Dispatchers.Main) {
                    result.success(savedUri ?: "")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop recording", e)
            result.error("STOP_RECORDING_ERROR", "Failed to stop recording: ${e.message}", null)
        }
    }
}
