import 'dart:math';

import 'economy_config.dart';
import 'garden_state.dart';

/// Pure deterministic economy rules.
///
/// All balancing values come from [EconomyConfig], not hardcoded constants.
/// No dependency on Flutter, Flame, or any platform.
class EconomyRules {
  const EconomyRules(this.config);

  final EconomyConfig config;

  /// Returns the price of the next slot in [zone] given [alreadyPurchased]
  /// slots in that zone.
  ///
  /// Throws [StateError] if the zone's maximum has been reached.
  int slotPrice(ZoneType zone, int alreadyPurchased) {
    final prices = config.slotPrices[zone]!;
    if (alreadyPurchased >= prices.length) {
      throw StateError(
        'No more slots available to purchase in ${zone.label}',
      );
    }
    return prices[alreadyPurchased];
  }

  /// Returns the price of an ordinary seed of [tier].
  ///
  /// Brilliant seeds are never sold; callers must reject [GrowthTier.brillante]
  /// before calling this.
  int seedPrice(GrowthTier tier) => config.seedPrices[tier]!;

  /// Returns the price of [type] fertilizer.
  int fertilizerPrice(FertilizerType type) => config.fertilizerPrices[type]!;

  /// Returns the price of a decoration identified by [decorationId].
  int decorationPrice(String decorationId) =>
      config.decorationPrices[decorationId]!;

  /// Calculates florins to credit from [totalDailySteps] walked today, given
  /// [alreadyClaimed] florins already credited for the day.
  ///
  /// Returns the delta to credit, never negative (no revocation).
  /// Respects [EconomyConfig.walkFlorinDailyCap].
  int walkFlorinsFromSteps(int totalDailySteps, int alreadyClaimed) {
    final raw = (totalDailySteps * config.florinsPerWalkStep).floor();
    final capped = raw.clamp(0, config.walkFlorinDailyCap);
    return max(0, capped - alreadyClaimed);
  }
}
