import 'garden_state.dart';

/// Immutable configuration for all economy balancing values.
///
/// Values reflect `docs/game-design.md` where explicitly cited and propose
/// test defaults otherwise. Injectable and replaceable in tests.
class EconomyConfig {
  const EconomyConfig({
    required this.florinsPerWalkStep,
    required this.walkFlorinDailyCap,
    required this.slotPrices,
    required this.seedPrices,
    required this.fertilizerPrices,
    required this.decorationPrices,
    required this.harvestFlorinDailyLimit,
  });

  factory EconomyConfig.defaults() => const EconomyConfig(
        florinsPerWalkStep: 1 / 500,
        walkFlorinDailyCap: 30,
        slotPrices: {
          ZoneType.potager: [30, 45, 60, 75],
          ZoneType.jardinFleuri: [30, 45, 60, 75],
          ZoneType.verger: [30, 45],
        },
        seedPrices: {
          GrowthTier.commune: 5,
          GrowthTier.peuCommune: 20,
          GrowthTier.rare: 60,
        },
        fertilizerPrices: {
          FertilizerType.basique: 10,
          FertilizerType.superEngrais: 20,
          FertilizerType.mega: 40,
        },
        decorationPrices: {
          'arrosoir': 15,
          'banc': 20,
          'fontaine': 50,
          'caisse_legumes': 15,
          'arche': 40,
          'tonneau': 12,
          'pot': 8,
          'panneau': 10,
          'nichoir': 18,
          'brouette': 25,
        },
        harvestFlorinDailyLimit: 20,
      );

  /// Florins earned per step walked (1 florin per 500 steps = 1/500).
  final double florinsPerWalkStep;

  /// Maximum florins from walking per day.
  final int walkFlorinDailyCap;

  /// Slot prices per zone, ordered by purchase rank.
  final Map<ZoneType, List<int>> slotPrices;

  /// Seed prices by growth tier (ordinary only; brillante never sold).
  final Map<GrowthTier, int> seedPrices;

  /// Fertilizer prices by type.
  final Map<FertilizerType, int> fertilizerPrices;

  /// Decoration prices by decoration id.
  final Map<String, int> decorationPrices;

  /// Maximum florins from harvests per day (without subscription).
  final int harvestFlorinDailyLimit;
}
