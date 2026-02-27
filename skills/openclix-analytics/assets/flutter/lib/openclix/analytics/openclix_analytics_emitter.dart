typedef OpenClixAnalyticsSink = Future<void> Function(
  String eventName,
  Map<String, Object?> properties,
);

enum OpenClixSourceType { app, system }
enum OpenClixAnalysisPeriod { pre, post }

class OpenClixAnalyticsEvent {
  final String name;
  final OpenClixSourceType sourceType;
  final Map<String, Object?> properties;

  const OpenClixAnalyticsEvent({
    required this.name,
    required this.sourceType,
    this.properties = const {},
  });
}

class OpenClixAnalyticsEmitter {
  final String platform;
  final OpenClixAnalysisPeriod analysisPeriod;
  final bool campaignActive;
  final OpenClixAnalyticsSink sink;
  final String Function(String canonicalName)? eventNameTransform;

  const OpenClixAnalyticsEmitter({
    required this.platform,
    required this.analysisPeriod,
    required this.campaignActive,
    required this.sink,
    this.eventNameTransform,
  });

  Future<void> emit(OpenClixAnalyticsEvent event) async {
    final merged = <String, Object?>{
      ...event.properties,
      'openclix_source': 'openclix',
      'openclix_event_name': event.name,
      'openclix_source_type': event.sourceType.name,
      'openclix_platform': platform,
      'openclix_campaign_id': _stringOrNull(event.properties['campaign_id']),
      'openclix_queued_message_id':
          _stringOrNull(event.properties['queued_message_id']),
      'openclix_channel_type': _stringOrNull(event.properties['channel_type']),
      'openclix_analysis_period': analysisPeriod.name,
      'openclix_campaign_active': campaignActive ? 'true' : 'false',
    };

    final outboundName = eventNameTransform?.call(event.name) ?? event.name;
    await sink(outboundName, merged);
  }

  String? _stringOrNull(Object? value) {
    return value is String ? value : null;
  }
}

String normalizeFirebaseEventName(String name) {
  var normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  if (!RegExp(r'^[a-z]').hasMatch(normalized)) {
    normalized = 'oc_$normalized';
  }
  if (normalized.length > 40) {
    normalized = normalized.substring(0, 40);
  }
  return normalized;
}
