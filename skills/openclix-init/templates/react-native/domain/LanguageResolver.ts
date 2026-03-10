import type { MessageContent, DeviceLocaleProvider } from './OpenClixTypes';

export interface LanguageResolverConfig {
  sdkDefaultLanguage?: string;
  deviceLocaleProvider?: DeviceLocaleProvider;
}

export class LanguageResolver {
  private explicitLanguage: string | undefined;
  private settingsDefaultLanguage: string | undefined;
  private readonly sdkDefaultLanguage: string | undefined;
  private readonly deviceLocaleProvider: DeviceLocaleProvider | undefined;

  constructor(config: LanguageResolverConfig) {
    this.sdkDefaultLanguage = config.sdkDefaultLanguage;
    this.deviceLocaleProvider = config.deviceLocaleProvider;
  }

  setLanguage(languageCode: string): void {
    const normalized = languageCode.substring(0, 2).toLowerCase();
    this.explicitLanguage = /^[a-z]{2}$/.test(normalized) ? normalized : undefined;
  }

  getLanguage(): string | undefined {
    return this.explicitLanguage;
  }

  clearLanguage(): void {
    this.explicitLanguage = undefined;
  }

  setSettingsDefaultLanguage(language: string | undefined): void {
    this.settingsDefaultLanguage = language;
  }

  /**
   * Resolution chain:
   * 1. Explicit setLanguage()
   * 2. Device locale (first 2 chars, lowercased)
   * 3. Campaign default_language
   * 4. Settings default_language (from remote config)
   * 5. SDK defaultLanguage
   */
  resolveLanguage(campaignDefaultLanguage?: string): string | undefined {
    if (this.explicitLanguage) return this.explicitLanguage;

    const deviceLocale = this.deviceLocaleProvider?.getLocale();
    if (deviceLocale) {
      const normalized = deviceLocale.substring(0, 2).toLowerCase();
      if (/^[a-z]{2}$/.test(normalized)) return normalized;
    }

    if (campaignDefaultLanguage) return campaignDefaultLanguage;
    if (this.settingsDefaultLanguage) return this.settingsDefaultLanguage;
    if (this.sdkDefaultLanguage) return this.sdkDefaultLanguage;

    return undefined;
  }

  /**
   * Resolves localized content from a MessageContent.
   * If no localized map or resolved language has no entry,
   * returns flat title/body (backward compat).
   */
  resolveContent(
    content: MessageContent,
    campaignDefaultLanguage?: string,
  ): { title: string; body: string; image_url?: string; landing_url?: string } {
    if (!content.localized || Object.keys(content.localized).length === 0) {
      return {
        title: content.title,
        body: content.body,
        image_url: content.image_url,
        landing_url: content.landing_url,
      };
    }

    const lang = this.resolveLanguage(campaignDefaultLanguage);
    if (lang && content.localized[lang]) {
      const entry = content.localized[lang];
      return {
        title: entry.title,
        body: entry.body,
        image_url: entry.image_url ?? content.image_url,
        landing_url: entry.landing_url ?? content.landing_url,
      };
    }

    return {
      title: content.title,
      body: content.body,
      image_url: content.image_url,
      landing_url: content.landing_url,
    };
  }
}
