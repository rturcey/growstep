import 'local_date.dart';

/// Unique identity for a daily palier reward.
///
/// Two rewards are distinct if they differ by day OR threshold.
/// For example, 2026-09-25/1000 and 2026-09-25/3000 are different rewards,
/// as are 2026-09-25/1000 and 2026-09-26/1000.
class DailyRewardId {
  const DailyRewardId(this.day, this.threshold);

  final LocalDate day;
  final int threshold;

  @override
  int get hashCode => Object.hash(day, threshold);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRewardId && day == other.day && threshold == other.threshold;

  @override
  String toString() => 'DailyRewardId($day, $threshold)';
}
