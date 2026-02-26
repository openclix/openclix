import notifee, {
  TriggerType,
  AndroidImportance,
  type TimestampTrigger,
} from '@notifee/react-native';
import type { MessageScheduler, QueuedMessage } from '../domain/ClixTypes';
import { toIsoStringOrCurrentTime } from './StorageUtils';

export class NotifeeScheduler implements MessageScheduler {
  private channelId: string = 'openclix-default';
  private channelCreated: boolean = false;

  async schedule(record: QueuedMessage): Promise<void> {
    await this.ensureChannel();

    const trigger: TimestampTrigger = {
      type: TriggerType.TIMESTAMP,
      timestamp: new Date(record.execute_at).getTime(),
    };

    await notifee.createTriggerNotification(
      {
        id: record.id,
        title: record.content.title,
        body: record.content.body,
        android: {
          channelId: this.channelId,
          importance: AndroidImportance.HIGH,
        },
        data: {
          campaignId: record.campaign_id,
          queuedMessageId: record.id,
        },
      },
      trigger,
    );
  }

  async cancel(id: string): Promise<void> {
    await notifee.cancelNotification(id);
  }

  async listPending(): Promise<QueuedMessage[]> {
    const triggers = await notifee.getTriggerNotifications();

    return triggers
      .filter((t) => t.notification.data?.queuedMessageId)
      .map((t) => ({
        id: String(t.notification.data!.queuedMessageId),
        campaign_id: String(t.notification.data!.campaignId || ''),
        channel_type: 'app_push' as const,
        status: 'scheduled' as const,
        execute_at: toIsoStringOrCurrentTime(
          (t.trigger as Partial<TimestampTrigger> | undefined)?.timestamp,
        ),
        content: {
          title: t.notification.title || '',
          body: t.notification.body || '',
        },
        created_at: new Date().toISOString(),
      }));
  }

  private async ensureChannel(): Promise<void> {
    if (this.channelCreated) return;

    await notifee.createChannel({
      id: this.channelId,
      name: 'OpenClix Notifications',
      importance: AndroidImportance.HIGH,
    });

    this.channelCreated = true;
  }
}
