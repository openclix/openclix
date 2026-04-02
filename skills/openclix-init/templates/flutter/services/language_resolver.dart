import '../models/openclix_types.dart';

class ResolvedContent {
  final String title;
  final String body;
  final String? imageUrl;
  final String? landingUrl;

  ResolvedContent({
    required this.title,
    required this.body,
    this.imageUrl,
    this.landingUrl,
  });
}

class LanguageResolver {
  String? _explicitLanguage;
  String? _settingsDefaultLanguage;
  final String? _sdkDefaultLanguage;
  final DeviceLocaleProvider? _deviceLocaleProvider;

  static final RegExp _languageCodePattern = RegExp(r'^[a-z]{2}$');

  static String? _normalizeLanguageCode(String code) {
    final normalized = code.length >= 2
        ? code.substring(0, 2).toLowerCase()
        : code.toLowerCase();
    return _languageCodePattern.hasMatch(normalized) ? normalized : null;
  }

  LanguageResolver({
    String? sdkDefaultLanguage,
    DeviceLocaleProvider? deviceLocaleProvider,
  })  : _sdkDefaultLanguage = sdkDefaultLanguage != null ? _normalizeLanguageCode(sdkDefaultLanguage) : null,
        _deviceLocaleProvider = deviceLocaleProvider;

  void setLanguage(String languageCode) {
    _explicitLanguage = _normalizeLanguageCode(languageCode);
  }

  String? getLanguage() {
    return _explicitLanguage;
  }

  void clearLanguage() {
    _explicitLanguage = null;
  }

  void setSettingsDefaultLanguage(String? language) {
    _settingsDefaultLanguage = language != null ? _normalizeLanguageCode(language) : null;
  }

  /// Resolution chain:
  /// 1. Explicit setLanguage()
  /// 2. Device locale (first 2 chars, lowercased)
  /// 3. Campaign default_language
  /// 4. Settings default_language (from remote config)
  /// 5. SDK defaultLanguage
  String? resolveLanguage({String? campaignDefaultLanguage}) {
    if (_explicitLanguage != null) return _explicitLanguage;

    final deviceLocale = _deviceLocaleProvider?.getLocale();
    if (deviceLocale != null) {
      final normalized = _normalizeLanguageCode(deviceLocale);
      if (normalized != null) return normalized;
    }

    if (campaignDefaultLanguage != null) return campaignDefaultLanguage;
    if (_settingsDefaultLanguage != null) return _settingsDefaultLanguage;
    if (_sdkDefaultLanguage != null) return _sdkDefaultLanguage;

    return null;
  }

  /// Resolves localized content from a MessageContent.
  /// If no localized map or resolved language has no entry,
  /// returns flat title/body (backward compat).
  ResolvedContent resolveContent(
    MessageContent content, {
    String? campaignDefaultLanguage,
  }) {
    if (content.localized == null || content.localized!.isEmpty) {
      return ResolvedContent(
        title: content.title,
        body: content.body,
        imageUrl: content.imageUrl,
        landingUrl: content.landingUrl,
      );
    }

    final lang = resolveLanguage(
      campaignDefaultLanguage: campaignDefaultLanguage,
    );
    if (lang != null && content.localized!.containsKey(lang)) {
      final entry = content.localized![lang]!;
      return ResolvedContent(
        title: entry.title,
        body: entry.body,
        imageUrl: entry.imageUrl ?? content.imageUrl,
        landingUrl: entry.landingUrl ?? content.landingUrl,
      );
    }

    return ResolvedContent(
      title: content.title,
      body: content.body,
      imageUrl: content.imageUrl,
      landingUrl: content.landingUrl,
    );
  }
}
