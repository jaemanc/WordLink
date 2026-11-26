import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var impactPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let asset = FlutterDartProject.lookupKey(forAsset: "assets/craft_impact.wav")
    if let url = Bundle.main.url(forResource: asset, withExtension: nil) {
      try? AVAudioSession.sharedInstance().setCategory(.ambient)
      impactPlayer = try? AVAudioPlayer(contentsOf: url)
      impactPlayer?.prepareToPlay()
    }

    FlutterMethodChannel(
      name: "wordlink/impact",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { [weak self] call, reply in
      guard call.method == "play", let player = self?.impactPlayer else {
        reply(FlutterMethodNotImplemented)
        return
      }
      player.volume = (call.arguments as? Bool == true) ? 1 : 0.75
      player.currentTime = 0
      player.play()
      reply(nil)
    }
  }
}
