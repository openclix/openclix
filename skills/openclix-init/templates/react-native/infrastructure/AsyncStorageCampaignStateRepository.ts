import AsyncStorage from '@react-native-async-storage/async-storage';
import type { CampaignStateRepositoryPort } from '../domain/ClixTypes';
import { CampaignStateRepository } from './CampaignStateRepository';

export function createAsyncStorageCampaignStateRepository(): CampaignStateRepositoryPort {
  return new CampaignStateRepository(AsyncStorage);
}
