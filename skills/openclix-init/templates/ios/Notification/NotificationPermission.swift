import Foundation
import UserNotifications

/// Result of a notification permission request or status check.
public struct NotificationPermissionResult {
    public let granted: Bool
    public let status: UNAuthorizationStatus
}

/// Utility for requesting and checking notification permissions.
///
/// Usage:
/// ```swift
/// let result = await NotificationPermission.request()
/// if result.granted {
///     // safe to schedule notifications
/// }
/// ```
public enum NotificationPermission {

    /// Request notification permission from the user.
    /// Pass custom options or use the default set (alert, sound, badge).
    public static func request(
        options: UNAuthorizationOptions = [.alert, .sound, .badge]
    ) async -> NotificationPermissionResult {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: options)
            let settings = await center.notificationSettings()
            return NotificationPermissionResult(
                granted: granted,
                status: settings.authorizationStatus
            )
        } catch {
            return NotificationPermissionResult(
                granted: false,
                status: .denied
            )
        }
    }

    /// Check the current notification authorization status without prompting.
    public static func checkStatus() async -> NotificationPermissionResult {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let granted = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        return NotificationPermissionResult(
            granted: granted,
            status: settings.authorizationStatus
        )
    }
}
