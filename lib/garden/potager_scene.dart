import 'dart:ui';

import 'garden_scene.dart';

/// First two migrated objects. Their exact display sizes preserve the current
/// scene; later family tickets can introduce shared size classes and variants.
class PotagerPilotScene {
  const PotagerPilotScene._();

  static const rock = GardenSpriteObject(
    id: 'east_upper_rock',
    asset: 'commun_decor_rochers_herbe_statique_ordinaire_00.png',
    contact: Offset(355, 150),
    size: Size(41.4, 23),
    layer: GardenLayer.depth,
    opacity: 0.82,
  );

  static const barrel = GardenSpriteObject(
    id: 'east_barrel',
    asset: 'commun_decor_tonneau_bois_statique_ordinaire_00.png',
    contact: Offset(355, 230),
    size: Size(32, 35),
    layer: GardenLayer.depth,
    opacity: 0.88,
  );

  static const objects = <GardenSpriteObject>[rock, barrel];
}

/// A saved plot index and its authored position on the shared isometric grid.
/// The contact is shared by soil, plant, selection, and hit testing.
class PotagerPlot {
  const PotagerPlot(this.index, this.gridI, this.gridJ);

  final int index;
  final double gridI;
  final double gridJ;

  String get id => 'soil_plot_$index';
  Offset get contact => PotagerPlots.grid.toScreen(gridI, gridJ);
}

class PotagerPlots {
  const PotagerPlots._();

  static const grid = IsoGrid(Offset(195, 230));
  static const footprintWidth = IsoGrid.cellWidth - 8;
  static const footprintHeight = IsoGrid.cellHeight - 4;

  /// Saved index order; lattice coordinates reproduce the historical contacts.
  static const plots = <PotagerPlot>[
    PotagerPlot(0, -3.5, -0.5), // back-left  (75, 150)
    PotagerPlot(1, 1, -1), // middle-right (275, 230)
    PotagerPlot(2, 0.5, 3.5), // front-left (75, 310)
    PotagerPlot(3, 3.5, 0.5), // front-right (315, 310)
    PotagerPlot(4, -2, -2), // back-center (195, 150)
    PotagerPlot(5, -1, 1), // middle-left (115, 230)
    PotagerPlot(6, 2, 2), // front-center (195, 310)
    PotagerPlot(7, -0.5, -3.5), // back-right (315, 150)
  ];

  static final contacts = List<Offset>.unmodifiable(
    plots.map((plot) => plot.contact),
  );

  static Iterable<PotagerPlot> visible(int purchasedCount) =>
      plots.take(purchasedCount);

  /// One softly irregular 2:1 soil outline inside the same 72 × 36 footprint.
  static Path footprintAt(Offset contact) {
    final x = contact.dx;
    final y = contact.dy;
    const w = footprintWidth / 2;
    const h = footprintHeight / 2;
    Offset p(double nx, double ny) => Offset(x + nx * w, y + ny * h);
    final path = Path()..moveTo(x, y - h);
    void curve(Offset a, Offset b, Offset end) =>
        path.cubicTo(a.dx, a.dy, b.dx, b.dy, end.dx, end.dy);

    curve(p(0.17, -1), p(0.31, -0.83), p(0.42, -0.67));
    curve(p(0.61, -0.56), p(1, -0.17), p(1, 0));
    curve(p(1, 0.17), p(0.83, 0.33), p(0.64, 0.44));
    curve(p(0.44, 0.56), p(0.17, 1), p(0, 1));
    curve(p(-0.17, 1), p(-0.31, 0.78), p(-0.47, 0.61));
    curve(p(-0.72, 0.44), p(-1, 0.17), p(-1, 0));
    curve(p(-1, -0.17), p(-0.86, -0.39), p(-0.64, -0.50));
    curve(p(-0.42, -0.67), p(-0.17, -1), p(0, -1));
    return path..close();
  }
}
