import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'garden_state.dart';

/// Runtime renderer for the orthogonal Fantasy Farm potager.
///
/// The Tiled source map is authored in native 32×32 pixels. Inside Growstep's
/// 390×450 logical artboard it is rendered at 16×16, so the 20×20 map occupies
/// 320×320 logical pixels and remains pixel-perfect.
class PotagerSprites {
  static const double sourceTileSize = 32;
  static const double renderTileSize = 16;

  static const int mapWidth = 20;
  static const int mapHeight = 20;

  static const ui.Size renderedMapSize = ui.Size(
    mapWidth * renderTileSize,
    mapHeight * renderTileSize,
  );

  static const ui.Offset mapOffset = ui.Offset(
    (390 - mapWidth * renderTileSize) / 2,
    (450 - mapHeight * renderTileSize) / 2,
  );

  /// Centers of the eight 2×2 cultivation beds after the 0.5 map scale.
  ///
  /// Stable slot order remains the gameplay/save order.
  static const List<ui.Offset> plotAnchors = [
    ui.Offset(115, 145), // plot_0
    ui.Offset(195, 145), // plot_1
    ui.Offset(275, 145), // plot_2
    ui.Offset(115, 225), // plot_3
    ui.Offset(275, 225), // plot_4
    ui.Offset(115, 305), // plot_5
    ui.Offset(195, 305), // plot_6
    ui.Offset(275, 305), // plot_7
  ];

  /// Column count of the Fantasy Farm crop sheet (4 columns × 17 rows = 68 tiles).
  static const int _cropColumns = 4;

  ui.Image? _crops;

  Future<void> load() async {
    final data = await rootBundle.load(
      'assets/sprites/fantasy_farm_free/crops__Crops.png',
    );

    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());

    final frame = await codec.getNextFrame();

    _crops = frame.image;

    codec.dispose();
  }

  void dispose() {
    _crops?.dispose();
    _crops = null;
  }

  static List<int> tilesFor(Species species) => switch (species) {
    // Fantasy Farm paid crop sheet: 4 columns × 17 rows = 68 tiles.
    // Group A (rows 0–2, col 3): tiles 3, 7, 11 — tomate.
    // Group B (rows 4–6, col 3): tiles 19, 23, 27 — carotte.
    // Group E (rows 13–16, col 3): tiles 55, 59, 63, 67 — courgette.
    Species.tomate => const [3, 7, 11, 11],
    Species.carotte => const [19, 23, 27, 27],
    Species.courgette => const [55, 59, 63, 67],

    _ => throw ArgumentError.value(
      species,
      'species',
      'Potager sprites only accepts potager species',
    ),
  };

  static int tileFor(Plant plant) {
    final stages = tilesFor(plant.species);

    return stages[plant.stage.index];
  }

  /// Paint four identical crop sprites on the 2×2 authored bed.
  ///
  /// Tiled owns the soil and environment. Growstep owns crop species/stage.
  void drawPlant(ui.Canvas canvas, ui.Offset center, Plant plant) {
    final image = _crops;

    if (image == null || plant.species.zone != ZoneType.potager) {
      return;
    }

    final tileId = tileFor(plant);

    final sourceColumn = tileId % _cropColumns;
    final sourceRow = tileId ~/ _cropColumns;

    final source = ui.Rect.fromLTWH(
      sourceColumn * sourceTileSize,
      sourceRow * sourceTileSize,
      sourceTileSize,
      sourceTileSize,
    );

    final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

    final topLeft = center.translate(-renderTileSize, -renderTileSize);

    for (var row = 0; row < 2; row++) {
      for (var column = 0; column < 2; column++) {
        final destination = ui.Rect.fromLTWH(
          topLeft.dx + column * renderTileSize,
          topLeft.dy + row * renderTileSize,
          renderTileSize,
          renderTileSize,
        );

        canvas.drawImageRect(image, source, destination, paint);
      }
    }

    if (plant.tier == GrowthTier.brillante) {
      _drawBrilliantMark(canvas, center.translate(11, -13));
    }
  }

  void _drawBrilliantMark(ui.Canvas canvas, ui.Offset center) {
    final ray = ui.Paint()
      ..color = const ui.Color(0xFFFFF4B8)
      ..strokeWidth = 1
      ..strokeCap = ui.StrokeCap.square;

    canvas.drawLine(center.translate(0, -3), center.translate(0, 3), ray);

    canvas.drawLine(center.translate(-3, 0), center.translate(3, 0), ray);

    canvas.drawCircle(
      center,
      1,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  }
}
