/// Catalogue of decorations available for purchase.
///
/// Each decoration has an [id], a human-readable [label], and a price
/// (looked up via [EconomyConfig.decorationPrices]). The [footprintWidth]
/// and [footprintHeight] describe the decoration's occupancy on the 80×40
/// isometric grid.
class DecorationDefinition {
  const DecorationDefinition({
    required this.id,
    required this.label,
    this.footprintWidth = 1,
    this.footprintHeight = 1,
  });

  final String id;
  final String label;
  final int footprintWidth;
  final int footprintHeight;
}

/// Static catalogue of all decorations available in the shop.
class DecorationCatalogue {
  const DecorationCatalogue();

  static const _definitions = [
    DecorationDefinition(id: 'arrosoir', label: 'Arrosoir'),
    DecorationDefinition(id: 'banc', label: 'Banc'),
    DecorationDefinition(id: 'fontaine', label: 'Fontaine'),
    DecorationDefinition(id: 'caisse_legumes', label: 'Caisse à légumes'),
    DecorationDefinition(id: 'arche', label: 'Arche'),
    DecorationDefinition(id: 'tonneau', label: 'Tonneau'),
    DecorationDefinition(id: 'pot', label: 'Pot'),
    DecorationDefinition(id: 'panneau', label: 'Panneau'),
    DecorationDefinition(id: 'nichoir', label: 'Nichoir'),
    DecorationDefinition(id: 'brouette', label: 'Brouette'),
  ];

  List<DecorationDefinition> get all => _definitions.toList();

  DecorationDefinition? find(String id) {
    for (final d in _definitions) {
      if (d.id == id) return d;
    }
    return null;
  }

  bool contains(String id) => find(id) != null;
}
