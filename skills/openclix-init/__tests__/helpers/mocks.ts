import type {
  Logger,
  MessageScheduler,
  CampaignStateRepositoryPort,
  CampaignStateSnapshot,
  QueuedMessage,
  Event,
  OpenClixLogLevel,
} from '../../templates/react-native/domain/OpenClixTypes';
import { makeEmptySnapshot } from './fixtures';

export interface MockLogger extends Logger {
  debugCalls: unknown[][];
  infoCalls: unknown[][];
  warnCalls: unknown[][];
  errorCalls: unknown[][];
}

export function createMockLogger(): MockLogger {
  const logger: MockLogger = {
    debugCalls: [],
    infoCalls: [],
    warnCalls: [],
    errorCalls: [],
    debug(msg: string, ...args: unknown[]) {
      logger.debugCalls.push([msg, ...args]);
    },
    info(msg: string, ...args: unknown[]) {
      logger.infoCalls.push([msg, ...args]);
    },
    warn(msg: string, ...args: unknown[]) {
      logger.warnCalls.push([msg, ...args]);
    },
    error(msg: string, ...args: unknown[]) {
      logger.errorCalls.push([msg, ...args]);
    },
    setLogLevel(_level: OpenClixLogLevel) {},
  };
  return logger;
}

export interface MockScheduler extends MessageScheduler {
  scheduledMessages: QueuedMessage[];
  cancelledIds: string[];
  pendingMessages: QueuedMessage[];
  scheduleError?: Error;
}

export function createMockScheduler(overrides?: {
  pendingMessages?: QueuedMessage[];
  scheduleError?: Error;
}): MockScheduler {
  const scheduler: MockScheduler = {
    scheduledMessages: [],
    cancelledIds: [],
    pendingMessages: overrides?.pendingMessages ?? [],
    scheduleError: overrides?.scheduleError,
    async schedule(record: QueuedMessage) {
      if (scheduler.scheduleError) throw scheduler.scheduleError;
      scheduler.scheduledMessages.push(record);
    },
    async cancel(id: string) {
      scheduler.cancelledIds.push(id);
    },
    async listPending() {
      return scheduler.pendingMessages;
    },
  };
  return scheduler;
}

export interface MockRepository extends CampaignStateRepositoryPort {
  savedSnapshots: CampaignStateSnapshot[];
  snapshot: CampaignStateSnapshot;
  saveError?: Error;
}

export function createMockRepository(
  snapshot?: CampaignStateSnapshot,
): MockRepository {
  const repo: MockRepository = {
    savedSnapshots: [],
    snapshot: snapshot ?? makeEmptySnapshot(),
    async loadSnapshot(_now: string) {
      return repo.snapshot;
    },
    async saveSnapshot(s: CampaignStateSnapshot) {
      if (repo.saveError) throw repo.saveError;
      repo.savedSnapshots.push(structuredClone(s));
    },
    async clearCampaignState() {
      repo.snapshot = makeEmptySnapshot();
    },
    async appendEvents() {},
    async loadEvents() { return []; },
    async clearEvents() {},
  };
  return repo;
}

export interface MockRecordEvent {
  (event: Event): Promise<void>;
  recordedEvents: Event[];
}

export function createMockRecordEvent(): MockRecordEvent {
  const fn = async (event: Event) => {
    fn.recordedEvents.push(event);
  };
  fn.recordedEvents = [] as Event[];
  return fn;
}
