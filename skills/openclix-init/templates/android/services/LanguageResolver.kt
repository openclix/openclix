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
    private val sdkDefaultLanguage: String? = null,
    private val deviceLocaleProvider: DeviceLocaleProvider? = null
) {
    private var explicitLanguage: String? = null

    fun setLanguage(languageCode: String) {
        explicitLanguage = languageCode
    }

    fun getLanguage(): String? = explicitLanguage

    fun clearLanguage() {
        explicitLanguage = null
    }

    /**
     * Resolution chain:
     * 1. Explicit setLanguage()
     * 2. Device locale (first 2 chars, lowercased)
     * 3. Campaign default_language
     * 4. SDK defaultLanguage
     */
    fun resolveLanguage(campaignDefaultLanguage: String? = null): String? {
        if (explicitLanguage != null) return explicitLanguage

        val deviceLocale = deviceLocaleProvider?.getLocale()
        if (deviceLocale != null) {
            val normalized = deviceLocale.take(2).lowercase()
            if (Regex("^[a-z]{2}$").matches(normalized)) return normalized
        }

        if (campaignDefaultLanguage != null) return campaignDefaultLanguage
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
