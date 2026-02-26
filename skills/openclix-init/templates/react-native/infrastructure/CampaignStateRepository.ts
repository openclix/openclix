import type {
  CampaignStateRepositoryPort,
  CampaignStateSnapshot,
  CampaignStateRecord,
  CampaignQueuedMessage,
  CampaignTriggerHistory,
} from '../domain/ClixTypes';
import {
  CAMPAIGN_STATE_KEYS,
  isNonEmptyString,
  isObjectRecord,
  parseArray,
  parseJson,
} from './StorageUtils';

export function createDefaultCampaignStateSnapshot(now: string): CampaignStateSnapshot {
  return {
    campaign_states: [],
    queued_messages: [],
    trigger_history: [],
    updated_at: now,
  };
}

interface CampaignStateMetaRow {
  updated_at: string;
}

export interface StorageEngine {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
  multiGet(keys: string[]): Promise<Array<[string, string | null]>>;
  multiSet(keyValuePairs: Array<[string, string]>): Promise<void>;
  multiRemove(keys: string[]): Promise<void>;
}

const META_UPDATED_AT_KEY = `${CAMPAIGN_STATE_KEYS.meta}/row`;

function normalizeUpdatedAt(updatedAt: string): string {
  return isNonEmptyString(updatedAt) ? updatedAt : new Date().toISOString();
}

function normalizeCampaignStateRow(value: unknown): CampaignStateRecord | null {
  if (!isObjectRecord(value)) return null;
  if (!isNonEmptyString(value.campaign_id)) return null;

  return {
    campaign_id: value.campaign_id,
    triggered: value.triggered === true,
    delivery_count:
      typeof value.delivery_count === 'number' && Number.isFinite(value.delivery_count)
        ? value.delivery_count
        : 0,
    last_triggered_at: isNonEmptyString(value.last_triggered_at)
      ? value.last_triggered_at
      : undefined,
    recurring_anchor_at: isNonEmptyString(value.recurring_anchor_at)
      ? value.recurring_anchor_at
      : undefined,
    recurring_last_scheduled_at: isNonEmptyString(value.recurring_last_scheduled_at)
      ? value.recurring_last_scheduled_at
      : undefined,
  };
}

function normalizeQueuedMessageRow(value: unknown): CampaignQueuedMessage | null {
  if (!isObjectRecord(value)) return null;
  if (!isNonEmptyString(value.message_id)) return null;
  if (!isNonEmptyString(value.campaign_id)) return null;
  if (!isNonEmptyString(value.execute_at)) return null;

  const triggerType =
    value.trigger_type === 'scheduled' || value.trigger_type === 'recurring'
      ? value.trigger_type
      : 'event';

  return {
    message_id: value.message_id,
    campaign_id: value.campaign_id,
    execute_at: value.execute_at,
    trigger_type: triggerType,
    trigger_event_id: isNonEmptyString(value.trigger_event_id)
      ? value.trigger_event_id
      : undefined,
    created_at: isNonEmptyString(value.created_at) ? value.created_at : value.execute_at,
  };
}

function normalizeTriggerHistoryRow(value: unknown): CampaignTriggerHistory | null {
  if (!isObjectRecord(value)) return null;
  if (!isNonEmptyString(value.triggered_at)) return null;

  return {
    campaign_id: isNonEmptyString(value.campaign_id) ? value.campaign_id : undefined,
    triggered_at: value.triggered_at,
  };
}

export function normalizeCampaignStateSnapshot(
  snapshot: CampaignStateSnapshot | null,
  now: string,
): CampaignStateSnapshot {
  if (!snapshot) return createDefaultCampaignStateSnapshot(now);
  return {
    campaign_states: Array.isArray(snapshot.campaign_states)
      ? snapshot.campaign_states
      : [],
    queued_messages: Array.isArray(snapshot.queued_messages)
      ? snapshot.queued_messages
      : [],
    trigger_history: Array.isArray(snapshot.trigger_history)
      ? snapshot.trigger_history
      : [],
    updated_at: normalizeUpdatedAt(snapshot.updated_at || now),
  };
}

export class StorageCampaignStateRepository implements CampaignStateRepositoryPort {
  constructor(private readonly storageEngine: StorageEngine) {}

  async loadSnapshot(now: string): Promise<CampaignStateSnapshot> {
    const [campaignStates, queuedMessages, triggerHistory, updatedAt] = await Promise.all([
      this.loadRecords(CAMPAIGN_STATE_KEYS.campaign_states, normalizeCampaignStateRow),
      this.loadRecords(CAMPAIGN_STATE_KEYS.queued_messages, normalizeQueuedMessageRow),
      this.loadRecords(CAMPAIGN_STATE_KEYS.trigger_history, normalizeTriggerHistoryRow),
      this.loadUpdatedAt(),
    ]);

    return normalizeCampaignStateSnapshot(
      {
        campaign_states: campaignStates,
        queued_messages: queuedMessages,
        trigger_history: triggerHistory,
        updated_at: updatedAt ?? now,
      },
      now,
    );
  }

  async saveSnapshot(snapshot: CampaignStateSnapshot): Promise<void> {
    const normalizedSnapshot = normalizeCampaignStateSnapshot(snapshot, snapshot.updated_at);
    const updatedAt = normalizeUpdatedAt(normalizedSnapshot.updated_at);

    await Promise.all([
      this.replaceRecords(
        CAMPAIGN_STATE_KEYS.campaign_states,
        normalizedSnapshot.campaign_states,
        (row) => row.campaign_id,
      ),
      this.replaceRecords(
        CAMPAIGN_STATE_KEYS.queued_messages,
        normalizedSnapshot.queued_messages,
        (row) => `${row.campaign_id}:${row.message_id}`,
      ),
      this.replaceRecords(
        CAMPAIGN_STATE_KEYS.trigger_history,
        normalizedSnapshot.trigger_history,
        (row, index) => `${row.campaign_id ?? 'none'}:${row.triggered_at}:${index}`,
      ),
      this.saveUpdatedAt(updatedAt),
    ]);
  }

  async clearCampaignState(): Promise<void> {
    await Promise.all([
      this.clearRecords(CAMPAIGN_STATE_KEYS.campaign_states),
      this.clearRecords(CAMPAIGN_STATE_KEYS.queued_messages),
      this.clearRecords(CAMPAIGN_STATE_KEYS.trigger_history),
      this.clearUpdatedAt(),
    ]);
  }

  private async loadRecords<RecordType>(
    namespaceKey: string,
    normalize: (value: unknown) => RecordType | null,
  ): Promise<RecordType[]> {
    const recordIds = await this.loadRecordIds(namespaceKey);
    if (recordIds.length === 0) return [];

    const records = await this.storageEngine.multiGet(
      recordIds.map((recordId) => this.buildRecordKey(namespaceKey, recordId)),
    );

    const normalizedRecords: RecordType[] = [];
    for (const [, rawValue] of records) {
      if (!rawValue) continue;
      try {
        const record = normalize(JSON.parse(rawValue) as unknown);
        if (record) normalizedRecords.push(record);
      } catch {
        continue;
      }
    }
    return normalizedRecords;
  }

  private async replaceRecords<RecordType>(
    namespaceKey: string,
    records: RecordType[],
    getRecordId: (record: RecordType, index: number) => string,
  ): Promise<void> {
    const previousRecordIds = await this.loadRecordIds(namespaceKey);
    const nextRecordIds: string[] = [];
    const payloadById = new Map<string, string>();

    records.forEach((record, index) => {
      const recordId = getRecordId(record, index);
      if (!isNonEmptyString(recordId)) return;
      if (!payloadById.has(recordId)) {
        nextRecordIds.push(recordId);
      }
      payloadById.set(recordId, JSON.stringify(record));
    });

    const nextRecordIdSet = new Set(nextRecordIds);
    const staleRecordIds = previousRecordIds.filter(
      (recordId) => !nextRecordIdSet.has(recordId),
    );

    if (staleRecordIds.length > 0) {
      await this.storageEngine.multiRemove(
        staleRecordIds.map((recordId) => this.buildRecordKey(namespaceKey, recordId)),
      );
    }

    const keyValuePairs: [string, string][] = nextRecordIds.map((recordId) => [
      this.buildRecordKey(namespaceKey, recordId),
      payloadById.get(recordId) ?? 'null',
    ]);
    keyValuePairs.push([this.buildRecordIdsKey(namespaceKey), JSON.stringify(nextRecordIds)]);

    await this.storageEngine.multiSet(keyValuePairs);
  }

  private async clearRecords(namespaceKey: string): Promise<void> {
    const recordIds = await this.loadRecordIds(namespaceKey);
    const keys = recordIds.map((recordId) => this.buildRecordKey(namespaceKey, recordId));
    keys.push(this.buildRecordIdsKey(namespaceKey));
    await this.storageEngine.multiRemove(keys);
  }

  private async loadRecordIds(namespaceKey: string): Promise<string[]> {
    const rawValue = await this.storageEngine.getItem(this.buildRecordIdsKey(namespaceKey));
    return parseArray<string>(rawValue).filter(
      (recordId): recordId is string => isNonEmptyString(recordId),
    );
  }

  private buildRecordIdsKey(namespaceKey: string): string {
    return `${namespaceKey}/ids`;
  }

  private buildRecordKey(namespaceKey: string, recordId: string): string {
    return `${namespaceKey}/records/${encodeURIComponent(recordId)}`;
  }

  private async loadUpdatedAt(): Promise<string | null> {
    const raw = await this.storageEngine.getItem(META_UPDATED_AT_KEY);
    const row = parseJson<CampaignStateMetaRow>(raw);
    return isNonEmptyString(row?.updated_at) ? row.updated_at : null;
  }

  private async saveUpdatedAt(updatedAt: string): Promise<void> {
    await this.storageEngine.setItem(
      META_UPDATED_AT_KEY,
      JSON.stringify({ updated_at: updatedAt }),
    );
  }

  private async clearUpdatedAt(): Promise<void> {
    await this.storageEngine.removeItem(META_UPDATED_AT_KEY);
  }
}

export class CampaignStateRepository extends StorageCampaignStateRepository {}
