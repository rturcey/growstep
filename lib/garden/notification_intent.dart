/// Notification intents produced by game logic and executed by
/// [NotificationScheduler]. These are pure data — no platform calls.
///
/// A notification intent carries enough information for the scheduler
/// to fire a local notification with the right title, body, and trigger.
sealed class NotificationIntent {
  const NotificationIntent({this.scheduledTime});

  final DateTime? scheduledTime;
}

/// Suggest the player take a walk after 60 minutes of inactivity.
class ProposeWalkIntent extends NotificationIntent {
  const ProposeWalkIntent({super.scheduledTime});
}

/// Remind the player to walk after 90 minutes of inactivity.
class ReminderWalkIntent extends NotificationIntent {
  const ReminderWalkIntent({super.scheduledTime});
}

/// Invitation to walk at a chosen hour.
class InvitationWalkIntent extends NotificationIntent {
  const InvitationWalkIntent({required this.hour, super.scheduledTime});

  final int hour;
}
