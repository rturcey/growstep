import '../garden/notification_intent.dart';

/// Thin abstraction over the platform's local notification system.
///
/// Receives notification intents produced by game logic and executes
/// them on the platform. The [Fake] implementation records intents
/// for test assertions. No game reward is decided here.
abstract interface class NotificationScheduler {
  Future<void> schedule(NotificationIntent intent);
  Future<void> cancel(NotificationIntent intent);
  Future<void> cancelAllOfType<T extends NotificationIntent>();
}
