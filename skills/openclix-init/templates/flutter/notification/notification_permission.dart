/// Callback to request notification permission from the user.
/// Returns `true` if permission was granted.
typedef RequestPermissionCallback = Future<bool> Function();

/// Callback to check current notification permission status
/// without prompting the user. Returns `true` if granted.
typedef CheckPermissionStatusCallback = Future<bool> Function();

/// Callback to configure foreground notification display.
/// Should set up the notification plugin to show banners/alerts
/// while the app is in the foreground.
typedef SetupForegroundHandlerCallback = void Function();

/// Wraps platform-specific notification permission and foreground display
/// callbacks. The host app provides concrete implementations that delegate
/// to the notification plugin already in use (e.g. flutter_local_notifications,
/// firebase_messaging).
///
/// Example usage:
/// ```dart
/// final permission = NotificationPermission(
///   requestPermission: () async {
///     // call your notification plugin's permission request
///     return true;
///   },
///   checkPermissionStatus: () async {
///     // check current permission status
///     return true;
///   },
///   setupForegroundHandler: () {
///     // configure foreground notification display
///   },
/// );
///
/// final granted = await permission.request();
/// if (granted) {
///   permission.setupForeground();
/// }
/// ```
class NotificationPermission {
  final RequestPermissionCallback requestPermission;
  final CheckPermissionStatusCallback checkPermissionStatus;
  final SetupForegroundHandlerCallback? setupForegroundHandler;

  NotificationPermission({
    required this.requestPermission,
    required this.checkPermissionStatus,
    this.setupForegroundHandler,
  });

  /// Request notification permission. Returns `true` if granted.
  Future<bool> request() async {
    return requestPermission();
  }

  /// Check current permission status without prompting.
  Future<bool> checkStatus() async {
    return checkPermissionStatus();
  }

  /// Configure foreground notification display if a handler was provided.
  void setupForeground() {
    setupForegroundHandler?.call();
  }
}
