import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'garden_state.dart';

/// Runtime renderer for Sunnyside World V2.1 crop sprites.
///
/// The Sunnyside pack supplies 11 crops as individual tightly-cropped PNGs,
/// each with 6 growth stages (_00 to _05). This class loads the subset that
/// maps to Growstep Species, and renders them with nearest-neighbour scaling
/// so the pixel art stays crisp.
///
/// Crop → Species mapping (only species with a reasonable visual match are
/// covered; the rest fall back to Canvas drawing in GardenGame):
///
///   carrot     → Species.carotte
///   sunflower  → Species.tournesol
///   pumpkin    → Species.tomate     (round warm-coloured fruit)
///   cabbage    → Species.courgette   (broad-leaf vegetable)
///   cauliflower→ Species.tulipe     (flowering head)
///   kale       → Species.lavande     (slender clustered leaves)
class SunnysideSprites {
  static const _cropPrefix = <Species, String>{
    Species.carotte: 'carrot',
    Species.tournesol: 'sunflower',
    Species.tomate: 'pumpkin',
    Species.courgette: 'cabbage',
    Species.tulipe: 'cauliflower',
    Species.lavande: 'kale',
  };

  static const int _maxStage = 5;

  static const String _assetRoot = 'assets/sprites/sunnyside/crops/';

  final Map<String, ui.Image> _images = {};

  Future<void> load() async {
    final crops = _cropPrefix.values.toSet();
    for (final crop in crops) {
      for (var stage = 0; stage <= _maxStage; stage++) {
        final key = _assetKey(crop, stage);
        final data = await rootBundle.load(key);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        _images[_cropStageKey(crop, stage)] = frame.image;
      }
    }
  }

  static String _assetKey(String crop, int stage) =>
      '$_assetRoot${crop}_${stage.toString().padLeft(2, '0')}.png';

  static String _cropStageKey(String crop, int stage) =>
      '${crop}_$stage';

  bool canDraw(Species species) => _cropPrefix.containsKey(species);

  static int stageIndex(PlantStage stage, bool readyToHarvest) {
    if (readyToHarvest) return _maxStage;
    return switch (stage) {
      PlantStage.graineGermee => 0,
      PlantStage.jeunePlant => 2,
      PlantStage.presqueMature => 3,
      PlantStage.mature => 4,
    };
  }

  void drawPlant(ui.Canvas canvas, ui.Offset contact, Plant plant) {
    final crop = _cropPrefix[plant.species];
    if (crop == null) return;

    final ready = plant.isReadyToHarvest ||
        (plant.completedCycles > 0 &&
            plant.progressSteps >= plant.targetSteps / 2);
    final stageIdx = stageIndex(plant.stage, ready);
    final image = _images[_cropStageKey(crop, stageIdx)];
    if (image == null) return;

    final src = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final scale = _scaleForStage(stageIdx);
    final destWidth = image.width * scale;
    final destHeight = image.height * scale;

    final dest = ui.Rect.fromLTWH(
      contact.dx - destWidth / 2,
      contact.dy - destHeight,
      destWidth,
      destHeight,
    );

    canvas.drawImageRect(
      image,
      src,
      dest,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );

    if (plant.tier == GrowthTier.brillante) {
      _drawBrilliantSparkle(canvas, contact, dest);
    }
  }

  static double _scaleForStage(int stageIdx) {
    return switch (stageIdx) {
      0 => 2.0,
      1 => 2.5,
      2 => 3.0,
      3 => 3.5,
      4 => 4.0,
      5 => 4.0,
      _ => 3.0,
    };
  }

  void _drawBrilliantSparkle(
    ui.Canvas canvas,
    ui.Offset contact,
    ui.Rect dest,
  ) {
    final cx = dest.center.dx;
    final cy = dest.top + dest.height * 0.2;
    final ray = ui.Paint()
      ..color = const ui.Color(0xFFFFF4B8)
      ..strokeWidth = 1
      ..strokeCap = ui.StrokeCap.square;
    canvas.drawLine(
      ui.Offset(cx, cy - 3),
      ui.Offset(cx, cy + 3),
      ray,
    );
    canvas.drawLine(
      ui.Offset(cx - 3, cy),
      ui.Offset(cx + 3, cy),
      ray,
    );
    canvas.drawCircle(
      ui.Offset(cx, cy),
      1,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  }

  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
