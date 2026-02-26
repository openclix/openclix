import '../models/clix_types.dart';

typedef ScheduleNotificationCallback = Future<void> Function(
  QueuedMessage queuedMessage,
);
typedef CancelNotificationCallback = Future<void> Function(String messageId);
typedef ListPendingNotificationCallback = Future<List<QueuedMessage>> Function();

class LocalNotificationScheduler implements ClixLocalMessageScheduler {
  final ScheduleNotificationCallback scheduleNotification;
  final CancelNotificationCallback cancelNotification;
  final ListPendingNotificationCallback listPendingNotifications;

  LocalNotificationScheduler({
    required this.scheduleNotification,
    required this.cancelNotification,
    required this.listPendingNotifications,
  });

  @override
  Future<void> schedule(QueuedMessage record) async {
    await scheduleNotification(record);
  }

  @override
  Future<void> cancel(String id) async {
    await cancelNotification(id);
  }

  @override
  Future<List<QueuedMessage>> listPending() async {
    return listPendingNotifications();
  }
}
