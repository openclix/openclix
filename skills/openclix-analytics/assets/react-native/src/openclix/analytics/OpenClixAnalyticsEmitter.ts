export type OpenClixSourceType = 'app' | 'system';
export type OpenClixAnalysisPeriod = 'pre' | 'post';

export interface OpenClixAnalyticsEvent {
  name: string;
  sourceType: OpenClixSourceType;
  properties?: Record<string, unknown>;
}

export interface OpenClixAnalyticsEmitterConfig {
  platform: 'expo' | 'react-native';
  analysisPeriod: OpenClixAnalysisPeriod;
  campaignActive: boolean;
  sink: (eventName: string, properties: Record<string, unknown>) => Promise<void> | void;
  eventNameTransform?: (canonicalName: string) => string;
}

export class OpenClixAnalyticsEmitter {
  constructor(private readonly config: OpenClixAnalyticsEmitterConfig) {}

  async emit(event: OpenClixAnalyticsEvent): Promise<void> {
    const merged: Record<string, unknown> = {
      ...(event.properties ?? {}),
      openclix_source: 'openclix',
      openclix_event_name: event.name,
      openclix_source_type: event.sourceType,
      openclix_platform: this.config.platform,
      openclix_campaign_id: this.getString(event.properties, 'campaign_id'),
      openclix_queued_message_id: this.getString(event.properties, 'queued_message_id'),
      openclix_channel_type: this.getString(event.properties, 'channel_type'),
      openclix_analysis_period: this.config.analysisPeriod,
      openclix_campaign_active: this.config.campaignActive ? 'true' : 'false',
    };

    const outboundName = this.config.eventNameTransform
      ? this.config.eventNameTransform(event.name)
      : event.name;

    await this.config.sink(outboundName, merged);
  }

  private getString(source: Record<string, unknown> | undefined, key: string): string | null {
    const value = source?.[key];
    return typeof value === 'string' ? value : null;
  }
}

export function normalizeFirebaseEventName(name: string): string {
  let normalized = name.toLowerCase().replace(/[^a-z0-9_]/g, '_');
  if (!/^[a-z]/.test(normalized)) normalized = `oc_${normalized}`;
  return normalized.slice(0, 40);
}
