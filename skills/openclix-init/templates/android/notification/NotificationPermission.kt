package ai.openclix.notification

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/**
 * Permission status for notifications.
 */
enum class NotificationPermissionStatus {
    /** Permission is granted (or not required on API < 33). */
    GRANTED,
    /** Permission was denied by the user. */
    DENIED,
    /** Permission is not required on this API level (< 33). */
    NOT_REQUIRED
}

/**
 * Utility for checking notification permission on Android 13+ (API 33).
 *
 * On API < 33, notifications do not require runtime permission, so
 * [checkStatus] returns [NotificationPermissionStatus.NOT_REQUIRED].
 *
 * This class does NOT launch the permission request dialog. The host
 * Activity must use [getPermissionString] with its own
 * `ActivityResultLauncher<String>` or `requestPermissions()` call.
 *
 * Example usage in an Activity:
 * ```kotlin
 * if (NotificationPermission.shouldRequestPermission(this)) {
 *     val permission = NotificationPermission.getPermissionString()!!
 *     requestPermissions(arrayOf(permission), REQUEST_CODE)
 * }
 * ```
 */
object NotificationPermission {

    private const val POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"

    /**
     * Check the current notification permission status.
     */
    fun checkStatus(context: Context): NotificationPermissionStatus {
        if (Build.VERSION.SDK_INT < 33) {
            return NotificationPermissionStatus.NOT_REQUIRED
        }
        val result = context.checkPermission(
            POST_NOTIFICATIONS,
            android.os.Process.myPid(),
            android.os.Process.myUid()
        )
        return if (result == PackageManager.PERMISSION_GRANTED) {
            NotificationPermissionStatus.GRANTED
        } else {
            NotificationPermissionStatus.DENIED
        }
    }

    /**
     * Returns `true` if the app is running on API 33+ and notification
     * permission has not yet been granted.
     */
    fun shouldRequestPermission(context: Context): Boolean {
        return checkStatus(context) == NotificationPermissionStatus.DENIED
    }

    /**
     * Returns the `POST_NOTIFICATIONS` permission string on API 33+,
     * or `null` on older API levels where no runtime permission is needed.
     */
    fun getPermissionString(): String? {
        return if (Build.VERSION.SDK_INT >= 33) POST_NOTIFICATIONS else null
    }
}
