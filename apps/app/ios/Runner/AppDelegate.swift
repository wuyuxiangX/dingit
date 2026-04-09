import Flutter
import UIKit
import FirebaseCore
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var badgeChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Explicitly register for remote notifications
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Register method channel for badge control from Dart.
    // The implicit engine's applicationRegistrar exposes the engine's
    // FlutterBinaryMessenger, which is available before the Flutter view
    // controller mounts (so Dart calls from initState work).
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: "com.dingit.badge",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleBadgeCall(call, result: result)
    }
    badgeChannel = channel
    print("[Badge] MethodChannel com.dingit.badge registered")
  }

  private func handleBadgeCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setBadgeCount" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any]
    let count = args?["count"] as? Int ?? 0
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(count) { error in
        if let error = error {
          print("[Badge] setBadgeCount(\(count)) failed: \(error)")
          result(FlutterError(code: "badge_error", message: "\(error)", details: nil))
        } else {
          result(nil)
        }
      }
    } else {
      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = count
        result(nil)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    // Clear badge when app comes to foreground (fallback; Dart's _syncBadge
    // will set the authoritative value right after).
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0) { error in
        if let error = error {
          print("[Badge] Failed to clear: \(error)")
        }
      }
    } else {
      application.applicationIconBadgeNumber = 0
    }
  }
}
