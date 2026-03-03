import Foundation
import UserNotifications

/// Static handler for displaying notifications while the app is in the foreground.
///
/// iOS suppresses notification banners when the app is active unless
/// `UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)`
/// returns presentation options. This helper provides a static method the host
/// app's existing delegate can call.
///
/// **Important:** iOS allows only ONE `UNUserNotificationCenterDelegate` per app.
/// Do NOT set this as the delegate directly. Instead, call the static method
/// from your existing delegate implementation.
///
/// Example usage in AppDelegate:
/// ```swift
/// class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
///     func application(_ application: UIApplication,
///                      didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
///         UNUserNotificationCenter.current().delegate = self
///         return true
///     }
///
///     func userNotificationCenter(
///         _ center: UNUserNotificationCenter,
///         willPresent notification: UNNotification,
///         withCompletionHandler completionHandler:
///             @escaping (UNNotificationPresentationOptions) -> Void
///     ) {
///         ForegroundNotificationHandler.handleWillPresent(
///             notification: notification,
///             completionHandler: completionHandler
///         )
///     }
/// }
/// ```
public enum ForegroundNotificationHandler {

    /// Call this from your `UNUserNotificationCenterDelegate.willPresent` implementation
    /// to display OpenClix notifications as banners while the app is active.
    public static func handleWillPresent(
        notification: UNNotification,
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
}
