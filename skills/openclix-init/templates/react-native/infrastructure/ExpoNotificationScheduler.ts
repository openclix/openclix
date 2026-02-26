import * as Notifications from 'expo-notifications';
import type { MessageScheduler, QueuedMessage } from '../domain/ClixTypes';
import { toIsoStringOrCurrentTime } from './StorageUtils';

export class ExpoNotificationScheduler implements MessageScheduler {
  async schedule(record: QueuedMessage): Promise<void> {
    const triggerDate = new Date(record.execute_at);

    await Notifications.scheduleNotificationAsync({
      identifier: record.id,
      content: {
        title: record.content.title,
        body: record.content.body,
        data: {
          campaignId: record.campaign_id,
          queuedMessageId: record.id,
        },
      },
      trigger: {
        type: Notifications.SchedulableTriggerInputTypes.DATE,
        date: triggerDate,
      },
    });
  }

  async cancel(id: string): Promise<void> {
    await Notifications.cancelScheduledNotificationAsync(id);
  }

  async listPending(): Promise<QueuedMessage[]> {
    const scheduled = await Notifications.getAllScheduledNotificationsAsync();

    return scheduled
      .filter((n) => n.content.data?.queuedMessageId)
      .map((n) => ({
        id: String(n.content.data!.queuedMessageId),
        campaign_id: String(n.content.data!.campaignId || ''),
        channel_type: 'app_push' as const,
        status: 'scheduled' as const,
        execute_at: toIsoStringOrCurrentTime(
          n.trigger && 'date' in n.trigger
            ? (n.trigger as { date?: unknown }).date
            : undefined,
        ),
        content: {
          title: n.content.title || '',
          body: n.content.body || '',
        },
        created_at: new Date().toISOString(),
      }));
  }
}
