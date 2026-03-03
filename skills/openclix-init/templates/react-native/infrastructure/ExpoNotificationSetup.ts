import type { ExpoNotificationsAdapter } from './ExpoNotificationScheduler';

export interface ExpoPermissionResult {
  granted: boolean;
  status: string;
}

export interface ExpoNotificationSetupAdapter extends ExpoNotificationsAdapter {
  requestPermissionsAsync(): Promise<{ status: string; granted: boolean }>;
  getPermissionsAsync(): Promise<{ status: string; granted: boolean }>;
  setNotificationHandler(handler: {
    handleNotification: () => Promise<{
      shouldShowAlert: boolean;
      shouldPlaySound: boolean;
      shouldSetBadge: boolean;
    }>;
  }): void;
}

/**
 * Request notification permission via Expo Notifications.
 * Call this before scheduling any campaign notifications.
 */
export async function requestExpoPermission(
  adapter: ExpoNotificationSetupAdapter,
): Promise<ExpoPermissionResult> {
  const result = await adapter.requestPermissionsAsync();
  return {
    granted: result.granted,
    status: result.status,
  };
}

/**
 * Check current notification permission status via Expo Notifications
 * without prompting the user.
 */
export async function checkExpoPermissionStatus(
  adapter: ExpoNotificationSetupAdapter,
): Promise<ExpoPermissionResult> {
  const result = await adapter.getPermissionsAsync();
  return {
    granted: result.granted,
    status: result.status,
  };
}

/**
 * Configure Expo Notifications to display notifications while
 * the app is in the foreground.
 * Call this once during app initialization.
 */
export function setupExpoForegroundHandler(
  adapter: ExpoNotificationSetupAdapter,
): void {
  adapter.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldPlaySound: true,
      shouldSetBadge: false,
    }),
  });
}
