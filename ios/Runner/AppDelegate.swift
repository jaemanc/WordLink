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

    FlutterMethodChannel(
      name: "wordlink/settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, reply in
      let defaults = UserDefaults.standard
      switch call.method {
      case "getProgress":
        reply(defaults.string(forKey: "wordlinkProgress"))
      case "setProgress":
        guard let progress = call.arguments as? String else {
          reply(FlutterError(code: "progress", message: "Invalid progress", details: nil))
          return
        }
        defaults.set(progress, forKey: "wordlinkProgress")
        reply(nil)
      case "getLanguage":
        reply(defaults.string(forKey: "wordlinkLanguage"))
      case "setLanguage":
        guard let language = call.arguments as? String, ["ko", "en"].contains(language) else {
          reply(FlutterError(code: "language", message: "Unsupported language", details: nil))
          return
        }
        defaults.set(language, forKey: "wordlinkLanguage")
        reply(nil)
      default:
        reply(FlutterMethodNotImplemented)
      }
    }

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
