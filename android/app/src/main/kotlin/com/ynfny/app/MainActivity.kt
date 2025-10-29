package com.ynfny.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CAMERA_CHANNEL = "com.ynfny/camera"
    private var cameraHandler: CameraHandler? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        cameraHandler = CameraHandler(
            context = this,
            textureRegistry = flutterEngine.renderer,
            lifecycleOwner = this
        )
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL).apply {
            setMethodCallHandler(cameraHandler)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        cameraHandler = null
    }
}
