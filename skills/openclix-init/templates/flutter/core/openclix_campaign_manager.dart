import '../models/openclix_types.dart';
import '../services/config_validator.dart';
import '../store/campaign_state_repository.dart';
import 'openclix.dart';

void assertOpenClixInitialized() {
  if (!OpenClix.isInitializedInternal()) {
    throw StateError(
      'OpenClix is not initialized. Call OpenClix.initialize() before using OpenClixCampaignManager.',
    );
  }
}

class OpenClixCampaignManager {
  OpenClixCampaignManager._();

  static Future<TriggerResult?> replaceConfig(Config config) async {
    assertOpenClixInitialized();

    final logger = OpenClix.getLoggerInternal();
    final triggerService = OpenClix.getTriggerServiceInternal();

    if (triggerService == null) {
      logger?.error('Cannot replace config: trigger service is not available.');
      return null;
    }

    final validationResult = validateConfig(config);

    if (!validationResult.valid) {
      for (final error in validationResult.errors) {
        logger?.error(
          'Config validation error [${error.code}]: ${error.message}',
        );
      }
      logger?.warn('Config replacement rejected due to validation errors.');
      return null;
    }

    for (final warning in validationResult.warnings) {
      logger?.warn(
        'Config validation warning [${warning.code}]: ${warning.message}',
      );
    }

    triggerService.replaceConfig(config);

    logger?.info(
      'Config replaced '
      '(version: ${config.configVersion}, campaigns: ${config.campaigns.length})',
    );

    try {
      return await triggerService.trigger(
        TriggerContext(
          trigger: 'config_replaced',
          now: OpenClix.getClockInternal()?.now(),
        ),
      );
    } catch (error) {
      logger?.error('Evaluation after config replacement failed:', error);
      return null;
    }
  }

  static Config? getConfig() {
    assertOpenClixInitialized();
    return OpenClix.getTriggerServiceInternal()?.getConfig();
  }

  static Future<CampaignStateSnapshot> getSnapshot() async {
    assertOpenClixInitialized();

    final campaignStateRepository = OpenClix.getCampaignStateRepositoryInternal();
    if (campaignStateRepository == null) {
      return createDefaultCampaignStateSnapshot(
        DateTime.now().toUtc().toIso8601String(),
      );
    }

    try {
      return await campaignStateRepository.loadSnapshot(
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (error) {
      OpenClix.getLoggerInternal()?.warn(
        'Failed to load campaign state snapshot:',
        error,
      );

      return createDefaultCampaignStateSnapshot(
        DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  static Future<List<QueuedMessage>> getScheduledMessages({
    String? campaignId,
    String? status,
  }) async {
    assertOpenClixInitialized();

    final messageScheduler = OpenClix.getMessageSchedulerInternal();
    if (messageScheduler == null) {
      return const [];
    }

    List<QueuedMessage> pendingMessages;
    try {
      pendingMessages = await messageScheduler.listPending();
    } catch (error) {
      OpenClix.getLoggerInternal()?.error(
        'Failed to list pending messages:',
        error,
      );
      return const [];
    }

    if (campaignId == null && status == null) {
      return pendingMessages;
    }

    return pendingMessages.where((message) {
      if (campaignId != null && message.campaignId != campaignId) {
        return false;
      }
      if (status != null && message.status.value != status) {
        return false;
      }
      return true;
    }).toList();
  }

  static Future<List<Event>> getEventLog([int? limit]) async {
    assertOpenClixInitialized();

    final campaignStateRepository = OpenClix.getCampaignStateRepositoryInternal();
    if (campaignStateRepository == null) {
      return const [];
    }

    try {
      return campaignStateRepository.loadEvents(limit);
    } catch (error) {
      OpenClix.getLoggerInternal()?.error('Failed to load event log:', error);
      return const [];
    }
  }
}
