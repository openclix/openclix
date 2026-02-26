import Foundation
import UserNotifications

public final class LocalNotificationScheduler: ClixMessageScheduler {

    private static let campaignIdKey = "openclix_campaign_id"
    private static let identifierKey = "openclix_id"
    private static let channelTypeKey = "openclix_channel_type"
    private static let statusKey = "openclix_status"
    private static let executeAtKey = "openclix_execute_at"
    private static let createdAtKey = "openclix_created_at"
    private static let contentTitleKey = "openclix_content_title"
    private static let contentBodyKey = "openclix_content_body"
    private static let imageUrlKey = "openclix_image_url"
    private static let landingUrlKey = "openclix_landing_url"
    private static let triggerEventIdKey = "openclix_trigger_event_id"

    public init() {}

    public func schedule(_ record: QueuedMessage) async throws {
        let content = UNMutableNotificationContent()
        content.title = record.content.title
        content.body = record.content.body
        content.sound = .default

        var userInfo: [String: Any] = [
            LocalNotificationScheduler.identifierKey: record.id,
            LocalNotificationScheduler.campaignIdKey: record.campaign_id,
            LocalNotificationScheduler.channelTypeKey: record.channel_type.rawValue,
            LocalNotificationScheduler.statusKey: record.status.rawValue,
            LocalNotificationScheduler.executeAtKey: record.execute_at,
            LocalNotificationScheduler.createdAtKey: record.created_at,
            LocalNotificationScheduler.contentTitleKey: record.content.title,
            LocalNotificationScheduler.contentBodyKey: record.content.body,
        ]

        if let imageUrl = record.content.image_url {
            userInfo[LocalNotificationScheduler.imageUrlKey] = imageUrl
        }
        if let landingUrl = record.content.landing_url {
            userInfo[LocalNotificationScheduler.landingUrlKey] = landingUrl
        }
        if let triggerEventId = record.trigger_event_id {
            userInfo[LocalNotificationScheduler.triggerEventIdKey] = triggerEventId
        }

        content.userInfo = userInfo

        let scheduledDate = parseIsoDate(record.execute_at) ?? Date()
        let interval = max(scheduledDate.timeIntervalSinceNow, 1)

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: record.id,
            content: content,
            trigger: trigger
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    public func cancel(_ id: String) async throws {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    public func listPending() async throws -> [QueuedMessage] {
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        var pendingMessages: [QueuedMessage] = []

        for request in pendingRequests {
            let userInfo = request.content.userInfo

            guard let identifier = userInfo[LocalNotificationScheduler.identifierKey] as? String,
                  let campaignId = userInfo[LocalNotificationScheduler.campaignIdKey] as? String else {
                continue
            }

            let channelTypeRaw =
                userInfo[LocalNotificationScheduler.channelTypeKey] as? String
                ?? ChannelType.app_push.rawValue
            let channelType = ChannelType(rawValue: channelTypeRaw) ?? .app_push

            let statusRaw =
                userInfo[LocalNotificationScheduler.statusKey] as? String
                ?? QueuedMessageStatus.scheduled.rawValue
            let status = QueuedMessageStatus(rawValue: statusRaw) ?? .scheduled

            let executeAt =
                userInfo[LocalNotificationScheduler.executeAtKey] as? String
                ?? formatIsoDate(Date())
            let createdAt =
                userInfo[LocalNotificationScheduler.createdAtKey] as? String
                ?? formatIsoDate(Date())

            let contentTitle =
                userInfo[LocalNotificationScheduler.contentTitleKey] as? String
                ?? request.content.title
            let contentBody =
                userInfo[LocalNotificationScheduler.contentBodyKey] as? String
                ?? request.content.body

            let imageUrl = userInfo[LocalNotificationScheduler.imageUrlKey] as? String
            let landingUrl = userInfo[LocalNotificationScheduler.landingUrlKey] as? String
            let triggerEventId = userInfo[LocalNotificationScheduler.triggerEventIdKey] as? String

            pendingMessages.append(
                QueuedMessage(
                    id: identifier,
                    campaign_id: campaignId,
                    channel_type: channelType,
                    status: status,
                    content: QueuedMessageContent(
                        title: contentTitle,
                        body: contentBody,
                        image_url: imageUrl,
                        landing_url: landingUrl
                    ),
                    trigger_event_id: triggerEventId,
                    execute_at: executeAt,
                    created_at: createdAt
                )
            )
        }

        return pendingMessages
    }
}

private func parseIsoDate(_ value: String) -> Date? {
    let internetFormatter = ISO8601DateFormatter()
    internetFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = internetFormatter.date(from: value) {
        return parsed
    }
    return ISO8601DateFormatter().date(from: value)
}

private func formatIsoDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}
