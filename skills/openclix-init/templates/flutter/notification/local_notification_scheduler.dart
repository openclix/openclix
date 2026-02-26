import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as timezone;

import '../models/clix_types.dart';

class LocalNotificationScheduler implements ClixLocalMessageScheduler {
  final FlutterLocalNotificationsPlugin plugin;
  final Map<String, QueuedMessage> pendingRecordsById = {};

  LocalNotificationScheduler({required this.plugin});

  @override
  Future<void> schedule(QueuedMessage record) async {
    final scheduledTime =
        DateTime.tryParse(record.executeAt)?.toLocal() ?? DateTime.now();
    final now = DateTime.now();

    final notificationId = record.id.hashCode.abs() % 2147483647;
    final payloadJson = jsonEncode(record.toJson());

    const androidDetails = AndroidNotificationDetails(
      'openclix_campaign',
      'Campaign Notifications',
      channelDescription: 'Notifications from OpenClix campaign engine',
      importance: Importance.high,
      priority: Priority.high,
    );

    const appleDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: appleDetails,
      macOS: appleDetails,
    );

    if (scheduledTime.isAfter(now)) {
      final scheduledTimeWithTimezone = timezone.TZDateTime.from(
        scheduledTime,
        timezone.local,
      );
      await plugin.zonedSchedule(
        notificationId,
        record.content.title,
        record.content.body,
        scheduledTimeWithTimezone,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payloadJson,
      );
    } else {
      await plugin.show(
        notificationId,
        record.content.title,
        record.content.body,
        notificationDetails,
        payload: payloadJson,
      );
    }

    pendingRecordsById[record.id] = record;
  }

  @override
  Future<void> cancel(String id) async {
    final notificationId = id.hashCode.abs() % 2147483647;
    await plugin.cancel(notificationId);
    pendingRecordsById.remove(id);
  }

  @override
  Future<List<QueuedMessage>> listPending() async {
    return pendingRecordsById.values
        .where((message) => message.status == QueuedMessageStatus.scheduled)
        .toList();
  }
}
