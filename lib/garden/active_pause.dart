/// A pause marche in progress.
///
/// Stores the start time, step objective, and deadline (10 minutes later).
class ActivePause {
  const ActivePause({
    required this.startTime,
    required this.objective,
    required this.deadline,
    this.rewarded = false,
  });

  final DateTime startTime;
  final int objective;
  final DateTime deadline;
  final bool rewarded;

  ActivePause copyWith({bool? rewarded}) => ActivePause(
        startTime: startTime,
        objective: objective,
        deadline: deadline,
        rewarded: rewarded ?? this.rewarded,
      );

  Map<String, Object?> toJson() => {
        'startTime': startTime.toIso8601String(),
        'objective': objective,
        'deadline': deadline.toIso8601String(),
        'rewarded': rewarded,
      };

  factory ActivePause.fromJson(Map<String, dynamic> json) => ActivePause(
        startTime: DateTime.parse(json['startTime'] as String),
        objective: json['objective'] as int,
        deadline: DateTime.parse(json['deadline'] as String),
        rewarded: json['rewarded'] as bool? ?? false,
      );
}
