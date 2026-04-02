import { describe, test, expect } from 'bun:test';
import { LanguageResolver } from '../templates/react-native/domain/LanguageResolver';
import type { MessageContent, DeviceLocaleProvider } from '../templates/react-native/domain/OpenClixTypes';

function makeResolver(opts?: {
  sdkDefaultLanguage?: string;
  deviceLocaleProvider?: DeviceLocaleProvider;
}): LanguageResolver {
  return new LanguageResolver({
    sdkDefaultLanguage: opts?.sdkDefaultLanguage,
    deviceLocaleProvider: opts?.deviceLocaleProvider,
  });
}

function makeContent(overrides?: Partial<MessageContent>): MessageContent {
  return {
    title: 'Default Title',
    body: 'Default Body',
    ...overrides,
  };
}

describe('LanguageResolver', () => {
  describe('resolution chain', () => {
    test('returns explicit language when set via setLanguage()', () => {
      const resolver = makeResolver();
      resolver.setLanguage('ko');
      expect(resolver.resolveLanguage()).toBe('ko');
    });

    test('returns device locale when no explicit language set', () => {
      const resolver = makeResolver({
        deviceLocaleProvider: { getLocale: () => 'ja' },
      });
      expect(resolver.resolveLanguage()).toBe('ja');
    });

    test('device locale is normalized to 2-char lowercase', () => {
      const resolver = makeResolver({
        deviceLocaleProvider: { getLocale: () => 'en_US' },
      });
      expect(resolver.resolveLanguage()).toBe('en');
    });

    test('returns campaign default when no explicit or device locale', () => {
      const resolver = makeResolver();
      expect(resolver.resolveLanguage('fr')).toBe('fr');
    });

    test('returns settings default when no explicit, device, or campaign default', () => {
      const resolver = makeResolver({ sdkDefaultLanguage: 'de' });
      resolver.setSettingsDefaultLanguage('zh');
      expect(resolver.resolveLanguage()).toBe('zh');
    });

    test('returns SDK default when no explicit, device, campaign, or settings default', () => {
      const resolver = makeResolver({ sdkDefaultLanguage: 'de' });
      expect(resolver.resolveLanguage()).toBe('de');
    });

    test('settings default takes priority over SDK default but not campaign default', () => {
      const resolver = makeResolver({ sdkDefaultLanguage: 'de' });
      resolver.setSettingsDefaultLanguage('zh');
      expect(resolver.resolveLanguage()).toBe('zh');
      expect(resolver.resolveLanguage('fr')).toBe('fr');
    });

    test('returns undefined when nothing is configured', () => {
      const resolver = makeResolver();
      expect(resolver.resolveLanguage()).toBeUndefined();
    });

    test('priority: explicit > device > campaign > SDK', () => {
      const resolver = makeResolver({
        sdkDefaultLanguage: 'de',
        deviceLocaleProvider: { getLocale: () => 'ja' },
      });
      resolver.setLanguage('ko');
      resolver.setSettingsDefaultLanguage('zh');
      expect(resolver.resolveLanguage('fr')).toBe('ko');
    });
  });

  describe('setLanguage / getLanguage / clearLanguage', () => {
    test('getLanguage() returns undefined initially', () => {
      const resolver = makeResolver();
      expect(resolver.getLanguage()).toBeUndefined();
    });

    test('setLanguage sets and getLanguage returns the value', () => {
      const resolver = makeResolver();
      resolver.setLanguage('ko');
      expect(resolver.getLanguage()).toBe('ko');
    });

    test('clearLanguage resets to undefined', () => {
      const resolver = makeResolver();
      resolver.setLanguage('ko');
      resolver.clearLanguage();
      expect(resolver.getLanguage()).toBeUndefined();
    });

    test('setLanguage normalizes input (e.g., EN -> en, en-US -> en)', () => {
      const resolver = makeResolver();
      resolver.setLanguage('EN');
      expect(resolver.getLanguage()).toBe('en');
      resolver.setLanguage('ko-KR');
      expect(resolver.getLanguage()).toBe('ko');
    });

    test('after clear, falls back to next in chain', () => {
      const resolver = makeResolver({
        deviceLocaleProvider: { getLocale: () => 'ja' },
      });
      resolver.setLanguage('ko');
      expect(resolver.resolveLanguage()).toBe('ko');
      resolver.clearLanguage();
      expect(resolver.resolveLanguage()).toBe('ja');
    });
  });

  describe('resolveContent', () => {
    test('returns flat content when no localized map exists (backward compat)', () => {
      const resolver = makeResolver();
      resolver.setLanguage('ko');
      const content = makeContent();
      const resolved = resolver.resolveContent(content);
      expect(resolved.title).toBe('Default Title');
      expect(resolved.body).toBe('Default Body');
    });

    test('returns flat content when localized map is empty', () => {
      const resolver = makeResolver();
      resolver.setLanguage('ko');
      const content = makeContent({ localized: {} });
      const resolved = resolver.resolveContent(content);
      expect(resolved.title).toBe('Default Title');
      expect(resolved.body).toBe('Default Body');
    });

    test('returns localized content for resolved language', () => {
      const resolver = makeResolver();
      resolver.setLanguage('ko');
      const content = makeContent({
        localized: {
          ko: { title: 'Korean Title', body: 'Korean Body' },
          ja: { title: 'Japanese Title', body: 'Japanese Body' },
        },
      });
      const resolved = resolver.resolveContent(content);
      expect(resolved.title).toBe('Korean Title');
      expect(resolved.body).toBe('Korean Body');
    });

    test('falls back to flat content when resolved language not in map', () => {
      const resolver = makeResolver();
      resolver.setLanguage('zh');
      const content = makeContent({
        localized: {
          ko: { title: 'Korean Title', body: 'Korean Body' },
        },
      });
      const resolved = resolver.resolveContent(content);
      expect(resolved.title).toBe('Default Title');
      expect(resolved.body).toBe('Default Body');
    });

    test('localized entry image_url/landing_url override flat values', () => {
      const resolver = makeResolver();
      resolver.setLanguage('ko');
      const content = makeContent({
        image_url: 'https://example.com/default.png',
        landing_url: 'https://example.com/default',
        localized: {
          ko: {
            title: 'Korean Title',
            body: 'Korean Body',
            image_url: 'https://example.com/ko.png',
            landing_url: 'https://example.com/ko',
          },
        },
      });
      const resolved = resolver.resolveContent(content);
      expect(resolved.image_url).toBe('https://example.com/ko.png');
      expect(resolved.landing_url).toBe('https://example.com/ko');
    });

    test('when localized entry lacks image_url/landing_url, falls back to flat values', () => {
      const resolver = makeResolver();
      resolver.setLanguage('ko');
      const content = makeContent({
        image_url: 'https://example.com/default.png',
        landing_url: 'https://example.com/default',
        localized: {
          ko: { title: 'Korean Title', body: 'Korean Body' },
        },
      });
      const resolved = resolver.resolveContent(content);
      expect(resolved.title).toBe('Korean Title');
      expect(resolved.body).toBe('Korean Body');
      expect(resolved.image_url).toBe('https://example.com/default.png');
      expect(resolved.landing_url).toBe('https://example.com/default');
    });
  });
});
