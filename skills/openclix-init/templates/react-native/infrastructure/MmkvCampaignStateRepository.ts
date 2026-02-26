import { MMKV } from 'react-native-mmkv';
import type { CampaignStateRepositoryPort } from '../domain/ClixTypes';
import {
  CampaignStateRepository,
  type StorageEngine,
} from './CampaignStateRepository';

const OPENCLIX_MMKV_ID = 'openclix';

class MmkvStorageEngine implements StorageEngine {
  constructor(private readonly mmkvStorage: MMKV) {}

  async getItem(key: string): Promise<string | null> {
    const value = this.mmkvStorage.getString(key);
    return typeof value === 'string' ? value : null;
  }

  async setItem(key: string, value: string): Promise<void> {
    this.mmkvStorage.set(key, value);
  }

  async removeItem(key: string): Promise<void> {
    this.mmkvStorage.delete(key);
  }

  async multiGet(keys: string[]): Promise<Array<[string, string | null]>> {
    return keys.map((key) => {
      const value = this.mmkvStorage.getString(key);
      return [key, typeof value === 'string' ? value : null];
    });
  }

  async multiSet(keyValuePairs: Array<[string, string]>): Promise<void> {
    keyValuePairs.forEach(([key, value]) => {
      this.mmkvStorage.set(key, value);
    });
  }

  async multiRemove(keys: string[]): Promise<void> {
    keys.forEach((key) => {
      this.mmkvStorage.delete(key);
    });
  }
}

export function createMmkvCampaignStateRepository(): CampaignStateRepositoryPort {
  const mmkvStorage = new MMKV({ id: OPENCLIX_MMKV_ID });
  return new CampaignStateRepository(new MmkvStorageEngine(mmkvStorage));
}
