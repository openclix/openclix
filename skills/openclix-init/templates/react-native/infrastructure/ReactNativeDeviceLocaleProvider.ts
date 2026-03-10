import type { DeviceLocaleProvider } from '../domain/OpenClixTypes';
import { Platform, NativeModules } from 'react-native';

export class ReactNativeDeviceLocaleProvider implements DeviceLocaleProvider {
  getLocale(): string | undefined {
    try {
      if (Platform.OS === 'ios') {
        const locale =
          NativeModules.SettingsManager?.settings?.AppleLocale ??
          NativeModules.SettingsManager?.settings?.AppleLanguages?.[0];
        return typeof locale === 'string' ? locale : undefined;
      }
      if (Platform.OS === 'android') {
        const locale = NativeModules.I18nManager?.localeIdentifier;
        return typeof locale === 'string' ? locale : undefined;
      }
    } catch {
      return undefined;
    }
    return undefined;
  }
}
