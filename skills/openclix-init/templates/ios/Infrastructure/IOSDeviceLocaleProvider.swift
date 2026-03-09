import Foundation

public class IOSDeviceLocaleProvider: DeviceLocaleProvider {
    public init() {}

    public func getLocale() -> String? {
        if #available(iOS 16.0, macOS 13.0, *) {
            return Locale.current.language.languageCode?.identifier
                ?? Locale.preferredLanguages.first
        } else {
            return Locale.current.languageCode
                ?? Locale.preferredLanguages.first
        }
    }
}
