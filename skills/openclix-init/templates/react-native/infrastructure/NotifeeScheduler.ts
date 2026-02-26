import type { MessageScheduler, QueuedMessage } from '../domain/ClixTypes';
import { toIsoStringOrCurrentTime } from './StorageUtils';

interface NotifeeTriggerTypes {
  TIMESTAMP: unknown;
}

interface NotifeeAndroidImportance {
  HIGH: unknown;
}

interface NotifeeTriggerNotification {
  notification: {
    title?: string | null;
    body?: string | null;
    data?: Record<string, unknown>;
  };
  trigger?: {
    timestamp?: unknown;
  };
}

export interface NotifeeAdapter {
  TriggerType?: NotifeeTriggerTypes;
  AndroidImportance?: NotifeeAndroidImportance;
  createChannel(channel: {
    id: string;
    name: string;
    importance: unknown;
  }): Promise<void>;
  createTriggerNotification(
    notification: {
      id: string;
      title: string;
      body: string;
      android: {
        channelId: string;
        importance: unknown;
      };
      data: Record<string, unknown>;
    },
    trigger: {
      type: unknown;
      timestamp: number;
    },
  ): Promise<void>;
  cancelNotification(id: string): Promise<void>;
  getTriggerNotifications(): Promise<NotifeeTriggerNotification[]>;
}

export class NotifeeScheduler implements MessageScheduler {
  private channelId = 'openclix-default';
  private channelCreated = false;

  constructor(private readonly notifeeAdapter: NotifeeAdapter) {}

  async schedule(record: QueuedMessage): Promise<void> {
    await this.ensureChannel();

    const triggerType = this.notifeeAdapter.TriggerType?.TIMESTAMP ?? 'timestamp';

    await this.notifeeAdapter.createTriggerNotification(
      {
        id: record.id,
        title: record.content.title,
        body: record.content.body,
        android: {
          channelId: this.channelId,
          importance: this.notifeeAdapter.AndroidImportance?.HIGH ?? 'high',
        },
        data: {
          campaignId: record.campaign_id,
          queuedMessageId: record.id,
        },
      },
      {
        type: triggerType,
        timestamp: new Date(record.execute_at).getTime(),
      },
    );
  }

  async cancel(id: string): Promise<void> {
    await this.notifeeAdapter.cancelNotification(id);
  }

  async listPending(): Promise<QueuedMessage[]> {
    const triggerNotifications = await this.notifeeAdapter.getTriggerNotifications();

    return triggerNotifications
      .filter((triggerNotification) => triggerNotification.notification.data?.queuedMessageId)
      .map((triggerNotification) => ({
        id: String(triggerNotification.notification.data!.queuedMessageId),
        campaign_id: String(triggerNotification.notification.data!.campaignId || ''),
        channel_type: 'app_push' as const,
        status: 'scheduled' as const,
        execute_at: toIsoStringOrCurrentTime(triggerNotification.trigger?.timestamp),
        content: {
          title: triggerNotification.notification.title || '',
          body: triggerNotification.notification.body || '',
        },
        created_at: new Date().toISOString(),
      }));
  }

  private async ensureChannel(): Promise<void> {
    if (this.channelCreated) return;

    await this.notifeeAdapter.createChannel({
      id: this.channelId,
      name: 'OpenClix Notifications',
      importance: this.notifeeAdapter.AndroidImportance?.HIGH ?? 'high',
    });

    this.channelCreated = true;
  }
}
