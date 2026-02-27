import 'dart:convert';
import 'dart:io';

import '../models/clix_types.dart';

const int defaultMaxEventLogSize = 5000;

CampaignStateSnapshot createDefaultCampaignStateSnapshot(String now) {
  return CampaignStateSnapshot(
    campaignStates: [],
    queuedMessages: [],
    triggerHistory: [],
    updatedAt: now,
  );
}

CampaignStateSnapshot normalizeCampaignStateSnapshot(
  CampaignStateSnapshot? snapshot,
  String now,
) {
  if (snapshot == null) {
    return createDefaultCampaignStateSnapshot(now);
  }

  final updatedAt = isNonEmptyString(snapshot.updatedAt)
      ? snapshot.updatedAt
      : now;
  return CampaignStateSnapshot(
    campaignStates: snapshot.campaignStates,
    queuedMessages: snapshot.queuedMessages,
    triggerHistory: snapshot.triggerHistory,
    updatedAt: updatedAt,
  );
}

bool isNonEmptyString(Object? value) {
  return value is String && value.isNotEmpty;
}

class FileCampaignStateRepository implements CampaignStateRepositoryPort {
  final String storagePath;
  late final File campaignStateFile;
  late final File eventsFile;

  FileCampaignStateRepository({required this.storagePath}) {
    campaignStateFile = File('$storagePath/openclix_campaign_state.json');
    eventsFile = File('$storagePath/openclix_events.json');
  }

  @override
  Future<CampaignStateSnapshot> loadSnapshot(String now) async {
    try {
      if (!await campaignStateFile.exists()) {
        return createDefaultCampaignStateSnapshot(now);
      }

      final raw = await campaignStateFile.readAsString();
      if (raw.trim().isEmpty) {
        return createDefaultCampaignStateSnapshot(now);
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return createDefaultCampaignStateSnapshot(now);
      }

      final snapshot = CampaignStateSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      return normalizeCampaignStateSnapshot(snapshot, now);
    } catch (_) {
      return createDefaultCampaignStateSnapshot(now);
    }
  }

  @override
  Future<void> saveSnapshot(CampaignStateSnapshot snapshot) async {
    final normalized = normalizeCampaignStateSnapshot(
      snapshot,
      snapshot.updatedAt,
    );
    await campaignStateFile.parent.create(recursive: true);
    await campaignStateFile.writeAsString(
      jsonEncode(normalized.toJson()),
      flush: true,
    );
  }

  @override
  Future<void> clearCampaignState() async {
    if (await campaignStateFile.exists()) {
      await campaignStateFile.delete();
    }
  }

  @override
  Future<void> appendEvents(
    List<Event> events, [
    int maxEntries = defaultMaxEventLogSize,
  ]) async {
    if (events.isEmpty) {
      return;
    }

    final existingEvents = await loadAllEvents();
    final mergedById = <String, Event>{};

    for (final existingEvent in existingEvents) {
      mergedById[existingEvent.id] = existingEvent;
    }

    for (final event in events) {
      final normalized = normalizeEventRecord(event.toJson());
      if (normalized == null) {
        continue;
      }
      mergedById[normalized.id] = normalized;
    }

    final merged = mergedById.values.toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final cap = maxEntries < 1
        ? 1
        : (maxEntries > defaultMaxEventLogSize
              ? defaultMaxEventLogSize
              : maxEntries);
    final trimmed = merged.length > cap
        ? merged.sublist(merged.length - cap)
        : merged;

    await eventsFile.parent.create(recursive: true);
    await eventsFile.writeAsString(
      jsonEncode(trimmed.map((event) => event.toJson()).toList()),
      flush: true,
    );
  }

  @override
  Future<List<Event>> loadEvents([int? limit]) async {
    final events = await loadAllEvents();

    if (limit == null) {
      return events;
    }

    if (limit <= 0) {
      return const [];
    }

    if (events.length <= limit) {
      return events;
    }

    return events.sublist(events.length - limit);
  }

  @override
  Future<void> clearEvents() async {
    if (await eventsFile.exists()) {
      await eventsFile.delete();
    }
  }

  Future<List<Event>> loadAllEvents() async {
    try {
      if (!await eventsFile.exists()) {
        return const [];
      }

      final raw = await eventsFile.readAsString();
      if (raw.trim().isEmpty) {
        return const [];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final events = <Event>[];
      for (final row in decoded) {
        final normalized = normalizeEventRecord(row);
        if (normalized != null) {
          events.add(normalized);
        }
      }

      events.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      return events;
    } catch (_) {
      return const [];
    }
  }

  Event? normalizeEventRecord(Object? value) {
    if (value is! Map) {
      return null;
    }

    final row = Map<String, dynamic>.from(value);

    final id = row['id'];
    final name = row['name'];
    final createdAt = row['created_at'];
    final sourceType = row['source_type'];

    if (!isNonEmptyString(id) ||
        !isNonEmptyString(name) ||
        !isNonEmptyString(createdAt)) {
      return null;
    }

    if (sourceType != EventSourceType.app.value &&
        sourceType != EventSourceType.system.value) {
      return null;
    }

    final rawProperties = row['properties'];

    return Event(
      id: id as String,
      name: name as String,
      sourceType: EventSourceType.fromJson(sourceType as String?),
      properties: rawProperties is Map
          ? Map<String, JsonValue>.from(rawProperties)
          : null,
      createdAt: createdAt as String,
    );
  }
}
