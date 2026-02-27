import type { MessageScheduler, QueuedMessage } from '../domain/ClixTypes';
import { toIsoStringOrCurrentTime } from './StorageUtils';

interface ExpoSchedulableTriggerTypes {
  DATE: unknown;
}

export interface ExpoNotificationsAdapter {
  SchedulableTriggerInputTypes?: ExpoSchedulableTriggerTypes;
  scheduleNotificationAsync(request: {
    identifier: string;
    content: {
      title: string;
      body: string;
      data: Record<string, unknown>;
    };
    trigger: {
      type: unknown;
      date: Date;
    };
  }): Promise<void>;
  cancelScheduledNotificationAsync(identifier: string): Promise<void>;
  getAllScheduledNotificationsAsync(): Promise<
    Array<{
      content: {
        title?: string | null;
        body?: string | null;
        data?: Record<string, unknown>;
      };
      trigger?: unknown;
    }>
  >;
}

export class ExpoNotificationScheduler implements MessageScheduler {
  constructor(private readonly notificationsAdapter: ExpoNotificationsAdapter) {}

  async schedule(record: QueuedMessage): Promise<void> {
    const triggerDate = new Date(record.execute_at);
    const triggerType =
      this.notificationsAdapter.SchedulableTriggerInputTypes?.DATE ?? 'date';

    await this.notificationsAdapter.scheduleNotificationAsync({
      identifier: record.id,
      content: {
        title: record.content.title,
        body: record.content.body,
        data: {
          campaignId: record.campaign_id,
          queuedMessageId: record.id,
          landingUrl: record.content.landing_url,
          imageUrl: record.content.image_url,
        },
      },
      trigger: {
        type: triggerType,
        date: triggerDate,
      },
    });
  }

  async cancel(id: string): Promise<void> {
    await this.notificationsAdapter.cancelScheduledNotificationAsync(id);
  }

  async listPending(): Promise<QueuedMessage[]> {
    const scheduled =
      await this.notificationsAdapter.getAllScheduledNotificationsAsync();

    return scheduled
      .filter((notification) => notification.content.data?.queuedMessageId)
      .map((notification) => ({
        id: String(notification.content.data!.queuedMessageId),
        campaign_id: String(notification.content.data!.campaignId || ''),
        channel_type: 'app_push' as const,
        status: 'scheduled' as const,
        execute_at: toIsoStringOrCurrentTime(
          notification.trigger &&
            typeof notification.trigger === 'object' &&
            'date' in notification.trigger
            ? (notification.trigger as { date?: unknown }).date
            : undefined,
        ),
        content: {
          title: notification.content.title || '',
          body: notification.content.body || '',
          landing_url:
            typeof notification.content.data?.landingUrl === 'string'
              ? notification.content.data.landingUrl
              : undefined,
          image_url:
            typeof notification.content.data?.imageUrl === 'string'
              ? notification.content.data.imageUrl
              : undefined,
        },
        created_at: new Date().toISOString(),
      }));
  }
}
