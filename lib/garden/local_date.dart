/// A date-only value type with no time or timezone component.
///
/// Used everywhere in daily progression rules to ensure deterministic
/// outcomes per calendar day.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  factory LocalDate.parse(String iso) {
    final parts = iso.split('-');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  final int year;
  final int month;
  final int day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDate &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}'
      '-${month.toString().padLeft(2, '0')}'
      '-${day.toString().padLeft(2, '0')}';

  String toIsoString() => toString();

  /// Nombre de jours entre [other] et [this] (positif si [this] est après
  /// [other]).
  int daysSince(LocalDate other) {
    final thisDays = _toEpochDays(year, month, day);
    final otherDays = _toEpochDays(other.year, other.month, other.day);
    return thisDays - otherDays;
  }

  static int _toEpochDays(int year, int month, int day) {
    var y = year;
    var m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final era = y ~/ 400;
    final yoe = y - era * 400;
    final doy = (153 * (m - 3) + 2) ~/ 5 + day - 1;
    final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
    return era * 146097 + doe - 719468;
  }
}
