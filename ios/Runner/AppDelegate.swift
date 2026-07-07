import Flutter
import UIKit
import Firebase
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // CRITICAL: Set the UNUserNotificationCenter delegate to self (AppDelegate).
    // FlutterAppDelegate already conforms to UNUserNotificationCenterDelegate.
    // This MUST be set before the app finishes launching so foreground
    // notifications are received and displayed (like WhatsApp behaviour).
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // Register for remote (APNs) notifications
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Foreground Notification Presentation (iOS 10+)
  // This tells iOS to SHOW the notification banner even when the app is in foreground.
  // Without this, notifications are silently delivered on iOS (no banner/sound/badge).
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show banner + play sound + update badge even while app is open (WhatsApp-style)
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // MARK: - Notification Tap Handler
  // Called when user taps a notification (foreground or background).
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
