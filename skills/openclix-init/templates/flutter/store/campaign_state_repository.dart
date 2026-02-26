import 'dart:convert';
import 'dart:io';

import '../models/clix_types.dart';

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

  FileCampaignStateRepository({required this.storagePath}) {
    campaignStateFile = File('$storagePath/openclix_campaign_state.json');
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
}
