import 'garden_state.dart';

/// Immutable configuration for all economy balancing values.
///
/// Values reflect `docs/game-design.md` where explicitly cited and propose
/// test defaults otherwise. Injectable and replaceable in tests.
class EconomyConfig {
  const EconomyConfig({
    required this.slotPrices,
    required this.seedPrices,
    required this.fertilizerPrices,
    required this.decorationPrices,
  });

  const EconomyConfig._default()
    : slotPrices = const {
        ZoneType.potager: [30, 45, 60, 75],
        ZoneType.jardinFleuri: [30, 45, 60, 75],
        ZoneType.verger: [30, 45],
      },
      seedPrices = const {
        GrowthTier.commune: 20,
        GrowthTier.peuCommune: 40,
        GrowthTier.rare: 80,
      },
      fertilizerPrices = const {
        FertilizerType.basique: 10,
        FertilizerType.superEngrais: 20,
        FertilizerType.mega: 40,
      },
      decorationPrices = const {
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
      };

  factory EconomyConfig.defaults() => const EconomyConfig._default();

  static const EconomyConfig defaultConfig = EconomyConfig._default();

  /// Slot prices per zone, ordered by purchase rank.
  final Map<ZoneType, List<int>> slotPrices;

  /// Seed prices by species rarity (ordinary seeds only; brillante never sold).
  /// Trees use the commune price (20). The shop sells « additional seeds of a
  /// discovered species » (sink de florins).
  final Map<GrowthTier, int> seedPrices;

  /// Fertilizer prices by type.
  final Map<FertilizerType, int> fertilizerPrices;

  /// Decoration prices by decoration id.
  final Map<String, int> decorationPrices;
}
