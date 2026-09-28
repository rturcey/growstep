import 'dart:math';

import 'economy_config.dart';
import 'garden_state.dart';
import 'local_date.dart';

/// The four daily walking thresholds.
const dailyThresholds = [1000, 3000, 6000, 10000];

/// Cumulative chances of receiving a shiny seed at each threshold.
const shinySeedChances = [0.02, 0.03, 0.04, 0.05];

/// A lot drawn deterministically for a given day and threshold.
class DailyLot {
  const DailyLot({
    required this.threshold,
    this.seedSpecies,
    this.fertilizerType,
    this.decorationId,
    this.shinySeedSpecies,
  });

  final int threshold;
  final Species? seedSpecies;
  final FertilizerType? fertilizerType;
  final String? decorationId;
  final Species? shinySeedSpecies;

  bool get hasShinySeed => shinySeedSpecies != null;
}

/// Pure deterministic daily progression rules.
///
/// The outcome for a given day depends only on [playerSeed] and the
/// calendar day. It never rerolls and is reconstructible at any time.
class DailyProgression {
  const DailyProgression([this.config = EconomyConfig.defaultConfig]);

  final EconomyConfig config;

  /// Returns a deterministic seed for [playerSeed] and [day].
  int _dailySeed(int playerSeed, LocalDate day) {
    final dayString = day.toIsoString();
    var hash = playerSeed;
    for (var i = 0; i < dayString.length; i++) {
      hash = hash * 31 + dayString.codeUnitAt(i);
    }
    return hash.abs();
  }

  /// Returns the four lots for [playerSeed] and [day].
  ///
  /// The lots are deterministic: same playerSeed + same day always
  /// produces the same lots. They are NOT persisted — reconstructed
  /// on demand.
  List<DailyLot> lotsFor(int playerSeed, LocalDate day) {
    final seed = _dailySeed(playerSeed, day);
    final rng = Random(seed);

    final shinyThreshold = _drawShinyThreshold(rng);
    final shinySpecies = shinyThreshold != null
        ? Species.values[rng.nextInt(Species.values.length)]
        : null;

    final lots = <DailyLot>[];
    for (var i = 0; i < dailyThresholds.length; i++) {
      final threshold = dailyThresholds[i];
      final isShinyThreshold = threshold == shinyThreshold;
      lots.add(
        _drawLot(
          rng: rng,
          threshold: threshold,
          shinySeedSpecies: isShinyThreshold ? shinySpecies : null,
        ),
      );
    }
    return lots;
  }

  int? _drawShinyThreshold(Random rng) {
    final roll = rng.nextDouble();
    if (roll >= shinySeedChances.last) return null;
    for (var i = 0; i < shinySeedChances.length; i++) {
      if (roll < shinySeedChances[i]) {
        return dailyThresholds[i];
      }
    }
    return null;
  }

  DailyLot _drawLot({
    required Random rng,
    required int threshold,
    required Species? shinySeedSpecies,
  }) {
    // Les lots ne contiennent plus jamais de florins : le marché est le seul
    // générateur. Chaque lot accorde graines, engrais ou décor.
    final rewardType = rng.nextInt(3);
    final commonSpecies = [
      Species.tomate,
      Species.carotte,
      Species.courgette,
      Species.tournesol,
      Species.tulipe,
      Species.lavande,
    ];

    return DailyLot(
      threshold: threshold,
      seedSpecies: rewardType == 0
          ? commonSpecies[rng.nextInt(commonSpecies.length)]
          : null,
      fertilizerType: rewardType == 1
          ? FertilizerType.values[rng.nextInt(FertilizerType.values.length)]
          : null,
      decorationId: rewardType == 2 ? 'pot' : null,
      shinySeedSpecies: shinySeedSpecies,
    );
  }

  /// Returns the thresholds that are reached for [stepsToday].
  List<int> reachedThresholds(int stepsToday) {
    return dailyThresholds.where((t) => stepsToday >= t).toList();
  }
}
