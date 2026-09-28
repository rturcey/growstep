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
    required this.dailyLotFlorinRanges,
    this.dailyLotFirstNoFlorinsChance = 0.2,
  });

  const EconomyConfig._default()
    : florinsPerWalkStep = 1 / 500,
      walkFlorinDailyCap = 30,
      slotPrices = const {
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
      },
      dailyLotFlorinRanges = const [
        [3, 5],
        [8, 12],
        [15, 20],
        [30, 50],
      ],
      dailyLotFirstNoFlorinsChance = 0.2;

  factory EconomyConfig.defaults() => const EconomyConfig._default();

  static const EconomyConfig defaultConfig = EconomyConfig._default();

  /// Florins earned per step walked (1 florin per 500 steps = 1/500).
  final double florinsPerWalkStep;

  /// Maximum florins from walking per day.
  final int walkFlorinDailyCap;

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

  /// Florin amount ranges [min, max] per daily lot rank (0-3).
  final List<List<int>> dailyLotFlorinRanges;

  /// Chance that the first daily lot gives no florins.
  final double dailyLotFirstNoFlorinsChance;
}
