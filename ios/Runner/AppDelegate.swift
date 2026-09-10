import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var iconChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    iconChannel = FlutterMethodChannel(
      name: "app_icon_channel",
      binaryMessenger: messenger
    )
    iconChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.setAlternateIcon(call: call, result: result)
    }
  }

  private func setAlternateIcon(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    // null / NSNull means primary icon
    let rawName = args?["iosName"]
    let iconName: String?
    if rawName == nil || rawName is NSNull {
      iconName = nil
    } else {
      iconName = rawName as? String
    }

    guard UIApplication.shared.supportsAlternateIcons else {
      result(FlutterError(code: "unsupported", message: "Alternate icons not supported", details: nil))
      return
    }

    // Already set
    if UIApplication.shared.alternateIconName == iconName {
      result("ok")
      return
    }

    UIApplication.shared.setAlternateIconName(iconName) { error in
      if let error = error {
        result(FlutterError(code: "icon_switch_failed", message: error.localizedDescription, details: nil))
      } else {
        result("ok")
      }
    }
  }
}
