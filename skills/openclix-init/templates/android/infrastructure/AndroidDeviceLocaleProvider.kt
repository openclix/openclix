package ai.openclix.infrastructure

import ai.openclix.models.DeviceLocaleProvider
import java.util.Locale

class AndroidDeviceLocaleProvider : DeviceLocaleProvider {
    override fun getLocale(): String? {
        return try {
            Locale.getDefault().language  // Returns ISO 639-1 code
        } catch (e: Exception) {
            null
        }
    }
}
