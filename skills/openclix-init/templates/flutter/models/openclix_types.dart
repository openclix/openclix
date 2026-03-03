typedef JsonValue = Object?;

int parseStrictInt(
  Object? value, {
  required int fallback,
  int? invalidFallback,
}) {
  if (value is int) {
    return value;
  }

  if (value is num && value.isFinite && value % 1 == 0) {
    return value.toInt();
  }

  return invalidFallback ?? fallback;
}

int? parseStrictOptionalInt(Object? value, {int? invalidFallback}) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num && value.isFinite && value % 1 == 0) {
    return value.toInt();
  }

  return invalidFallback;
}

class Config {
  final String schemaVersion;
  final String configVersion;
  final Settings? settings;
  final Map<String, Campaign> campaigns;

  Config({
    required this.schemaVersion,
    required this.configVersion,
    this.settings,
    required this.campaigns,
  });

  factory Config.fromJson(Map<String, dynamic> json) {
    final campaignsJson = Map<String, dynamic>.from(
      json['campaigns'] as Map? ?? const {},
    );

    return Config(
      schemaVersion: json['schema_version'] as String? ?? '',
      configVersion: json['config_version'] as String? ?? '',
      settings: json['settings'] is Map<String, dynamic>
          ? Settings.fromJson(json['settings'] as Map<String, dynamic>)
          : json['settings'] is Map
          ? Settings.fromJson(
              Map<String, dynamic>.from(json['settings'] as Map),
            )
          : null,
      campaigns: campaignsJson.map(
        (campaignId, rawCampaign) => MapEntry(
          campaignId,
          Campaign.fromJson(Map<String, dynamic>.from(rawCampaign as Map)),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'config_version': configVersion,
      if (settings != null) 'settings': settings!.toJson(),
      'campaigns': campaigns.map((campaignId, campaign) {
        return MapEntry(campaignId, campaign.toJson());
      }),
    };
  }
}

class Settings {
  final FrequencyCap? frequencyCap;
  final DoNotDisturb? doNotDisturb;

  Settings({this.frequencyCap, this.doNotDisturb});

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      frequencyCap: json['frequency_cap'] is Map<String, dynamic>
          ? FrequencyCap.fromJson(json['frequency_cap'] as Map<String, dynamic>)
          : json['frequency_cap'] is Map
          ? FrequencyCap.fromJson(
              Map<String, dynamic>.from(json['frequency_cap'] as Map),
            )
          : null,
      doNotDisturb: json['do_not_disturb'] is Map<String, dynamic>
          ? DoNotDisturb.fromJson(
              json['do_not_disturb'] as Map<String, dynamic>,
            )
          : json['do_not_disturb'] is Map
          ? DoNotDisturb.fromJson(
              Map<String, dynamic>.from(json['do_not_disturb'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (frequencyCap != null) 'frequency_cap': frequencyCap!.toJson(),
      if (doNotDisturb != null) 'do_not_disturb': doNotDisturb!.toJson(),
    };
  }
}

class FrequencyCap {
  final int maxCount;
  final int windowSeconds;

  FrequencyCap({required this.maxCount, required this.windowSeconds});

  factory FrequencyCap.fromJson(Map<String, dynamic> json) {
    return FrequencyCap(
      maxCount: parseStrictInt(
        json['max_count'],
        fallback: 0,
        invalidFallback: -1,
      ),
      windowSeconds: parseStrictInt(
        json['window_seconds'],
        fallback: 0,
        invalidFallback: -1,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'max_count': maxCount, 'window_seconds': windowSeconds};
  }
}

class DoNotDisturb {
  final int startHour;
  final int endHour;

  DoNotDisturb({required this.startHour, required this.endHour});

  factory DoNotDisturb.fromJson(Map<String, dynamic> json) {
    return DoNotDisturb(
      startHour: parseStrictInt(
        json['start_hour'],
        fallback: -1,
        invalidFallback: -1,
      ),
      endHour: parseStrictInt(
        json['end_hour'],
        fallback: -1,
        invalidFallback: -1,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'start_hour': startHour, 'end_hour': endHour};
  }
}

enum CampaignStatus {
  running('running'),
  paused('paused');

  const CampaignStatus(this.value);
  final String value;

  static CampaignStatus fromJson(String? raw) {
    return CampaignStatus.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => CampaignStatus.paused,
    );
  }

  String toJson() => value;
}

class Campaign {
  final String name;
  final String type;
  final String description;
  final CampaignStatus status;
  final CampaignTrigger trigger;
  final Message message;

  Campaign({
    required this.name,
    required this.type,
    required this.description,
    required this.status,
    required this.trigger,
    required this.message,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: CampaignStatus.fromJson(json['status'] as String?),
      trigger: CampaignTrigger.fromJson(
        Map<String, dynamic>.from(json['trigger'] as Map? ?? const {}),
      ),
      message: Message.fromJson(
        Map<String, dynamic>.from(json['message'] as Map? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'description': description,
      'status': status.toJson(),
      'trigger': trigger.toJson(),
      'message': message.toJson(),
    };
  }
}

enum TriggerType {
  event('event'),
  scheduled('scheduled'),
  recurring('recurring');

  const TriggerType(this.value);
  final String value;

  static TriggerType fromJson(String? raw) {
    return TriggerType.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => TriggerType.event,
    );
  }

  String toJson() => value;
}

class CampaignTrigger {
  final TriggerType type;
  final EventTriggerConfig? event;
  final ScheduledTriggerConfig? scheduled;
  final RecurringTriggerConfig? recurring;

  CampaignTrigger({
    required this.type,
    this.event,
    this.scheduled,
    this.recurring,
  });

  factory CampaignTrigger.fromJson(Map<String, dynamic> json) {
    return CampaignTrigger(
      type: TriggerType.fromJson(json['type'] as String?),
      event: json['event'] is Map<String, dynamic>
          ? EventTriggerConfig.fromJson(json['event'] as Map<String, dynamic>)
          : json['event'] is Map
          ? EventTriggerConfig.fromJson(
              Map<String, dynamic>.from(json['event'] as Map),
            )
          : null,
      scheduled: json['scheduled'] is Map<String, dynamic>
          ? ScheduledTriggerConfig.fromJson(
              json['scheduled'] as Map<String, dynamic>,
            )
          : json['scheduled'] is Map
          ? ScheduledTriggerConfig.fromJson(
              Map<String, dynamic>.from(json['scheduled'] as Map),
            )
          : null,
      recurring: json['recurring'] is Map<String, dynamic>
          ? RecurringTriggerConfig.fromJson(
              json['recurring'] as Map<String, dynamic>,
            )
          : json['recurring'] is Map
          ? RecurringTriggerConfig.fromJson(
              Map<String, dynamic>.from(json['recurring'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toJson(),
      if (event != null) 'event': event!.toJson(),
      if (scheduled != null) 'scheduled': scheduled!.toJson(),
      if (recurring != null) 'recurring': recurring!.toJson(),
    };
  }
}

class EventTriggerConfig {
  final EventConditionGroup triggerEvent;
  final int? delaySeconds;
  final EventConditionGroup? cancelEvent;

  EventTriggerConfig({
    required this.triggerEvent,
    this.delaySeconds,
    this.cancelEvent,
  });

  factory EventTriggerConfig.fromJson(Map<String, dynamic> json) {
    return EventTriggerConfig(
      triggerEvent: EventConditionGroup.fromJson(
        Map<String, dynamic>.from(json['trigger_event'] as Map? ?? const {}),
      ),
      delaySeconds: parseStrictOptionalInt(
        json['delay_seconds'],
        invalidFallback: -1,
      ),
      cancelEvent: json['cancel_event'] is Map<String, dynamic>
          ? EventConditionGroup.fromJson(
              json['cancel_event'] as Map<String, dynamic>,
            )
          : json['cancel_event'] is Map
          ? EventConditionGroup.fromJson(
              Map<String, dynamic>.from(json['cancel_event'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trigger_event': triggerEvent.toJson(),
      if (delaySeconds != null) 'delay_seconds': delaySeconds,
      if (cancelEvent != null) 'cancel_event': cancelEvent!.toJson(),
    };
  }
}

class ScheduledTriggerConfig {
  final String executeAt;

  ScheduledTriggerConfig({required this.executeAt});

  factory ScheduledTriggerConfig.fromJson(Map<String, dynamic> json) {
    return ScheduledTriggerConfig(
      executeAt: json['execute_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'execute_at': executeAt};
  }
}

enum RecurrenceType {
  hourly('hourly'),
  daily('daily'),
  weekly('weekly');

  const RecurrenceType(this.value);
  final String value;

  static RecurrenceType fromJson(String? raw) {
    return RecurrenceType.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => RecurrenceType.hourly,
    );
  }

  String toJson() => value;
}

enum DayOfWeek {
  sunday('sunday'),
  monday('monday'),
  tuesday('tuesday'),
  wednesday('wednesday'),
  thursday('thursday'),
  friday('friday'),
  saturday('saturday');

  const DayOfWeek(this.value);
  final String value;

  static DayOfWeek? fromJson(String? raw) {
    for (final candidate in DayOfWeek.values) {
      if (candidate.value == raw) return candidate;
    }
    return null;
  }

  String toJson() => value;
}

class TimeOfDayRule {
  final int hour;
  final int minute;

  TimeOfDayRule({required this.hour, required this.minute});

  factory TimeOfDayRule.fromJson(Map<String, dynamic> json) {
    return TimeOfDayRule(
      hour: parseStrictInt(json['hour'], fallback: -1, invalidFallback: -1),
      minute: parseStrictInt(json['minute'], fallback: -1, invalidFallback: -1),
    );
  }

  Map<String, dynamic> toJson() {
    return {'hour': hour, 'minute': minute};
  }
}

class WeeklyRule {
  final List<DayOfWeek> daysOfWeek;

  WeeklyRule({required this.daysOfWeek});

  factory WeeklyRule.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days_of_week'] as List<dynamic>? ?? const [];
    return WeeklyRule(
      daysOfWeek: rawDays
          .map((rawDay) => DayOfWeek.fromJson(rawDay as String?))
          .whereType<DayOfWeek>()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'days_of_week': daysOfWeek.map((day) => day.toJson()).toList()};
  }
}

class RecurrenceRule {
  final RecurrenceType type;
  final int interval;
  final WeeklyRule? weeklyRule;
  final TimeOfDayRule? timeOfDay;

  RecurrenceRule({
    required this.type,
    required this.interval,
    this.weeklyRule,
    this.timeOfDay,
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      type: RecurrenceType.fromJson(json['type'] as String?),
      interval: parseStrictInt(
        json['interval'],
        fallback: 0,
        invalidFallback: 0,
      ),
      weeklyRule: json['weekly_rule'] is Map<String, dynamic>
          ? WeeklyRule.fromJson(json['weekly_rule'] as Map<String, dynamic>)
          : json['weekly_rule'] is Map
          ? WeeklyRule.fromJson(
              Map<String, dynamic>.from(json['weekly_rule'] as Map),
            )
          : null,
      timeOfDay: json['time_of_day'] is Map<String, dynamic>
          ? TimeOfDayRule.fromJson(json['time_of_day'] as Map<String, dynamic>)
          : json['time_of_day'] is Map
          ? TimeOfDayRule.fromJson(
              Map<String, dynamic>.from(json['time_of_day'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toJson(),
      'interval': interval,
      if (weeklyRule != null) 'weekly_rule': weeklyRule!.toJson(),
      if (timeOfDay != null) 'time_of_day': timeOfDay!.toJson(),
    };
  }
}

class RecurringTriggerConfig {
  final String? startAt;
  final String? endAt;
  final RecurrenceRule rule;

  RecurringTriggerConfig({this.startAt, this.endAt, required this.rule});

  factory RecurringTriggerConfig.fromJson(Map<String, dynamic> json) {
    return RecurringTriggerConfig(
      startAt: json['start_at'] as String?,
      endAt: json['end_at'] as String?,
      rule: RecurrenceRule.fromJson(
        Map<String, dynamic>.from(json['rule'] as Map? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      'rule': rule.toJson(),
    };
  }
}

class EventConditionGroup {
  final String connector;
  final List<EventCondition> conditions;

  EventConditionGroup({required this.connector, required this.conditions});

  factory EventConditionGroup.fromJson(Map<String, dynamic> json) {
    final rawConditions = json['conditions'] as List<dynamic>? ?? const [];
    return EventConditionGroup(
      connector: json['connector'] as String? ?? 'and',
      conditions: rawConditions
          .map(
            (rawCondition) => EventCondition.fromJson(
              Map<String, dynamic>.from(rawCondition as Map),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connector': connector,
      'conditions': conditions.map((condition) => condition.toJson()).toList(),
    };
  }
}

enum EventConditionOperator {
  equal('equal'),
  notEqual('not_equal'),
  greaterThan('greater_than'),
  greaterThanOrEqual('greater_than_or_equal'),
  lessThan('less_than'),
  lessThanOrEqual('less_than_or_equal'),
  contains('contains'),
  notContains('not_contains'),
  startsWith('starts_with'),
  endsWith('ends_with'),
  matches('matches'),
  exists('exists'),
  notExists('not_exists'),
  inList('in'),
  notInList('not_in');

  const EventConditionOperator(this.value);
  final String value;

  static EventConditionOperator fromJson(String? raw) {
    return EventConditionOperator.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => EventConditionOperator.equal,
    );
  }

  String toJson() => value;
}

class EventCondition {
  final String field;
  final String? propertyName;
  final EventConditionOperator operator;
  final List<String> values;

  EventCondition({
    required this.field,
    this.propertyName,
    required this.operator,
    required this.values,
  });

  factory EventCondition.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'] as List<dynamic>? ?? const [];
    return EventCondition(
      field: json['field'] as String? ?? '',
      propertyName: json['property_name'] as String?,
      operator: EventConditionOperator.fromJson(json['operator'] as String?),
      values: rawValues.map((rawValue) => rawValue.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      if (propertyName != null) 'property_name': propertyName,
      'operator': operator.toJson(),
      'values': values,
    };
  }
}

enum ChannelType {
  appPush('app_push');

  const ChannelType(this.value);
  final String value;

  static ChannelType fromJson(String? raw) {
    return ChannelType.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => ChannelType.appPush,
    );
  }

  String toJson() => value;
}

class Message {
  final ChannelType channelType;
  final MessageContent content;

  Message({required this.channelType, required this.content});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      channelType: ChannelType.fromJson(json['channel_type'] as String?),
      content: MessageContent.fromJson(
        Map<String, dynamic>.from(json['content'] as Map? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'channel_type': channelType.toJson(), 'content': content.toJson()};
  }
}

class MessageContent {
  final String title;
  final String body;
  final String? imageUrl;
  final String? landingUrl;

  MessageContent({
    required this.title,
    required this.body,
    this.imageUrl,
    this.landingUrl,
  });

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    return MessageContent(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      landingUrl: json['landing_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      if (imageUrl != null) 'image_url': imageUrl,
      if (landingUrl != null) 'landing_url': landingUrl,
    };
  }
}

enum QueuedMessageStatus {
  scheduled('scheduled'),
  delivered('delivered'),
  cancelled('cancelled');

  const QueuedMessageStatus(this.value);
  final String value;

  static QueuedMessageStatus fromJson(String? raw) {
    return QueuedMessageStatus.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => QueuedMessageStatus.scheduled,
    );
  }

  String toJson() => value;
}

enum SkipReason {
  campaignNotRunning('campaign_not_running'),
  campaignFrequencyCapExceeded('campaign_frequency_cap_exceeded'),
  campaignDoNotDisturbBlocked('campaign_do_not_disturb_blocked'),
  triggerEventNotMatched('trigger_event_not_matched'),
  triggerCancelEventMatched('trigger_cancel_event_matched');

  const SkipReason(this.value);
  final String value;

  static SkipReason fromJson(String? raw) {
    return SkipReason.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => SkipReason.campaignNotRunning,
    );
  }

  String toJson() => value;
}

class QueuedMessage {
  final String id;
  final String campaignId;
  final ChannelType channelType;
  final QueuedMessageStatus status;
  final MessageContent content;
  final String? triggerEventId;
  final SkipReason? skipReason;
  final String executeAt;
  final String createdAt;

  QueuedMessage({
    required this.id,
    required this.campaignId,
    required this.channelType,
    required this.status,
    required this.content,
    this.triggerEventId,
    this.skipReason,
    required this.executeAt,
    required this.createdAt,
  });

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: json['id'] as String? ?? '',
      campaignId: json['campaign_id'] as String? ?? '',
      channelType: ChannelType.fromJson(json['channel_type'] as String?),
      status: QueuedMessageStatus.fromJson(json['status'] as String?),
      content: MessageContent.fromJson(
        Map<String, dynamic>.from(json['content'] as Map? ?? const {}),
      ),
      triggerEventId: json['trigger_event_id'] as String?,
      skipReason: json['skip_reason'] == null
          ? null
          : SkipReason.fromJson(json['skip_reason'] as String?),
      executeAt: json['execute_at'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'channel_type': channelType.toJson(),
      'status': status.toJson(),
      'content': content.toJson(),
      if (triggerEventId != null) 'trigger_event_id': triggerEventId,
      if (skipReason != null) 'skip_reason': skipReason!.toJson(),
      'execute_at': executeAt,
      'created_at': createdAt,
    };
  }
}

enum EventSourceType {
  app('app'),
  system('system');

  const EventSourceType(this.value);
  final String value;

  static EventSourceType fromJson(String? raw) {
    return EventSourceType.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => EventSourceType.app,
    );
  }

  String toJson() => value;
}

enum SystemEventName {
  messageScheduled('clix.message.scheduled'),
  messageDelivered('clix.message.delivered'),
  messageOpened('clix.message.opened'),
  messageCancelled('clix.message.cancelled'),
  messageFailed('clix.message.failed');

  const SystemEventName(this.value);
  final String value;

  static SystemEventName fromJson(String? raw) {
    return SystemEventName.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => SystemEventName.messageFailed,
    );
  }

  String toJson() => value;
}

class Event {
  final String id;
  final String name;
  final EventSourceType sourceType;
  final Map<String, JsonValue>? properties;
  final String createdAt;

  Event({
    required this.id,
    required this.name,
    required this.sourceType,
    this.properties,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    final rawProperties = json['properties'];
    return Event(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sourceType: EventSourceType.fromJson(json['source_type'] as String?),
      properties: rawProperties is Map
          ? Map<String, JsonValue>.from(rawProperties)
          : null,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'source_type': sourceType.toJson(),
      if (properties != null) 'properties': properties,
      'created_at': createdAt,
    };
  }
}

enum ClixLogLevel {
  debug('debug'),
  info('info'),
  warn('warn'),
  error('error'),
  none('none');

  const ClixLogLevel(this.value);
  final String value;

  static ClixLogLevel fromJson(String? raw) {
    return ClixLogLevel.values.firstWhere(
      (value) => value.value == raw,
      orElse: () => ClixLogLevel.warn,
    );
  }

  String toJson() => value;
}

class TriggerContext {
  final Event? event;
  final String trigger;
  final String? now;

  TriggerContext({this.event, required this.trigger, this.now});
}

class DecisionTrace {
  final String campaignId;
  final String action;
  final String result;
  final SkipReason? skipReason;
  final String reason;

  DecisionTrace({
    required this.campaignId,
    required this.action,
    required this.result,
    this.skipReason,
    required this.reason,
  });

  factory DecisionTrace.fromJson(Map<String, dynamic> json) {
    return DecisionTrace(
      campaignId: json['campaign_id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      result: json['result'] as String? ?? '',
      skipReason: json['skip_reason'] == null
          ? null
          : SkipReason.fromJson(json['skip_reason'] as String?),
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id': campaignId,
      'action': action,
      'result': result,
      if (skipReason != null) 'skip_reason': skipReason!.toJson(),
      'reason': reason,
    };
  }
}

class TriggerResult {
  final String evaluatedAt;
  final String trigger;
  final List<DecisionTrace> traces;
  final List<QueuedMessage> queuedMessages;

  TriggerResult({
    required this.evaluatedAt,
    required this.trigger,
    required this.traces,
    required this.queuedMessages,
  });

  Map<String, dynamic> toJson() {
    return {
      'evaluated_at': evaluatedAt,
      'trigger': trigger,
      'traces': traces.map((trace) => trace.toJson()).toList(),
      'queued_messages': queuedMessages
          .map((message) => message.toJson())
          .toList(),
    };
  }
}

class CampaignStateSnapshot {
  final List<CampaignStateRecord> campaignStates;
  final List<CampaignQueuedMessage> queuedMessages;
  final List<CampaignTriggerHistory> triggerHistory;
  String updatedAt;

  CampaignStateSnapshot({
    required this.campaignStates,
    required this.queuedMessages,
    required this.triggerHistory,
    required this.updatedAt,
  });

  factory CampaignStateSnapshot.fromJson(Map<String, dynamic> json) {
    final campaignStateRows =
        json['campaign_states'] as List<dynamic>? ?? const [];
    final queuedMessageRows =
        json['queued_messages'] as List<dynamic>? ?? const [];
    final triggerHistoryRows =
        json['trigger_history'] as List<dynamic>? ?? const [];

    return CampaignStateSnapshot(
      campaignStates: campaignStateRows
          .map(
            (row) => CampaignStateRecord.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
      queuedMessages: queuedMessageRows
          .map(
            (row) => CampaignQueuedMessage.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
      triggerHistory: triggerHistoryRows
          .map(
            (row) => CampaignTriggerHistory.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_states': campaignStates.map((state) => state.toJson()).toList(),
      'queued_messages': queuedMessages
          .map((message) => message.toJson())
          .toList(),
      'trigger_history': triggerHistory
          .map((history) => history.toJson())
          .toList(),
      'updated_at': updatedAt,
    };
  }
}

class CampaignStateRecord {
  final String campaignId;
  bool triggered;
  int deliveryCount;
  String? lastTriggeredAt;
  String? recurringAnchorAt;
  String? recurringLastScheduledAt;

  CampaignStateRecord({
    required this.campaignId,
    required this.triggered,
    required this.deliveryCount,
    this.lastTriggeredAt,
    this.recurringAnchorAt,
    this.recurringLastScheduledAt,
  });

  factory CampaignStateRecord.fromJson(Map<String, dynamic> json) {
    return CampaignStateRecord(
      campaignId: json['campaign_id'] as String? ?? '',
      triggered: json['triggered'] == true,
      deliveryCount: (json['delivery_count'] as num? ?? 0).toInt(),
      lastTriggeredAt: json['last_triggered_at'] as String?,
      recurringAnchorAt: json['recurring_anchor_at'] as String?,
      recurringLastScheduledAt: json['recurring_last_scheduled_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id': campaignId,
      'triggered': triggered,
      'delivery_count': deliveryCount,
      if (lastTriggeredAt != null) 'last_triggered_at': lastTriggeredAt,
      if (recurringAnchorAt != null) 'recurring_anchor_at': recurringAnchorAt,
      if (recurringLastScheduledAt != null)
        'recurring_last_scheduled_at': recurringLastScheduledAt,
    };
  }
}

class CampaignQueuedMessage {
  final String messageId;
  final String campaignId;
  final String executeAt;
  final TriggerType triggerType;
  final String? triggerEventId;
  final String createdAt;

  CampaignQueuedMessage({
    required this.messageId,
    required this.campaignId,
    required this.executeAt,
    required this.triggerType,
    this.triggerEventId,
    required this.createdAt,
  });

  factory CampaignQueuedMessage.fromJson(Map<String, dynamic> json) {
    return CampaignQueuedMessage(
      messageId: json['message_id'] as String? ?? '',
      campaignId: json['campaign_id'] as String? ?? '',
      executeAt: json['execute_at'] as String? ?? '',
      triggerType: TriggerType.fromJson(json['trigger_type'] as String?),
      triggerEventId: json['trigger_event_id'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'campaign_id': campaignId,
      'execute_at': executeAt,
      'trigger_type': triggerType.toJson(),
      if (triggerEventId != null) 'trigger_event_id': triggerEventId,
      'created_at': createdAt,
    };
  }
}

class CampaignTriggerHistory {
  final String? campaignId;
  final String triggeredAt;

  CampaignTriggerHistory({this.campaignId, required this.triggeredAt});

  factory CampaignTriggerHistory.fromJson(Map<String, dynamic> json) {
    return CampaignTriggerHistory(
      campaignId: json['campaign_id'] as String?,
      triggeredAt: json['triggered_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (campaignId != null) 'campaign_id': campaignId,
      'triggered_at': triggeredAt,
    };
  }
}

class ClixConfig {
  final String endpoint;
  final String? projectId;
  final String? apiKey;
  final ClixLogLevel logLevel;
  final Map<String, String>? extraHeaders;
  final int? sessionTimeoutMs;

  ClixConfig({
    required this.endpoint,
    this.projectId,
    this.apiKey,
    this.logLevel = ClixLogLevel.warn,
    this.extraHeaders,
    this.sessionTimeoutMs,
  });
}

abstract class ClixClock {
  String now();
}

abstract class ClixLifecycleStateReader {
  String getAppState();

  void setAppState(String state) {}

  void dispose() {}
}

abstract class ClixLogger {
  void debug(String message, [Object? argument]);

  void info(String message, [Object? argument]);

  void warn(String message, [Object? argument]);

  void error(String message, [Object? argument]);

  void setLogLevel(ClixLogLevel level) {}
}

abstract class ClixLocalMessageScheduler {
  Future<void> schedule(QueuedMessage record);

  Future<void> cancel(String id);

  Future<List<QueuedMessage>> listPending();
}

abstract class CampaignStateRepositoryPort {
  Future<CampaignStateSnapshot> loadSnapshot(String now);

  Future<void> saveSnapshot(CampaignStateSnapshot snapshot);

  Future<void> clearCampaignState();

  Future<void> appendEvents(List<Event> events, [int maxEntries = 5000]);

  Future<List<Event>> loadEvents([int? limit]);

  Future<void> clearEvents();
}
