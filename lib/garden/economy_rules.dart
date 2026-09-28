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
      throw StateError('No more slots available to purchase in ${zone.label}');
    }
    return prices[alreadyPurchased];
  }

  /// Returns the price of an ordinary seed of [tier].
  ///
  /// Brilliant seeds are never sold; callers must reject [GrowthTier.brillante]
  /// before calling this.
  int seedPrice(GrowthTier tier) => config.seedPrices[tier]!;

  /// Returns the price of an additional seed of [species] (sink de florins).
  /// Brillante is never sold; ordinary species are priced by their rarity.
  int seedPriceForSpecies(Species species) =>
      config.seedPrices[species.rarity]!;

  /// Prix de vente d'une récolte de [species] au marché, sachant
  /// [salesToday] ventes déjà effectuées aujourd'hui pour cette espèce.
  ///
  /// Les premières ventes (quota de l'espèce) se vendent à plein tarif ; le
  /// surplus à 30 % (rendement marginal réduit, jamais un plafond dur).
  int marketPrice(Species species, int salesToday) {
    final full = species.pricePerHarvest;
    if (salesToday < species.dailyQuota) return full;
    return (full * 0.3).floor();
  }

  /// Returns the price of [type] fertilizer.
  int fertilizerPrice(FertilizerType type) => config.fertilizerPrices[type]!;

  /// Returns the price of a decoration identified by [decorationId].
  int decorationPrice(String decorationId) =>
      config.decorationPrices[decorationId]!;
}
