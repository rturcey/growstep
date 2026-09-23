import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'garden_state.dart';
import 'garden_sprites.dart';
import 'potager_path.dart';

/// Isometric grid engine: every scene position derives from the 80×40 rhombus
/// lattice with axes u = (40, 20) and v = (-40, 20). Origin is the grid center.
class IsoGrid {
  const IsoGrid(this.origin);

  /// Screen center of the grid.
  final Offset origin;

  /// Lattice (i, j) → screen coordinates. Integer = cell center, half-integer
  /// = edge midpoint, the only positions allowed for anchors and path nodes.
  Offset toScreen(double i, double j) => Offset(
    origin.dx + (i - j) * 40,
    origin.dy + (i + j) * 20,
  );

  /// Diamond path for one grid cell centered at lattice (i, j).
  Path cellPath(double i, double j) {
    final c = toScreen(i, j);
    return Path()
      ..moveTo(c.dx, c.dy - 20)
      ..lineTo(c.dx + 40, c.dy)
      ..lineTo(c.dx, c.dy + 20)
      ..lineTo(c.dx - 40, c.dy)
      ..close();
  }
}

/// One renderable scene object with depth sorting and draw dispatch.
class _SceneObject {
  _SceneObject(this.anchor, this.draw);

  final Offset anchor;
  final void Function(Canvas canvas) draw;
}

/// Modular garden scene rendered by Flame at phone scale.
///
/// One island is rendered at a time on a fixed 390 × 450 logical canvas. The
/// apparent scale never shrinks with phone height: the Flutter layout adapts
/// around the scene instead of rescaling the world. Every bed, path node and
/// decoration snaps to the 80 × 40 isometric lattice.
class GardenGame extends FlameGame {
  final GardenSprites _sprites = GardenSprites();
  GardenSnapshot snapshot = GardenSnapshot.initial();
  ZoneType currentZone = ZoneType.potager;
  int? selectedSlot;
  bool showTouchTargets = false;

  static const zonesInViewOrder = [
    ZoneType.jardinFleuri,
    ZoneType.potager,
    ZoneType.verger,
  ];
  static const double referenceWidth = 390;
  static const double referenceHeight = 450;
  static const double touchSize = 44;
  static const double sceneScale = 1.0;
  static const double earthThickness = 24;

  /// Stable 3–2–3 potager anchors ordered by saved slot index, from the
  /// approved island geometry gabarit (docs/geometrie-ilots.md).
  static const _potagerAnchors = <Offset>[
    Offset(75, 150), // 0 back-left
    Offset(275, 230), // 1 middle-right
    Offset(75, 310), // 2 front-left
    Offset(315, 310), // 3 front-right
    Offset(195, 150), // 4 back-center
    Offset(115, 230), // 5 middle-left
    Offset(195, 310), // 6 front-center
    Offset(315, 150), // 7 back-right
  ];
  static const _flowerAnchors = <Offset>[
    Offset(75, 150),
    Offset(275, 230),
    Offset(75, 310),
    Offset(315, 310),
    Offset(195, 150),
    Offset(115, 230),
    Offset(195, 310),
    Offset(315, 150),
  ];
  static const _orchardAnchors = <Offset>[
    Offset(195, 190), // 0 back-center
    Offset(115, 325), // 1 front-left
    Offset(275, 325), // 2 front-right
  ];

  static List<Offset> anchorsFor(ZoneType zone) => switch (zone) {
    ZoneType.potager => _potagerAnchors,
    ZoneType.jardinFleuri => _flowerAnchors,
    ZoneType.verger => _orchardAnchors,
  };

  void moveTo(ZoneType zone) {
    if (zone == currentZone) return;
    currentZone = zone;
    selectedSlot = null;
  }

  int? hitTestSlot(Offset localPosition) {
    final scenePoint = (localPosition - _canvasOrigin()) / sceneScale;
    final anchors = anchorsFor(currentZone);
    for (var slot = 0; slot < snapshot.zones[currentZone]!.length; slot++) {
      final anchor = anchors[slot];
      if ((scenePoint.dx - anchor.dx).abs() <= touchSize / 2 &&
          (scenePoint.dy - anchor.dy).abs() <= touchSize / 2) {
        return slot;
      }
    }
    return null;
  }

  Offset _canvasOrigin() => Offset(
    (size.x - referenceWidth * sceneScale) / 2,
    (size.y - referenceHeight * sceneScale) / 2,
  );

  @override
  Color backgroundColor() => const Color(0xFFE4EBD5);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _sprites.load();
  }

  @override
  void onRemove() {
    _sprites.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.topLeft,
          radius: 1.4,
          colors: [Color(0xFFF0F4DE), Color(0xFFD5E5C2)],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );
    canvas.save();
    final origin = _canvasOrigin();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(sceneScale);
    _drawIsland(canvas, currentZone);
    canvas.restore();
  }

  // ─── Island rendering ──────────────────────────────────────────────────

  void _drawIsland(Canvas canvas, ZoneType zone) {
    // Collect ALL scene objects for proper depth sorting.
    final objects = <_SceneObject>[];

    // Terrain (drawn first, unsorted).
    _drawTerrain(canvas, zone);
    if (zone == ZoneType.potager) PotagerPath.draw(canvas);

    // Environment objects.
    for (final entry in _environmentObjects(zone)) {
      objects.add(entry);
    }

    // Slot objects (beds + plants).
    final anchors = anchorsFor(zone);
    final purchased = snapshot.zones[zone]!;
    for (var slot = 0; slot < purchased.length; slot++) {
      final point = anchors[slot];
      objects.add(_SceneObject(point, (c) => _drawBed(c, point, zone)));
      if (purchased[slot] != null) {
        objects.add(_SceneObject(
          point.translate(0, -1),
          (c) => _drawPlant(c, point, purchased[slot]!),
        ));
      }
      if (zone == currentZone && selectedSlot == slot) {
        objects.add(_SceneObject(
          point.translate(0, 1),
          (c) => _drawSelection(c, point, zone),
        ));
      }
    }

    // Depth sort by ground-contact Y.
    objects.sort((a, b) => a.anchor.dy.compareTo(b.anchor.dy));
    for (final obj in objects) {
      obj.draw(canvas);
    }

    // Touch targets drawn on top.
    if (showTouchTargets) {
      for (var slot = 0; slot < purchased.length; slot++) {
        if (zone != currentZone) continue;
        final point = anchors[slot];
        canvas.drawRect(
          Rect.fromCenter(center: point, width: touchSize, height: touchSize),
          Paint()
            ..color = const Color(0x7763845B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  // ─── Terrain ───────────────────────────────────────────────────────────

  Path _islandContour(ZoneType zone) {
    final points = switch (zone) {
      ZoneType.potager => const <Offset>[
        Offset(40, 205), Offset(55, 135), Offset(125, 102),
        Offset(200, 94), Offset(275, 102), Offset(345, 135),
        Offset(360, 205), Offset(350, 285), Offset(320, 352),
        Offset(245, 392), Offset(145, 392), Offset(70, 352),
        Offset(40, 285),
      ],
      ZoneType.jardinFleuri => const <Offset>[
        Offset(38, 210), Offset(70, 128), Offset(150, 96),
        Offset(200, 90), Offset(250, 96), Offset(330, 128),
        Offset(362, 210), Offset(350, 290), Offset(312, 360),
        Offset(235, 398), Offset(155, 398), Offset(78, 360),
        Offset(40, 290),
      ],
      ZoneType.verger => const <Offset>[
        Offset(50, 240), Offset(95, 150), Offset(195, 120),
        Offset(295, 150), Offset(340, 240), Offset(320, 320),
        Offset(250, 380), Offset(140, 380), Offset(70, 320),
      ],
    };
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  void _drawTerrain(Canvas canvas, ZoneType zone) {
    final contour = _islandContour(zone);
    final earth = contour.shift(const Offset(0, earthThickness));

    // Soft cast shadow under the island.
    canvas.drawPath(
      earth.shift(const Offset(4, 6)),
      Paint()..color = const Color(0x225A7850),
    );

    // Earth side — warm brown gradient with subtle texture.
    canvas.drawPath(
      earth,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFAA805B), Color(0xFF8A674A), Color(0xFF76543F)],
        ).createShader(earth.getBounds()),
    );

    // Earth grain — subtle horizontal striations for material depth.
    final bounds = earth.getBounds();
    canvas.save();
    canvas.clipPath(earth);
    for (var y = bounds.top; y < bounds.bottom; y += 4) {
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.right, y),
        Paint()
          ..color = const Color(0x0D5A3F2A)
          ..strokeWidth = 1,
      );
    }
    canvas.restore();

    // Grass top — layered gradient for natural variation.
    canvas.drawPath(
      contour,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFC0D87E),
            Color(0xFFA8C86A),
            Color(0xFF91B765),
            Color(0xFF85AB58),
          ],
        ).createShader(contour.getBounds()),
    );

    // Subtle grass texture — organic blotches, not a grid stamp.
    canvas.save();
    canvas.clipPath(contour);
    final rng = math.Random(42 + zone.index);
    for (var i = 0; i < 60; i++) {
      final x = bounds.left + rng.nextDouble() * bounds.width;
      final y = bounds.top + rng.nextDouble() * bounds.height;
      final r = 3.0 + rng.nextDouble() * 8;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 1.2),
        Paint()..color = Color.fromRGBO(
          130 + rng.nextInt(40),
          160 + rng.nextInt(40),
          80 + rng.nextInt(30),
          0.06 + rng.nextDouble() * 0.08,
        ),
      );
    }
    // Brighter highlights near the top-left (light source).
    for (var i = 0; i < 25; i++) {
      final x = bounds.left + rng.nextDouble() * bounds.width * 0.7;
      final y = bounds.top + rng.nextDouble() * bounds.height * 0.6;
      final r = 4.0 + rng.nextDouble() * 6;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r),
        Paint()..color = const Color(0x14C4DC8C),
      );
    }
    canvas.restore();

    // Grass edge — soft highlight on the top rim.
    canvas.drawPath(
      contour,
      Paint()
        ..color = const Color(0xFF6F915F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawPath(
      contour,
      Paint()
        ..color = const Color(0x33B8D480)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  // ─── Environment objects ───────────────────────────────────────────────

  List<_SceneObject> _environmentObjects(ZoneType zone) {
    final objects = <_SceneObject>[];

    // Edge trees at the back corners.
    objects.add(_SceneObject(
      const Offset(68, 152),
      (c) => _drawTree(c, const Offset(68, 152), zone, withFruit: false),
    ));
    if (zone != ZoneType.potager) {
      objects.add(_SceneObject(
        const Offset(322, 148),
        (c) => _drawTree(c, const Offset(322, 148), zone, withFruit: true),
      ));
    }

    // Shrubs and bushes along the borders.
    for (final bush in const [
      Offset(50, 115), Offset(92, 98), Offset(135, 108),
      Offset(255, 98), Offset(302, 108), Offset(338, 148),
      Offset(52, 248), Offset(342, 248),
    ]) {
      objects.add(_SceneObject(
        bush.translate(0, 6),
        (c) => _drawShrub(c, bush, 13, zone),
      ));
    }

    // Front border hedge.
    for (final point in const [
      Offset(58, 360), Offset(92, 382), Offset(138, 392),
      Offset(195, 396), Offset(252, 392), Offset(298, 382),
      Offset(332, 360),
    ]) {
      objects.add(_SceneObject(
        point.translate(0, 5),
        (c) => _drawShrub(c, point, 10, zone),
      ));
    }

    // Grass tufts.
    for (final tuft in const [
      Offset(60, 178), Offset(330, 172), Offset(48, 298),
      Offset(342, 296), Offset(120, 386), Offset(270, 388),
    ]) {
      objects.add(_SceneObject(tuft, (c) => _drawGrassTuft(c, tuft)));
    }

    // Flower clumps.
    final accent = switch (zone) {
      ZoneType.potager => const Color(0xFFF0D478),
      ZoneType.jardinFleuri => const Color(0xFFE8B0A8),
      ZoneType.verger => const Color(0xFFF5E7D4),
    };
    for (final bloom in [
      Offset(53, 212), Offset(337, 216), Offset(66, 336),
      Offset(327, 340),
      if (zone != ZoneType.potager) Offset(195, 390),
      if (zone == ZoneType.potager) Offset(235, 390),
    ]) {
      objects.add(_SceneObject(
        bloom.translate(0, 3),
        (c) => _drawFlowerClump(c, bloom, accent),
      ));
    }

    // Zone-specific accessories.
    if (zone == ZoneType.potager) {
      objects.add(_SceneObject(
        const Offset(330, 150).translate(0, 8),
        (c) => _drawWateringCan(c, const Offset(330, 150)),
      ));
      objects.add(_SceneObject(
        const Offset(330, 350).translate(0, 12),
        (c) => _drawNurseryCrate(c, const Offset(330, 350)),
      ));
    } else if (zone == ZoneType.jardinFleuri) {
      objects.add(_SceneObject(
        const Offset(330, 175).translate(0, 4),
        (c) => _drawBirdbath(c, const Offset(330, 175)),
      ));
    }

    // Path stones — placed after environment so they sort naturally.
    if (zone != ZoneType.potager) {
      for (final entry in _pathNodes(zone).asMap().entries) {
        objects.add(_SceneObject(
          entry.value,
          (c) => _drawStone(c, entry.value, entry.key),
        ));
      }
    }

    // Verger bench.
    if (zone == ZoneType.verger) {
      objects.add(_SceneObject(
        const Offset(195, 392),
        (c) => _sprites.draw(c, 'verger_banc_bois_ordinaire_00.png',
            const Offset(195, 392), 67, 38),
      ));
    }

    return objects;
  }

  List<Offset> _pathNodes(ZoneType zone) => switch (zone) {
    ZoneType.potager => const [],
    ZoneType.jardinFleuri => const [
      Offset(195, 388), Offset(195, 355),
      Offset(150, 335), Offset(240, 335),
      Offset(150, 285), Offset(240, 285),
      Offset(195, 250), Offset(195, 210), Offset(195, 175),
    ],
    ZoneType.verger => const [
      Offset(195, 388), Offset(195, 350),
      Offset(150, 330), Offset(240, 330),
      Offset(140, 280), Offset(250, 280),
    ],
  };

  // ─── Beds ──────────────────────────────────────────────────────────────

  void _drawBed(Canvas canvas, Offset point, ZoneType zone) {
    if (zone == ZoneType.verger) {
      _drawTreeBase(canvas, point);
      return;
    }
    if (zone != ZoneType.potager && _sprites.draw(
      canvas,
      'commun_parcelle_bois_vide_ordinaire_00.png',
      point.translate(0, 18),
      80,
      58,
    )) {
      return;
    }

    if (zone == ZoneType.potager) {
      canvas.save();
      canvas.clipPath(_islandContour(zone));
      PotagerPath.drawBedContact(canvas, point);
      canvas.restore();
    }

    // Contact shadow — soft, slightly offset.
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(2, 24), width: 76, height: 16),
      Paint()
        ..color = const Color(0x284B4B36)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Bed dimensions aligned to the 80×40 grid diamond.
    const w = 40.0; // half-width
    const h = 20.0; // half-height
    final fh = zone == ZoneType.potager ? 10.0 : 13.0;

    // Front-left face (darker, shadowed).
    final leftFace = Path()
      ..moveTo(point.dx - w, point.dy)
      ..lineTo(point.dx, point.dy + h)
      ..lineTo(point.dx, point.dy + h + fh)
      ..lineTo(point.dx - w, point.dy + fh)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = const Color(0xFF8B6845));

    // Front-right face (warmer, lit).
    final rightFace = Path()
      ..moveTo(point.dx, point.dy + h)
      ..lineTo(point.dx + w, point.dy)
      ..lineTo(point.dx + w, point.dy + fh)
      ..lineTo(point.dx, point.dy + h + fh)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = const Color(0xFFB08258));

    // Wood top rim — warm honey gradient.
    final topRim = Path()
      ..moveTo(point.dx, point.dy - h)
      ..lineTo(point.dx + w, point.dy)
      ..lineTo(point.dx, point.dy + h)
      ..lineTo(point.dx - w, point.dy)
      ..close();
    canvas.drawPath(
      topRim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFD9A86A), const Color(0xFFC4905A)],
        ).createShader(topRim.getBounds()),
    );

    // Soil interior — dark, rich brown.
    const soilInset = 3.0;
    final soil = Path()
      ..moveTo(point.dx, point.dy - h + soilInset)
      ..lineTo(point.dx + w - soilInset, point.dy)
      ..lineTo(point.dx, point.dy + h - soilInset)
      ..lineTo(point.dx - w + soilInset, point.dy)
      ..close();
    canvas.drawPath(
      soil,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A3F2E), Color(0xFF6B4D38)],
        ).createShader(soil.getBounds()),
    );

    // Soil texture — small irregular clumps.
    final rng = math.Random(point.dx.hashCode ^ point.dy.hashCode);
    canvas.save();
    canvas.clipPath(soil);
    for (var i = 0; i < 5; i++) {
      final dx = (rng.nextDouble() - 0.5) * (w * 1.3);
      final dy = (rng.nextDouble() - 0.3) * (h * 1.2);
      canvas.drawCircle(
        point.translate(dx, dy),
        1.5 + rng.nextDouble() * 2,
        Paint()..color = const Color(0x44604030),
      );
    }
    canvas.restore();

    // Corner posts — small vertical pegs at the bed corners.
    for (final corner in [
      point.translate(-w, 0),
      point.translate(w, 0),
      point.translate(0, h),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: corner.translate(0, 1), width: 6, height: 10),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFC49260),
      );
      canvas.drawLine(
        corner.translate(-1, 0),
        corner.translate(-1, 8),
        Paint()
          ..color = const Color(0xFFE6B57E)
          ..strokeWidth = 1,
      );
    }

    // Wood plank edge highlights.
    canvas.drawLine(
      point.translate(-w + 2, 1),
      point.translate(0, h + 1),
      Paint()
        ..color = const Color(0xFFE7B781)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      point.translate(1, h + 1),
      point.translate(w - 2, 1),
      Paint()
        ..color = const Color(0xFFE1AB75)
        ..strokeWidth = 1.5,
    );
  }

  void _drawTreeBase(Canvas canvas, Offset point) {
    if (_sprites.draw(
      canvas,
      'verger_pied_arbre_herbe_ordinaire_00.png',
      point.translate(0, 14),
      90,
      48,
    )) {
      return;
    }
    // Grass pad around tree trunk.
    _diamond(canvas, point, 42, 21, const Color(0xFF79995B));
    _diamond(canvas, point, 38, 19, const Color(0xFF8AAA68));
    // Small earth ring.
    canvas.drawCircle(point, 6, Paint()..color = const Color(0xFF6C503C));
  }

  // ─── Plants ────────────────────────────────────────────────────────────

  void _drawPlant(Canvas canvas, Offset point, Plant plant) {
    if (plant.progressSteps == 0 && plant.completedCycles == 0) {
      // Sown state — small soil mound with a tiny crack.
      canvas.drawCircle(point, 4, Paint()..color = const Color(0xFF5A3F2E));
      canvas.drawCircle(
        point.translate(1, -1),
        2,
        Paint()..color = const Color(0xFF6B4D38),
      );
      return;
    }

    final spritePrefix = switch (plant.species) {
      Species.tomate => 'potager_plante_tomate',
      Species.carotte => 'potager_plante_carotte',
      Species.courgette => 'potager_plante_courgette',
      Species.tournesol => 'fleurs_plante_tournesol',
      Species.tulipe => 'fleurs_plante_tulipe',
      Species.lavande => 'fleurs_plante_lavande',
      Species.pommier => 'verger_arbre_pommier',
      Species.poirier => 'verger_arbre_poirier',
    };
    final produce = plant.isReadyToHarvest ||
        (plant.completedCycles > 0 &&
            plant.progressSteps >= plant.targetSteps / 2);
    final spriteStage = switch (plant.stage) {
      PlantStage.graineGermee || PlantStage.jeunePlant => 'jeune',
      PlantStage.presqueMature => 'adulte_sans_production',
      PlantStage.mature => produce ? 'recoltable' : 'adulte_sans_production',
    };
    final tree = plant.species.zone == ZoneType.verger;
    final matureSize = switch (plant.species) {
      Species.tomate => const Size(76, 61),
      Species.carotte => const Size(77, 41),
      Species.courgette => const Size(82, 64),
      Species.tournesol => const Size(73, 83),
      Species.tulipe => const Size(67, 72),
      Species.lavande => const Size(67, 73),
      Species.pommier => const Size(137, 127),
      Species.poirier => const Size(139, 131),
    };
    final stageScale = switch (plant.stage) {
      PlantStage.graineGermee => tree ? 0.42 : 0.40,
      PlantStage.jeunePlant => tree ? 0.64 : 0.63,
      PlantStage.presqueMature => 0.83,
      PlantStage.mature => 1.0,
    };
    if (_sprites.draw(
      canvas,
      '${spritePrefix}_${spriteStage}_ordinaire_00.png',
      point.translate(0, tree ? 13 : 9),
      matureSize.width * stageScale,
      matureSize.height * stageScale,
    )) {
      return;
    }
    _drawPlantShape(canvas, point, plant, produce);
  }

  void _drawPlantShape(Canvas canvas, Offset point, Plant plant, bool produce) {
    final species = plant.species;
    final stage = plant.stage;
    final brilliant = plant.tier == GrowthTier.brillante;
    final isTree = species.zone == ZoneType.verger;

    if (isTree) {
      _drawTreeCanopy(canvas, point, species, stage, produce, brilliant);
      return;
    }

    switch (species) {
      case Species.tomate:
        _drawTomate(canvas, point, stage, produce, brilliant);
      case Species.carotte:
        _drawCarotte(canvas, point, stage, produce, brilliant);
      case Species.courgette:
        _drawCourgette(canvas, point, stage, produce, brilliant);
      case Species.tournesol:
        _drawTournesol(canvas, point, stage, produce, brilliant);
      case Species.tulipe:
        _drawTulipe(canvas, point, stage, produce, brilliant);
      case Species.lavande:
        _drawLavande(canvas, point, stage, produce, brilliant);
      default:
        break;
    }
  }

  // ─── Vegetable plants ─────────────────────────────────────────────────

  void _drawTomate(Canvas c, Offset p, PlantStage stage, bool produce, bool brilliant) {
    final h = switch (stage) {
      PlantStage.graineGermee => 10.0,
      PlantStage.jeunePlant => 24.0,
      PlantStage.presqueMature => 48.0,
      PlantStage.mature => 60.0,
    };
    // Stem.
    _stem(c, p, h, const Color(0xFF52764F), 3);
    // Bushy foliage — multiple layered ovals for volume.
    if (h > 15) {
      final layers = <(Offset, double, double, Color)>[
        (p.translate(-14, -h * 0.4), 22, 14, const Color(0xFF426D4D)),
        (p.translate(13, -h * 0.55), 24, 15, const Color(0xFF4F7946)),
        (p.translate(-6, -h * 0.7), 20, 13, const Color(0xFF5D8A51)),
        (p.translate(8, -h * 0.85), 18, 12, const Color(0xFF6F985F)),
        (p.translate(-12, -h * 0.92), 16, 10, const Color(0xFF829E70)),
      ];
      for (final (center, w, hh, color) in layers) {
        c.drawOval(
          Rect.fromCenter(center: center, width: w, height: hh),
          Paint()..color = color,
        );
      }
      // Highlight glints — upper-left.
      c.drawOval(
        Rect.fromCenter(center: p.translate(-14, -h * 0.45), width: 10, height: 5),
        Paint()..color = const Color(0x55A5C46B),
      );
      c.drawOval(
        Rect.fromCenter(center: p.translate(10, -h * 0.82), width: 8, height: 4),
        Paint()..color = const Color(0x55B0CE72),
      );
    }
    // Fruits.
    if (produce) {
      for (final fruit in [
        p.translate(-10, -h * 0.5),
        p.translate(8, -h * 0.65),
        p.translate(2, -h * 0.35),
      ]) {
        c.drawCircle(fruit, 5, Paint()..color = const Color(0xFFC96955));
        c.drawCircle(fruit.translate(-1.5, -1.5), 2,
            Paint()..color = const Color(0xFFE08A70));
      }
    }
    if (brilliant) {
      _brilliantSparkle(c, p.translate(-8, -h * 0.8));
    }
  }

  void _drawCarotte(Canvas c, Offset p, PlantStage stage, bool produce, bool brilliant) {
    final h = switch (stage) {
      PlantStage.graineGermee => 6.0,
      PlantStage.jeunePlant => 16.0,
      PlantStage.presqueMature => 28.0,
      PlantStage.mature => 36.0,
    };
    if (h < 12) {
      _sprout(c, p, h);
      return;
    }
    // Multiple carrot tops — fan of feathery leaves.
    for (var i = -2; i <= 2; i++) {
      final dx = i * 7.0;
      final tip = p.translate(dx, -h);
      // Stem.
      _stem(c, p.translate(dx * 0.3, 0), h * (1 - dx.abs() * 0.02),
          const Color(0xFF52764F), 2);
      // Feathery leaves — layered ovals getting smaller toward top.
      c.drawOval(
        Rect.fromCenter(center: tip.translate(0, 6), width: 14, height: 8),
        Paint()..color = const Color(0xFF4F7946),
      );
      c.drawOval(
        Rect.fromCenter(center: tip.translate(-2, 2), width: 10, height: 6),
        Paint()..color = const Color(0xFF5D8A51),
      );
      c.drawOval(
        Rect.fromCenter(center: tip.translate(2, -1), width: 8, height: 5),
        Paint()..color = const Color(0xFF7BA658),
      );
    }
    if (produce) {
      // Carrot root poking from soil.
      c.drawPath(
        Path()
          ..moveTo(p.dx - 6, p.dy - 2)
          ..lineTo(p.dx + 6, p.dy - 2)
          ..lineTo(p.dx, p.dy + 12)
          ..close(),
        Paint()..color = const Color(0xFFE39A51),
      );
    }
    if (brilliant) {
      _brilliantSparkle(c, p.translate(0, -h * 0.7));
    }
  }

  void _drawCourgette(Canvas c, Offset p, PlantStage stage, bool produce, bool brilliant) {
    final h = switch (stage) {
      PlantStage.graineGermee => 8.0,
      PlantStage.jeunePlant => 20.0,
      PlantStage.presqueMature => 38.0,
      PlantStage.mature => 50.0,
    };
    _stem(c, p, h, const Color(0xFF52764F), 4);
    if (h > 15) {
      // Large, broad leaves — distinctive from tomato.
      for (final leaf in [
        (p.translate(-16, -h * 0.3), 26.0, 16.0, const Color(0xFF3D6B3A)),
        (p.translate(14, -h * 0.45), 28.0, 17.0, const Color(0xFF4F7946)),
        (p.translate(-8, -h * 0.6), 24.0, 15.0, const Color(0xFF5D8A51)),
        (p.translate(10, -h * 0.78), 22.0, 14.0, const Color(0xFF6F985F)),
      ]) {
        final (center, w, hh, color) = leaf;
        c.drawOval(
          Rect.fromCenter(center: center, width: w, height: hh),
          Paint()..color = color,
        );
        // Leaf veins — subtle lighter lines.
        c.drawOval(
          Rect.fromCenter(center: center.translate(-2, -1), width: w * 0.5, height: hh * 0.4),
          Paint()..color = const Color(0x22A5C46B),
        );
      }
    }
    if (produce) {
      // Courgette fruit — dark green oval at base.
      c.drawOval(
        Rect.fromCenter(center: p.translate(8, -h * 0.2), width: 18, height: 7),
        Paint()..color = const Color(0xFF527C49),
      );
      c.drawOval(
        Rect.fromCenter(center: p.translate(8, -h * 0.2 - 1), width: 12, height: 4),
        Paint()..color = const Color(0xFF6B9A55),
      );
    }
    if (brilliant) {
      _brilliantSparkle(c, p.translate(-6, -h * 0.7));
    }
  }

  // ─── Flower plants ─────────────────────────────────────────────────────

  void _drawTournesol(Canvas c, Offset p, PlantStage stage, bool produce, bool brilliant) {
    final h = switch (stage) {
      PlantStage.graineGermee => 8.0,
      PlantStage.jeunePlant => 22.0,
      PlantStage.presqueMature => 48.0,
      PlantStage.mature => 72.0,
    };
    _stem(c, p, h, const Color(0xFF52764F), 3);
    if (h > 20) {
      // Leaves along the stem.
      c.drawOval(
        Rect.fromCenter(center: p.translate(-10, -h * 0.35), width: 16, height: 8),
        Paint()..color = const Color(0xFF5D8A51),
      );
      c.drawOval(
        Rect.fromCenter(center: p.translate(10, -h * 0.55), width: 16, height: 8),
        Paint()..color = const Color(0xFF7BA658),
      );
    }
    if (h > 35) {
      // Sunflower head — multiple petals around a dark center.
      final head = p.translate(0, -h);
      final petalR = h > 55 ? 10.0 : 7.0;
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi * 2 / 8;
        c.drawCircle(
          head.translate(math.cos(angle) * petalR * 0.7, math.sin(angle) * petalR * 0.7),
          petalR * 0.5,
          Paint()..color = const Color(0xFFF0C945),
        );
      }
      c.drawCircle(head, petalR * 0.45, Paint()..color = const Color(0xFF765338));
      c.drawCircle(head.translate(-1, -1), petalR * 0.25,
          Paint()..color = const Color(0xFF9A6B45));
    }
    if (brilliant) {
      _brilliantSparkle(c, p.translate(0, -h * 0.8));
    }
  }

  void _drawTulipe(Canvas c, Offset p, PlantStage stage, bool produce, bool brilliant) {
    final h = switch (stage) {
      PlantStage.graineGermee => 6.0,
      PlantStage.jeunePlant => 18.0,
      PlantStage.presqueMature => 38.0,
      PlantStage.mature => 56.0,
    };
    if (h < 12) {
      _sprout(c, p, h);
      return;
    }
    // Multiple tulip stems — a cluster.
    for (var i = -1; i <= 1; i++) {
      final dx = i * 9.0;
      final tip = p.translate(dx, -h * (1 - dx.abs() * 0.01));
      _stem(c, p.translate(dx * 0.5, 0), h * (1 - dx.abs() * 0.01),
          const Color(0xFF52764F), 2);
      if (h > 30) {
        // Tulip flower — cup shape.
        c.drawOval(
          Rect.fromCenter(center: tip.translate(0, -2), width: 10, height: 16),
          Paint()..color = const Color(0xFFE79AAD),
        );
        c.drawOval(
          Rect.fromCenter(center: tip.translate(0, -4), width: 7, height: 12),
          Paint()..color = const Color(0xFFEFB8C6),
        );
        // Petal highlight.
        c.drawOval(
          Rect.fromCenter(center: tip.translate(-2, -5), width: 4, height: 8),
          Paint()..color = const Color(0xFFF5CDD8),
        );
      } else if (h > 15) {
        // Bud.
        c.drawOval(
          Rect.fromCenter(center: tip, width: 6, height: 10),
          Paint()..color = const Color(0xFFE79AAD),
        );
      }
    }
    if (brilliant && h > 30) {
      _brilliantSparkle(c, p.translate(0, -h * 0.7));
    }
  }

  void _drawLavande(Canvas c, Offset p, PlantStage stage, bool produce, bool brilliant) {
    final h = switch (stage) {
      PlantStage.graineGermee => 6.0,
      PlantStage.jeunePlant => 16.0,
      PlantStage.presqueMature => 34.0,
      PlantStage.mature => 52.0,
    };
    if (h < 12) {
      _sprout(c, p, h);
      return;
    }
    // Multiple lavender stems — a bushy cluster.
    for (var i = -2; i <= 2; i++) {
      final dx = i * 6.0;
      final tip = p.translate(dx, -h * (1 - dx.abs() * 0.02));
      _stem(c, p.translate(dx * 0.4, 0), h * (1 - dx.abs() * 0.02),
          const Color(0xFF52764F), 1.5);
      if (h > 25) {
        // Lavender spike — small ovals.
        c.drawOval(
          Rect.fromCenter(center: tip.translate(0, -4), width: 5, height: 14),
          Paint()..color = const Color(0xFF9C8BB5),
        );
        c.drawOval(
          Rect.fromCenter(center: tip.translate(0, -8), width: 4, height: 8),
          Paint()..color = const Color(0xFFB09EC8),
        );
      } else if (h > 15) {
        c.drawOval(
          Rect.fromCenter(center: tip, width: 4, height: 8),
          Paint()..color = const Color(0xFFA695CF),
        );
      }
    }
    if (brilliant && h > 25) {
      _brilliantSparkle(c, p.translate(0, -h * 0.7));
    }
  }

  // ─── Trees ─────────────────────────────────────────────────────────────

  void _drawTreeCanopy(Canvas c, Offset p, Species species, PlantStage stage,
      bool produce, bool brilliant) {
    final h = switch (stage) {
      PlantStage.graineGermee => 28.0,
      PlantStage.jeunePlant => 52.0,
      PlantStage.presqueMature => 88.0,
      PlantStage.mature => 116.0,
    };
    // Contact shadow.
    c.drawOval(
      Rect.fromCenter(center: p.translate(2, 3), width: 60, height: 18),
      Paint()
        ..color = const Color(0x334D6A3F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Trunk — tapering with slight flare at base.
    final trunkW = h < 50 ? 5.0 : 9.0;
    _stem(c, p, h, const Color(0xFF8A674A), trunkW);
    // Trunk texture — darker side.
    c.drawLine(
      p.translate(trunkW * 0.3, 0),
      p.translate(trunkW * 0.3, -h + 5),
      Paint()
        ..color = const Color(0xFF6F5039)
        ..strokeWidth = trunkW * 0.4
        ..strokeCap = StrokeCap.round,
    );
    // Branches.
    if (h > 50) {
      final bark = Paint()
        ..color = const Color(0xFF8A674A)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      c.drawLine(p.translate(0, -h * 0.5), p.translate(-18, -h * 0.72), bark);
      c.drawLine(p.translate(0, -h * 0.58), p.translate(16, -h * 0.78), bark);
      bark.strokeWidth = 2.5;
      c.drawLine(p.translate(-12, -h * 0.68), p.translate(-24, -h * 0.85), bark);
      c.drawLine(p.translate(10, -h * 0.72), p.translate(22, -h * 0.88), bark);
    }
    // Crown — layered masses for depth.
    final tip = p.translate(0, -h);
    final crownR = h < 50 ? 14.0 : h < 80 ? 26.0 : 34.0;
    // Dark base layer.
    for (final mass in [
      tip.translate(-crownR * 0.6, crownR * 0.3),
      tip.translate(crownR * 0.7, crownR * 0.25),
      tip.translate(0, crownR * 0.1),
    ]) {
      c.drawCircle(mass, crownR, Paint()..color = const Color(0xFF3D6B3A));
    }
    // Mid layer.
    for (final mass in [
      tip.translate(-crownR * 0.5, -crownR * 0.1),
      tip.translate(crownR * 0.5, -crownR * 0.15),
      tip.translate(0, -crownR * 0.3),
    ]) {
      c.drawCircle(mass, crownR * 0.85, Paint()..color = const Color(0xFF4F7946));
    }
    // Highlight layer — upper-left.
    c.drawCircle(
      tip.translate(-crownR * 0.35, -crownR * 0.4),
      crownR * 0.6,
      Paint()..color = const Color(0xFF6F9D53),
    );
    c.drawCircle(
      tip.translate(-crownR * 0.15, -crownR * 0.55),
      crownR * 0.4,
      Paint()..color = const Color(0xFF829E70),
    );
    // Scattered leaves for texture.
    final rng = math.Random(p.dx.hashCode);
    for (var i = 0; i < 8; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = rng.nextDouble() * crownR * 0.9;
      c.drawOval(
        Rect.fromCenter(
          center: tip.translate(math.cos(angle) * dist, math.sin(angle) * dist * 0.6 - 4),
          width: 8,
          height: 5,
        ),
        Paint()..color = rng.nextBool()
            ? const Color(0xFFA4C667)
            : const Color(0xFF7BA658),
      );
    }
    // Fruits.
    if (produce) {
      final fruitColor = species == Species.poirier
          ? const Color(0xFFCFBB5A)
          : const Color(0xFFD86D50);
      final fruitHighlight = species == Species.poirier
          ? const Color(0xFFE5D480)
          : const Color(0xFFED9078);
      for (final fruit in [
        tip.translate(-crownR * 0.5, crownR * 0.1),
        tip.translate(crownR * 0.3, crownR * 0.2),
        tip.translate(crownR * 0.6, -crownR * 0.1),
      ]) {
        c.drawCircle(fruit, 5, Paint()..color = fruitColor);
        c.drawCircle(fruit.translate(-1.5, -1.5), 2, Paint()..color = fruitHighlight);
      }
    }
    if (brilliant) {
      _brilliantSparkle(c, tip.translate(-crownR * 0.3, -crownR * 0.3));
    }
  }

  void _drawTree(Canvas c, Offset foot, ZoneType zone, {required bool withFruit}) {
    if (_sprites.draw(
      c,
      withFruit && zone == ZoneType.verger
          ? 'verger_arbre_pommier_recoltable_ordinaire_00.png'
          : 'verger_arbre_pommier_adulte_sans_production_ordinaire_00.png',
      foot,
      88,
      91,
    )) {
      return;
    }
    _drawTreeCanopy(c, foot, Species.pommier, PlantStage.mature, withFruit, false);
  }

  // ─── Environment rendering ─────────────────────────────────────────────

  void _drawShrub(Canvas c, Offset point, double radius, ZoneType zone) {
    if (_sprites.draw(
      c,
      'commun_buisson_haie_ordinaire_00.png',
      point.translate(0, 10),
      radius * 3.0,
      radius * 1.9,
    )) {
      return;
    }
    // Contact shadow.
    c.drawOval(
      Rect.fromCenter(center: point.translate(1, 5), width: radius * 2.8, height: radius * 1.1),
      Paint()..color = const Color(0x3347683F),
    );
    // Base masses — dark to light.
    for (final (center, r, color) in [
      (point.translate(-radius * 0.5, 0), radius * 0.7, const Color(0xFF3D6B3A)),
      (point.translate(radius * 0.4, -radius * 0.15), radius * 0.65, const Color(0xFF4F7946)),
      (point.translate(-radius * 0.1, -radius * 0.35), radius * 0.6, const Color(0xFF5D8A51)),
      (point.translate(radius * 0.2, -radius * 0.1), radius * 0.5, const Color(0xFF6F985F)),
    ]) {
      c.drawCircle(center, r, Paint()..color = color);
    }
    // Highlight glints.
    for (final (center, w, hh) in [
      (point.translate(-radius * 0.4, -radius * 0.45), radius * 0.5, radius * 0.25),
      (point.translate(radius * 0.3, -radius * 0.5), radius * 0.4, radius * 0.2),
    ]) {
      c.drawOval(
        Rect.fromCenter(center: center, width: w, height: hh),
        Paint()..color = const Color(0x66A7C76B),
      );
    }
    // Scattered leaves.
    final rng = math.Random(point.dx.hashCode);
    for (var i = 0; i < 5; i++) {
      final dx = (rng.nextDouble() - 0.5) * radius * 2;
      final dy = -rng.nextDouble() * radius * 1.2;
      c.drawOval(
        Rect.fromCenter(center: point.translate(dx, dy), width: 7, height: 4),
        Paint()..color = rng.nextBool()
            ? const Color(0xFF9ABC63)
            : const Color(0xFFB4CF76),
      );
    }
    // Zone accent flower.
    if (zone == ZoneType.jardinFleuri) {
      _drawSmallFlower(c, point.translate(radius * 0.3, -radius * 0.4), const Color(0xFFE8B0A8), 3);
    } else if (zone == ZoneType.verger) {
      c.drawCircle(point.translate(radius * 0.3, -radius * 0.4), 2.5,
          Paint()..color = const Color(0xFFD86E58));
    }
  }

  void _drawStone(Canvas c, Offset center, int variant) {
    if (_sprites.draw(
      c,
      'commun_dalle_pierre_creme_ordinaire_00.png',
      center.translate(0, 6),
      46,
      26,
    )) {
      return;
    }
    final hw = 21.0 + (variant % 3) * 1.5;
    final hh = 11.0 + (variant % 2);
    // Contact shadow.
    c.drawOval(
      Rect.fromCenter(center: center.translate(1, hh + 1), width: hw * 1.8, height: hh * 0.6),
      Paint()..color = const Color(0x22706050),
    );
    // Stone side.
    final side = Path()
      ..moveTo(center.dx - hw, center.dy)
      ..lineTo(center.dx, center.dy + hh)
      ..lineTo(center.dx + hw, center.dy)
      ..lineTo(center.dx + hw, center.dy + hh * 0.6)
      ..lineTo(center.dx, center.dy + hh + hh * 0.6)
      ..lineTo(center.dx - hw, center.dy + hh * 0.6)
      ..close();
    c.drawPath(side, Paint()..color = const Color(0xFFC9C0A8));
    // Stone top — warm cream with slight variation.
    final top = Path()
      ..moveTo(center.dx, center.dy - hh)
      ..lineTo(center.dx + hw, center.dy)
      ..lineTo(center.dx, center.dy + hh)
      ..lineTo(center.dx - hw, center.dy)
      ..close();
    c.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFF5EED8), const Color(0xFFE8DFC4)],
        ).createShader(top.getBounds()),
    );
    // Edge highlight.
    c.drawPath(
      top,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawGrassTuft(Canvas c, Offset point) {
    final paint = Paint()
      ..color = const Color(0xFF779F61)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // Multiple blades at different angles for a natural look.
    for (final blade in [
      (-5, -8), (-2, -11), (1, -10), (4, -8), (-3, -6),
    ]) {
      c.drawLine(point, point.translate(blade.$1.toDouble(), blade.$2.toDouble()), paint);
    }
    // Lighter tips.
    final lightPaint = Paint()
      ..color = const Color(0xFFA5C46B)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    c.drawLine(point.translate(-2, -5), point.translate(-3, -9), lightPaint);
    c.drawLine(point.translate(1, -5), point.translate(2, -9), lightPaint);
  }

  void _drawFlowerClump(Canvas c, Offset point, Color color) {
    final pink = color == const Color(0xFFE8B0A8);
    if (_sprites.draw(
      c,
      pink
          ? 'fleurs_fleurs_sauvages_roses_ordinaire_00.png'
          : 'commun_fleurs_marguerites_blanches_ordinaire_00.png',
      point.translate(0, 3),
      22,
      21,
    )) {
      return;
    }
    // Grass base.
    _drawGrassTuft(c, point);
    // Three flowers at different heights.
    _drawSmallFlower(c, point.translate(-5, -9), color, 4);
    _drawSmallFlower(c, point.translate(6, -6), color, 3);
    _drawSmallFlower(c, point.translate(0, -12), color, 3);
  }

  void _drawSmallFlower(Canvas c, Offset center, Color color, double radius) {
    // Petals.
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      c.drawCircle(
        center.translate(math.cos(angle) * radius * 0.6, math.sin(angle) * radius * 0.6),
        radius * 0.5,
        Paint()..color = color,
      );
    }
    // Center.
    c.drawCircle(center, radius * 0.35, Paint()..color = const Color(0xFFE6C65D));
  }

  void _drawWateringCan(Canvas c, Offset point) {
    if (_sprites.draw(
      c,
      'potager_arrosoir_metal_ordinaire_00.png',
      point.translate(0, 8),
      38,
      31,
    )) {
      return;
    }
    // Shadow.
    c.drawOval(
      Rect.fromCenter(center: point.translate(0, 8), width: 32, height: 10),
      Paint()..color = const Color(0x28715D4D),
    );
    // Body — slightly tapered.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: point, width: 20, height: 16),
        const Radius.circular(3),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9FB5AE), Color(0xFF7A948C)],
        ).createShader(Rect.fromCenter(center: point, width: 20, height: 16)),
    );
    // Handle.
    c.drawArc(
      Rect.fromCenter(center: point.translate(-8, -4), width: 12, height: 10),
      math.pi * 0.3, math.pi * 0.9, false,
      Paint()
        ..color = const Color(0xFF6E8982)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Spout.
    c.drawPath(
      Path()
        ..moveTo(point.dx + 8, point.dy - 1)
        ..lineTo(point.dx + 22, point.dy - 8)
        ..lineTo(point.dx + 22, point.dy - 5)
        ..lineTo(point.dx + 8, point.dy + 2)
        ..close(),
      Paint()..color = const Color(0xFF78968E),
    );
    // Highlight.
    c.drawLine(
      point.translate(-6, -5),
      point.translate(4, -5),
      Paint()..color = const Color(0x44D0E0DB)..strokeWidth = 2,
    );
  }

  void _drawNurseryCrate(Canvas c, Offset point) {
    if (_sprites.draw(
      c,
      'potager_caisse_semis_bois_ordinaire_00.png',
      point.translate(0, 14),
      51,
      39,
    )) {
      return;
    }
    // Shadow.
    c.drawOval(
      Rect.fromCenter(center: point.translate(0, 12), width: 48, height: 14),
      Paint()..color = const Color(0x335A7045),
    );
    const w = 25.0, h = 12.0, fh = 8.0;
    // Left face.
    c.drawPath(
      Path()
        ..moveTo(point.dx - w, point.dy)
        ..lineTo(point.dx, point.dy + h)
        ..lineTo(point.dx, point.dy + h + fh)
        ..lineTo(point.dx - w, point.dy + fh)
        ..close(),
      Paint()..color = const Color(0xFF8B6845),
    );
    // Right face.
    c.drawPath(
      Path()
        ..moveTo(point.dx, point.dy + h)
        ..lineTo(point.dx + w, point.dy)
        ..lineTo(point.dx + w, point.dy + fh)
        ..lineTo(point.dx, point.dy + h + fh)
        ..close(),
      Paint()..color = const Color(0xFFA07A52),
    );
    // Top — wood planks.
    _diamond(c, point, w, h, const Color(0xFFB08258));
    for (final dx in [-12.0, -4.0, 4.0, 12.0]) {
      c.drawLine(
        point.translate(dx, -h + (dx.abs() * h / w)),
        point.translate(dx, h - (dx.abs() * h / w)),
        Paint()
          ..color = const Color(0xFF8B6845)
          ..strokeWidth = 1,
      );
    }
    // Sprouts.
    for (final dx in [-10.0, 0.0, 10.0]) {
      final sprout = point.translate(dx, -2);
      _stem(c, sprout, 10, const Color(0xFF547A4B), 1.5);
      c.drawOval(
        Rect.fromCenter(center: sprout.translate(-3, -9), width: 9, height: 5),
        Paint()..color = const Color(0xFF7CA559),
      );
      c.drawOval(
        Rect.fromCenter(center: sprout.translate(3, -10), width: 9, height: 5),
        Paint()..color = const Color(0xFFA0C46B),
      );
    }
  }

  void _drawBirdbath(Canvas c, Offset point) {
    if (_sprites.draw(
      c,
      'fleurs_bain_oiseaux_pierre_ordinaire_00.png',
      point.translate(0, 5),
      38,
      49,
    )) {
      return;
    }
    // Shadow.
    c.drawOval(
      Rect.fromCenter(center: point.translate(0, 6), width: 40, height: 12),
      Paint()..color = const Color(0x335A7045),
    );
    // Pedestal.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: point.translate(0, -6), width: 10, height: 28),
        const Radius.circular(3),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC4C7B8), Color(0xFFA4A798)],
        ).createShader(Rect.fromCenter(center: point.translate(0, -6), width: 10, height: 28)),
    );
    // Basin.
    c.drawOval(
      Rect.fromCenter(center: point.translate(0, -22), width: 36, height: 14),
      Paint()..color = const Color(0xFFD7D6C2),
    );
    // Water.
    c.drawOval(
      Rect.fromCenter(center: point.translate(0, -24), width: 28, height: 7),
      Paint()..color = const Color(0xFF8DB8B4),
    );
    // Water glint.
    c.drawOval(
      Rect.fromCenter(center: point.translate(6, -26), width: 8, height: 2),
      Paint()..color = const Color(0xFFCFEBDF),
    );
  }

  void _drawSelection(Canvas c, Offset point, ZoneType zone) {
    _diamond(
      c,
      point,
      zone == ZoneType.verger ? 49 : 43,
      zone == ZoneType.verger ? 24 : 22,
      const Color(0x0063845B),
      stroke: const Color(0xFF2B3C32),
      strokeWidth: 2,
    );
  }

  // ─── Drawing helpers ───────────────────────────────────────────────────

  void _stem(Canvas c, Offset base, double height, Color color, double width) {
    c.drawLine(
      base,
      base.translate(0, -height),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _sprout(Canvas c, Offset base, double height) {
    c.drawLine(
      base,
      base.translate(0, -height),
      Paint()
        ..color = const Color(0xFF52764F)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    c.drawOval(
      Rect.fromCenter(center: base.translate(-2, -height), width: 6, height: 3),
      Paint()..color = const Color(0xFF7BA658),
    );
    c.drawOval(
      Rect.fromCenter(center: base.translate(2, -height + 1), width: 6, height: 3),
      Paint()..color = const Color(0xFFA0C46B),
    );
  }

  void _brilliantSparkle(Canvas c, Offset point) {
    c.drawCircle(point, 3, Paint()..color = const Color(0xCCF5EDDA));
    c.drawCircle(point.translate(-1, -1), 1.5, Paint()..color = const Color(0xFFFFFFFF));
  }

  void _diamond(
    Canvas canvas,
    Offset center,
    double halfWidth,
    double halfHeight,
    Color fill, {
    Color? stroke,
    double strokeWidth = 1,
  }) {
    final path = Path()
      ..moveTo(center.dx, center.dy - halfHeight)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..lineTo(center.dx, center.dy + halfHeight)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    if (stroke != null) {
      final strokePaint = Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawPath(path, strokePaint);
    }
  }
}
