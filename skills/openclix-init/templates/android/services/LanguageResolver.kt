package ai.openclix.services

import ai.openclix.models.DeviceLocaleProvider
import ai.openclix.models.MessageContent

data class ResolvedContent(
    val title: String,
    val body: String,
    val image_url: String? = null,
    val landing_url: String? = null
)

class LanguageResolver(
    sdkDefaultLanguage: String? = null,
    private val deviceLocaleProvider: DeviceLocaleProvider? = null
) {
    companion object {
        private val LANGUAGE_CODE_PATTERN = Regex("^[a-z]{2}$")

        private fun normalizeLanguageCode(code: String): String? {
            val normalized = code.take(2).lowercase(java.util.Locale.ROOT)
            return if (LANGUAGE_CODE_PATTERN.matches(normalized)) normalized else null
        }
    }

    private val sdkDefaultLanguage: String? = sdkDefaultLanguage?.let { normalizeLanguageCode(it) }

    @Volatile
    private var explicitLanguage: String? = null

    @Volatile
    private var settingsDefaultLanguage: String? = null

    fun setLanguage(languageCode: String) {
        explicitLanguage = normalizeLanguageCode(languageCode)
    }

    fun getLanguage(): String? = explicitLanguage

    fun clearLanguage() {
        explicitLanguage = null
    }

    fun setSettingsDefaultLanguage(language: String?) {
        settingsDefaultLanguage = language?.let { normalizeLanguageCode(it) }
    }

    /**
     * Resolution chain:
     * 1. Explicit setLanguage()
     * 2. Device locale (first 2 chars, lowercased)
     * 3. Campaign default_language
     * 4. Settings default_language (from remote config)
     * 5. SDK defaultLanguage
     */
    fun resolveLanguage(campaignDefaultLanguage: String? = null): String? {
        if (explicitLanguage != null) return explicitLanguage

        val deviceLocale = deviceLocaleProvider?.getLocale()
        if (deviceLocale != null) {
            val normalized = normalizeLanguageCode(deviceLocale)
            if (normalized != null) return normalized
        }

        if (campaignDefaultLanguage != null) return campaignDefaultLanguage
        if (settingsDefaultLanguage != null) return settingsDefaultLanguage
        if (sdkDefaultLanguage != null) return sdkDefaultLanguage

        return null
    }

    /**
     * Resolves localized content from a MessageContent.
     * If no localized map or resolved language has no entry,
     * returns flat title/body (backward compat).
     */
    fun resolveContent(
        content: MessageContent,
        campaignDefaultLanguage: String? = null
    ): ResolvedContent {
        if (content.localized.isNullOrEmpty()) {
            return ResolvedContent(
                title = content.title,
                body = content.body,
                image_url = content.image_url,
                landing_url = content.landing_url
            )
        }

        val lang = resolveLanguage(campaignDefaultLanguage)
        if (lang != null && content.localized.containsKey(lang)) {
            val entry = content.localized[lang]!!
            return ResolvedContent(
                title = entry.title,
                body = entry.body,
                image_url = entry.image_url ?: content.image_url,
                landing_url = entry.landing_url ?: content.landing_url
            )
        }

        return ResolvedContent(
            title = content.title,
            body = content.body,
            image_url = content.image_url,
            landing_url = content.landing_url
        )
    }
}
