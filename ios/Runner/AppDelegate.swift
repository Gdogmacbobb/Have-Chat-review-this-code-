import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var cameraHandler: CameraHandler?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let cameraChannel = FlutterMethodChannel(name: "com.ynfny/camera",
                                                  binaryMessenger: controller.binaryMessenger)
        
        cameraHandler = CameraHandler(textureRegistry: controller.engine!.textureRegistry)
        cameraChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.cameraHandler?.handle(call, result: result)
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
