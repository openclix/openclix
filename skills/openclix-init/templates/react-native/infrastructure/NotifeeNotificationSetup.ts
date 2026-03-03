import type { NotifeeAdapter } from './NotifeeScheduler';

export interface NotifeePermissionResult {
  granted: boolean;
  status: string;
}

export interface NotifeePermissionAdapter extends NotifeeAdapter {
  requestPermission(): Promise<{ authorizationStatus: number }>;
  getNotificationSettings(): Promise<{ authorizationStatus: number }>;
}

/**
 * Request notification permission via Notifee.
 * Call this before scheduling any campaign notifications.
 */
export async function requestNotifeePermission(
  adapter: NotifeePermissionAdapter,
): Promise<NotifeePermissionResult> {
  const result = await adapter.requestPermission();
  // Notifee authorizationStatus: 1 = AUTHORIZED, 2 = PROVISIONAL
  const granted =
    result.authorizationStatus === 1 || result.authorizationStatus === 2;
  return {
    granted,
    status: String(result.authorizationStatus),
  };
}

/**
 * Check current notification permission status via Notifee
 * without prompting the user.
 */
export async function checkNotifeePermissionStatus(
  adapter: NotifeePermissionAdapter,
): Promise<NotifeePermissionResult> {
  const settings = await adapter.getNotificationSettings();
  const granted =
    settings.authorizationStatus === 1 || settings.authorizationStatus === 2;
  return {
    granted,
    status: String(settings.authorizationStatus),
  };
}
