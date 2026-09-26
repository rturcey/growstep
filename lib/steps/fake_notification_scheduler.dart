import '../garden/notification_intent.dart';
import 'notification_scheduler.dart';

class FakeNotificationScheduler implements NotificationScheduler {
  final List<NotificationIntent> scheduled = [];
  final List<NotificationIntent> cancelled = [];

  void clear() {
    scheduled.clear();
    cancelled.clear();
  }

  @override
  Future<void> schedule(NotificationIntent intent) async {
    scheduled.add(intent);
  }

  @override
  Future<void> cancel(NotificationIntent intent) async {
    cancelled.add(intent);
  }

  @override
  Future<void> cancelAllOfType<T extends NotificationIntent>() async {
    final matching = scheduled.whereType<T>().toList();
    for (final intent in matching) {
      scheduled.remove(intent);
      cancelled.add(intent);
    }
  }
}
