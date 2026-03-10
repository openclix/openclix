import Foundation

public struct ResolvedContent: Equatable {
    public let title: String
    public let body: String
    public let image_url: String?
    public let landing_url: String?

    public init(
        title: String,
        body: String,
        image_url: String? = nil,
        landing_url: String? = nil
    ) {
        self.title = title
        self.body = body
        self.image_url = image_url
        self.landing_url = landing_url
    }
}

private let languageCodePattern = try! NSRegularExpression(pattern: "^[a-z]{2}$")

public final class LanguageResolver: @unchecked Sendable {

    private let lock = NSLock()
    private var explicitLanguage: String?
    private var settingsDefaultLanguage: String?
    private let sdkDefaultLanguage: String?
    private let deviceLocaleProvider: DeviceLocaleProvider?

    public init(
        sdkDefaultLanguage: String? = nil,
        deviceLocaleProvider: DeviceLocaleProvider? = nil
    ) {
        self.sdkDefaultLanguage = sdkDefaultLanguage
        self.deviceLocaleProvider = deviceLocaleProvider
    }

    public func setLanguage(_ languageCode: String) {
        lock.lock()
        defer { lock.unlock() }
        explicitLanguage = languageCode
    }

    public func getLanguage() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return explicitLanguage
    }

    public func clearLanguage() {
        lock.lock()
        defer { lock.unlock() }
        explicitLanguage = nil
    }

    public func setSettingsDefaultLanguage(_ language: String?) {
        lock.lock()
        defer { lock.unlock() }
        settingsDefaultLanguage = language
    }

    /// Resolution chain:
    /// 1. Explicit setLanguage()
    /// 2. Device locale (first 2 chars, lowercased)
    /// 3. Campaign default_language
    /// 4. Settings default_language (from remote config)
    /// 5. SDK defaultLanguage
    public func resolveLanguage(campaignDefaultLanguage: String? = nil) -> String? {
        lock.lock()
        let explicit = explicitLanguage
        let settingsDefault = settingsDefaultLanguage
        lock.unlock()

        if let explicit {
            return explicit
        }

        if let deviceLocale = deviceLocaleProvider?.getLocale() {
            let prefix = String(deviceLocale.prefix(2)).lowercased()
            let range = NSRange(prefix.startIndex..., in: prefix)
            if languageCodePattern.firstMatch(in: prefix, range: range) != nil {
                return prefix
            }
        }

        if let campaignDefaultLanguage {
            return campaignDefaultLanguage
        }

        if let settingsDefault {
            return settingsDefault
        }

        if let sdkDefaultLanguage {
            return sdkDefaultLanguage
        }

        return nil
    }

    /// Resolves localized content from a MessageContent.
    /// If no localized map or resolved language has no entry,
    /// returns flat title/body (backward compat).
    public func resolveContent(
        _ content: MessageContent,
        campaignDefaultLanguage: String? = nil
    ) -> ResolvedContent {
        guard let localized = content.localized, !localized.isEmpty else {
            return ResolvedContent(
                title: content.title,
                body: content.body,
                image_url: content.image_url,
                landing_url: content.landing_url
            )
        }

        let lang = resolveLanguage(campaignDefaultLanguage: campaignDefaultLanguage)
        if let lang, let entry = localized[lang] {
            return ResolvedContent(
                title: entry.title,
                body: entry.body,
                image_url: entry.image_url ?? content.image_url,
                landing_url: entry.landing_url ?? content.landing_url
            )
        }

        return ResolvedContent(
            title: content.title,
            body: content.body,
            image_url: content.image_url,
            landing_url: content.landing_url
        )
    }
}
