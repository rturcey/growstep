import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'garden_state.dart';
import 'garden_sprites.dart';

/// Modular garden scene rendered by Flame at phone scale.
///
/// One island is rendered at a time on a fixed 390 × 450 logical canvas. The
/// apparent scale never shrinks with phone height: the Flutter layout adapts
/// around the scene instead of rescaling the world.
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

  void _drawIsland(Canvas canvas, ZoneType zone) {
    _drawTerrain(canvas, zone);
    _drawPath(canvas, zone);
    _drawEnvironment(canvas, zone);
    _drawSlots(canvas, zone);
  }

  /// Grass top surface as one continuous body; the brown earth slice is
  /// visible only on the exterior contour. No interior dirt seams appear.
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
    canvas.drawPath(
      earth.shift(const Offset(3, 4)),
      Paint()..color = const Color(0x335A7850),
    );
    canvas.drawPath(
      earth,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFAA805B), Color(0xFF76543F)],
        ).createShader(earth.getBounds()),
    );
    canvas.drawPath(
      contour,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB5D47C), Color(0xFF91B765)],
        ).createShader(contour.getBounds()),
    );
    canvas.save();
    canvas.clipPath(contour);
    for (var row = -1; row < 21; row++) {
      final y = row * 20.0;
      for (var col = -1; col < 15; col++) {
        final x = col * 80.0 + (row.isOdd ? 40 : 0);
        _sprites.draw(
          canvas,
          'commun_terrain_case_herbe_surface_ordinaire_00.png',
          Offset(x, y + 21),
          80,
          42,
          opacity: 0.25,
        );
      }
    }
    canvas.restore();
    canvas.drawPath(
      contour,
      Paint()
        ..color = const Color(0xFF6F915F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Connected stone route entering from the front and branching between the
  /// planting locations without crossing their footprints. Grass stays visible
  /// between the stones.
  List<Offset> _pathNodes(ZoneType zone) => switch (zone) {
    ZoneType.potager || ZoneType.jardinFleuri => const [
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

  void _drawPath(Canvas canvas, ZoneType zone) {
    final nodes = _pathNodes(zone);
    for (var index = 0; index < nodes.length; index++) {
      _drawStone(canvas, nodes[index], index);
    }
  }

  void _drawStone(Canvas canvas, Offset center, int variant) {
    final halfWidth = 23.0 + (variant % 3) * 1.5;
    final halfHeight = 12.5 + (variant % 2);
    if (_sprites.draw(
      canvas,
      'commun_dalle_pierre_creme_ordinaire_00.png',
      center.translate(0, 14),
      halfWidth * 2,
      halfHeight * 2,
    )) {
      return;
    }
    _diamond(
      canvas,
      center,
      halfWidth,
      halfHeight,
      const Color(0xFFF2EBD8),
      stroke: const Color(0xFFC9C0A8),
    );
  }

  void _drawEnvironment(Canvas canvas, ZoneType zone) {
    final accent = switch (zone) {
      ZoneType.potager => const Color(0xFFF0D478),
      ZoneType.jardinFleuri => const Color(0xFFE8B0A8),
      ZoneType.verger => const Color(0xFFF5E7D4),
    };
    _edgeTree(canvas, const Offset(70, 150), zone.index);
    if (zone != ZoneType.potager) {
      _edgeTree(canvas, const Offset(318, 142), zone.index);
    }
    for (final bush in const [
      Offset(50, 120), Offset(95, 100), Offset(135, 110),
      Offset(260, 100), Offset(305, 112), Offset(335, 150),
      Offset(55, 250), Offset(340, 250),
      Offset(90, 380), Offset(300, 380),
    ]) {
      _shrub(canvas, bush, 14, zone.index);
    }
    for (final tuft in const [
      Offset(60, 180), Offset(330, 175), Offset(50, 300),
      Offset(340, 300), Offset(120, 388), Offset(270, 388),
    ]) {
      _grassTuft(canvas, tuft);
    }
    for (final bloom in const [
      Offset(55, 215), Offset(335, 220), Offset(70, 340),
      Offset(325, 345), Offset(195, 392),
    ]) {
      _flowerClump(canvas, bloom, accent);
    }
    for (final point in const [
      Offset(60, 365), Offset(95, 388), Offset(140, 396),
      Offset(195, 398), Offset(250, 396), Offset(295, 388),
      Offset(330, 365),
    ]) {
      _shrub(canvas, point, 11, zone.index);
    }
    if (zone == ZoneType.potager) {
      _wateringCan(canvas, const Offset(330, 150));
      _nurseryCrate(canvas, const Offset(330, 350));
      _sprites.draw(
        canvas,
        'commun_chien_idle_ordinaire_00.png',
        const Offset(195, 372),
        48,
        42,
      );
    } else if (zone == ZoneType.jardinFleuri) {
      _birdbath(canvas, const Offset(330, 175));
    }
  }

  void _drawSlots(Canvas canvas, ZoneType zone) {
    final anchors = anchorsFor(zone);
    final purchased = snapshot.zones[zone]!;
    // Depth sort by ground-contact Y so nearer plants overlap farther ones.
    final order = List.generate(purchased.length, (i) => i)
      ..sort((a, b) => anchors[a].dy.compareTo(anchors[b].dy));
    for (final slot in order) {
      final point = anchors[slot];
      if (zone == ZoneType.verger) {
        if (!_sprites.draw(
          canvas,
          'verger_pied_arbre_herbe_ordinaire_00.png',
          point.translate(0, 14),
          90,
          48,
        )) {
          _diamond(
            canvas,
            point,
            42,
            21,
            const Color(0xFF79995B),
            stroke: const Color(0xFF52764F),
          );
        }
      } else {
        _drawBed(canvas, point);
      }
      if (purchased[slot] != null) {
        _drawPlant(canvas, point, purchased[slot]!);
      }
      if (zone == currentZone && selectedSlot == slot) {
        _diamond(
          canvas,
          point,
          zone == ZoneType.verger ? 49 : 43,
          zone == ZoneType.verger ? 24 : 22,
          const Color(0x0063845B),
          stroke: const Color(0xFF2B3C32),
          strokeWidth: 2,
        );
      }
      if (showTouchTargets && zone == currentZone) {
        canvas.drawRect(
          Rect.fromCenter(center: point, width: touchSize, height: touchSize),
          Paint()
            ..color = const Color(0x7763845B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    if (zone == ZoneType.verger) {
      _sprites.draw(
        canvas,
        'verger_banc_bois_ordinaire_00.png',
        const Offset(195, 392),
        67,
        38,
      );
    }
  }

  void _drawBed(Canvas canvas, Offset point) {
    if (_sprites.draw(
      canvas,
      'commun_parcelle_bois_vide_ordinaire_00.png',
      point.translate(0, 36),
      100,
      72,
    )) {
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(2, 27), width: 88, height: 18),
      Paint()..color = const Color(0x304B4B36),
    );
    final side = Path()
      ..moveTo(point.dx - 45, point.dy)
      ..lineTo(point.dx, point.dy + 23)
      ..lineTo(point.dx + 45, point.dy)
      ..lineTo(point.dx + 45, point.dy + 13)
      ..lineTo(point.dx, point.dy + 36)
      ..lineTo(point.dx - 45, point.dy + 13)
      ..close();
    canvas.drawPath(side, Paint()..color = const Color(0xFF9B6D49));
    final rightFace = Path()
      ..moveTo(point.dx, point.dy + 23)
      ..lineTo(point.dx + 45, point.dy)
      ..lineTo(point.dx + 45, point.dy + 13)
      ..lineTo(point.dx, point.dy + 36)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = const Color(0xFFBD8A59));
    _diamond(canvas, point, 45, 23, const Color(0xFFD1A16B));
    _diamond(canvas, point, 38, 18, const Color(0xFF624938));
    for (final mark in const [
      Offset(-21, -3),
      Offset(-11, 7),
      Offset(2, -8),
      Offset(14, 4),
      Offset(24, -2),
      Offset(-2, 11),
    ]) {
      canvas.drawLine(
        point + mark,
        point + mark + const Offset(5, 2),
        Paint()
          ..color = const Color(0xFF80614A)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawLine(
      point.translate(-43, 3),
      point.translate(0, 27),
      Paint()
        ..color = const Color(0xFFE7B781)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      point.translate(1, 27),
      point.translate(43, 3),
      Paint()
        ..color = const Color(0xFFE1AB75)
        ..strokeWidth = 2,
    );
    for (final corner in [
      point.translate(-45, 0),
      point.translate(45, 0),
      point.translate(0, 23),
    ]) {
      canvas.drawRect(
        Rect.fromLTWH(corner.dx - 3, corner.dy - 3, 6, 15),
        Paint()..color = const Color(0xFFC49260),
      );
      canvas.drawLine(
        corner.translate(-2, -2),
        corner.translate(-2, 10),
        Paint()
          ..color = const Color(0xFFE6B57E)
          ..strokeWidth = 1,
      );
    }
  }

  void _drawPlant(Canvas canvas, Offset point, Plant plant) {
    if (plant.progressSteps == 0 && plant.completedCycles == 0) {
      canvas.drawCircle(point, 4, Paint()..color = const Color(0xFFD9D0B8));
      return;
    }
    final height = switch (plant.stage) {
      PlantStage.graineGermee => 13.0,
      PlantStage.jeunePlant => 29.0,
      PlantStage.presqueMature => 54.0,
      PlantStage.mature => plant.species.zone == ZoneType.verger ? 116.0 : 72.0,
    };
    final produce =
        plant.isReadyToHarvest ||
        (plant.completedCycles > 0 &&
            plant.progressSteps >= plant.targetSteps / 2);
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
    _plantShape(
      canvas,
      point,
      plant.species,
      height,
      produce,
      plant.tier == GrowthTier.brillante,
    );
  }

  void _plantShape(
    Canvas canvas,
    Offset point,
    Species species,
    double height,
    bool produce,
    bool brilliant,
  ) {
    final isTree = species.zone == ZoneType.verger;
    final tip = point.translate(0, -height);
    final stemPaint = Paint();
    stemPaint.color = isTree
        ? const Color(0xFF8A674A)
        : const Color(0xFF52764F);
    stemPaint.strokeWidth = isTree ? 9 : 3;
    stemPaint.strokeCap = StrokeCap.round;
    canvas.drawLine(point, tip, stemPaint);
    final leaf = Paint()..color = const Color(0xFF52764F);
    if (isTree) {
      final radius = height < 70 ? 15.0 : 36.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: tip.translate(0, 20),
          width: radius * 3.1,
          height: radius * 1.7,
        ),
        Paint()..color = const Color(0xFF426D4D),
      );
      canvas.drawCircle(tip.translate(-radius * 0.7, 13), radius, leaf);
      canvas.drawCircle(tip.translate(radius * 0.7, 13), radius, leaf);
      canvas.drawCircle(
        tip.translate(0, -8),
        radius,
        Paint()..color = const Color(0xFF829E70),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: tip.translate(-radius * 0.6, -radius * 0.5),
          width: radius * 0.9,
          height: radius * 0.45,
        ),
        Paint()..color = const Color(0x668FB985),
      );
    } else {
      if (height > 35) {
        final branch = Paint()
          ..color = const Color(0xFF52764F)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          point.translate(0, -height * 0.42),
          point.translate(-17, -height * 0.65),
          branch,
        );
        canvas.drawLine(
          point.translate(0, -height * 0.58),
          point.translate(17, -height * 0.79),
          branch,
        );
        for (final leafCenter in [
          point.translate(-18, -height * 0.67),
          point.translate(18, -height * 0.8),
        ]) {
          canvas.drawOval(
            Rect.fromCenter(center: leafCenter, width: 19, height: 10),
            Paint()..color = const Color(0xFF5D8A51),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: leafCenter.translate(-3, -2),
              width: 8,
              height: 3,
            ),
            Paint()..color = const Color(0xFFA5BF6C),
          );
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: point.translate(-10, -height * 0.42),
            width: 23,
            height: 11,
          ),
          Paint()..color = const Color(0xFF6F985F),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: point.translate(11, -height * 0.57),
            width: 23,
            height: 11,
          ),
          Paint()..color = const Color(0xFF829E70),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(center: tip.translate(-11, 7), width: 24, height: 12),
        leaf,
      );
      canvas.drawOval(
        Rect.fromCenter(center: tip.translate(11, 1), width: 24, height: 12),
        leaf,
      );
      if (species.zone == ZoneType.jardinFleuri && height > 40) {
        switch (species) {
          case Species.tournesol:
            _flower(canvas, tip, const Color(0xFFF0C945), height > 60 ? 14 : 9);
            canvas.drawCircle(tip, 5, Paint()..color = const Color(0xFF765338));
          case Species.tulipe:
            for (final dx in [-7.0, 0.0, 7.0]) {
              canvas.drawOval(
                Rect.fromCenter(
                  center: tip.translate(dx, -3),
                  width: 10,
                  height: 18,
                ),
                Paint()..color = const Color(0xFFE79AAD),
              );
            }
          case Species.lavande:
            for (final dx in [-9.0, 0.0, 9.0]) {
              canvas.drawOval(
                Rect.fromCenter(
                  center: tip.translate(dx, -4),
                  width: 6,
                  height: 19,
                ),
                Paint()..color = const Color(0xFFA695CF),
              );
            }
          default:
            break;
        }
      } else {
        canvas.drawCircle(
          tip,
          height > 50 ? 10 : 5,
          Paint()..color = const Color(0xFF829E70),
        );
        if (height > 50 && species == Species.tomate && !produce) {
          _flower(canvas, tip.translate(-7, 8), const Color(0xFFF2D17B), 3);
        }
      }
    }
    if (produce) {
      if (isTree) {
        for (final fruit in const [
          Offset(-21, 17),
          Offset(14, 21),
          Offset(27, -2),
        ]) {
          canvas.drawCircle(
            tip + fruit,
            6,
            Paint()
              ..color = species == Species.poirier
                  ? const Color(0xFFCFBB5A)
                  : const Color(0xFFD86D50),
          );
        }
      } else if (species == Species.tomate) {
        for (final fruit in const [
          Offset(-11, 15),
          Offset(12, 22),
          Offset(8, -2),
        ]) {
          canvas.drawCircle(
            tip + fruit,
            5,
            Paint()..color = const Color(0xFFD66C50),
          );
        }
      } else if (species == Species.carotte) {
        final root = Path()
          ..moveTo(point.dx - 7, point.dy - 2)
          ..lineTo(point.dx + 7, point.dy - 2)
          ..lineTo(point.dx, point.dy + 14)
          ..close();
        canvas.drawPath(root, Paint()..color = const Color(0xFFE39A51));
      } else if (species == Species.courgette) {
        canvas.drawOval(
          Rect.fromCenter(center: tip.translate(9, 22), width: 20, height: 8),
          Paint()..color = const Color(0xFF527C49),
        );
      }
    }
    if (brilliant) {
      canvas.drawCircle(
        tip.translate(-7, -5),
        3,
        Paint()..color = const Color(0xFFF5EDDA),
      );
    }
  }

  void _grassTuft(Canvas canvas, Offset point) {
    final paint = Paint()
      ..color = const Color(0xFF779F61)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(point, point.translate(-5, -8), paint);
    canvas.drawLine(point, point.translate(0, -11), paint);
    canvas.drawLine(point, point.translate(5, -7), paint);
  }

  void _flower(Canvas canvas, Offset center, Color color, double radius) {
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawCircle(
        center.translate(
          math.cos(angle) * radius * 0.65,
          math.sin(angle) * radius * 0.65,
        ),
        radius * 0.55,
        Paint()..color = color,
      );
    }
    canvas.drawCircle(
      center,
      radius * 0.38,
      Paint()..color = const Color(0xFFE6C65D),
    );
  }

  void _flowerClump(Canvas canvas, Offset point, Color color) {
    final pink =
        color == const Color(0xFFEAB3BA) || color == const Color(0xFFE8B0A8);
    if (_sprites.draw(
      canvas,
      pink
          ? 'fleurs_fleurs_sauvages_roses_ordinaire_00.png'
          : 'commun_fleurs_marguerites_blanches_ordinaire_00.png',
      point.translate(0, 3),
      22,
      21,
    )) {
      return;
    }
    _grassTuft(canvas, point);
    _flower(canvas, point.translate(-5, -9), color, 4);
    _flower(canvas, point.translate(6, -6), color, 3);
  }

  void _wateringCan(Canvas canvas, Offset point) {
    if (_sprites.draw(
      canvas,
      'potager_arrosoir_metal_ordinaire_00.png',
      point.translate(0, 10),
      38,
      31,
    )) {
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(0, 8), width: 34, height: 12),
      Paint()..color = const Color(0x33715D4D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: point, width: 21, height: 18),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF8FA9A2),
    );
    canvas.drawLine(
      point.translate(9, -1),
      point.translate(25, -8),
      Paint()
        ..color = const Color(0xFF78968E)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _nurseryCrate(Canvas canvas, Offset point) {
    if (_sprites.draw(
      canvas,
      'potager_caisse_semis_bois_ordinaire_00.png',
      point.translate(0, 29),
      51,
      39,
    )) {
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(0, 13), width: 56, height: 17),
      Paint()..color = const Color(0x445A7045),
    );
    final side = Path()
      ..moveTo(point.dx - 25, point.dy)
      ..lineTo(point.dx, point.dy + 12)
      ..lineTo(point.dx + 25, point.dy)
      ..lineTo(point.dx + 25, point.dy + 16)
      ..lineTo(point.dx, point.dy + 29)
      ..lineTo(point.dx - 25, point.dy + 16)
      ..close();
    canvas.drawPath(side, Paint()..color = const Color(0xFF986D48));
    _diamond(
      canvas,
      point,
      25,
      12,
      const Color(0xFF694F3B),
      stroke: const Color(0xFFBF9162),
      strokeWidth: 4,
    );
    for (final dx in [-12.0, 0.0, 12.0]) {
      final sprout = point.translate(dx, -4);
      canvas.drawLine(
        sprout,
        sprout.translate(0, -12),
        Paint()
          ..color = const Color(0xFF547A4B)
          ..strokeWidth = 2,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: sprout.translate(-5, -11),
          width: 11,
          height: 6,
        ),
        Paint()..color = const Color(0xFF7CA559),
      );
      canvas.drawOval(
        Rect.fromCenter(center: sprout.translate(5, -12), width: 11, height: 6),
        Paint()..color = const Color(0xFFA0C46B),
      );
    }
  }

  void _birdbath(Canvas canvas, Offset point) {
    if (_sprites.draw(
      canvas,
      'fleurs_bain_oiseaux_pierre_ordinaire_00.png',
      point.translate(0, 5),
      38,
      49,
    )) {
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(0, 6), width: 45, height: 15),
      Paint()..color = const Color(0x445A7045),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: point.translate(0, -8), width: 11, height: 31),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFB4B7A8),
    );
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(0, -25), width: 40, height: 15),
      Paint()..color = const Color(0xFFD7D6C2),
    );
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(0, -27), width: 31, height: 8),
      Paint()..color = const Color(0xFF8DB8B4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: point.translate(7, -29), width: 9, height: 2),
      Paint()..color = const Color(0xFFCFEBDF),
    );
  }

  void _edgeTree(Canvas canvas, Offset foot, int zone) {
    if (_sprites.draw(
      canvas,
      zone == 2
          ? 'verger_arbre_pommier_recoltable_ordinaire_00.png'
          : 'verger_arbre_pommier_adulte_sans_production_ordinaire_00.png',
      foot,
      88,
      91,
    )) {
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: foot.translate(2, 3), width: 69, height: 22),
      Paint()..color = const Color(0x444D6A3F),
    );
    final bark = Paint()
      ..color = const Color(0xFF806344)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(foot, foot.translate(-2, -76), bark);
    bark.strokeWidth = 5;
    canvas.drawLine(foot.translate(-2, -53), foot.translate(-28, -79), bark);
    canvas.drawLine(foot.translate(-2, -57), foot.translate(23, -82), bark);
    for (final crown in const [
      Offset(-29, -86),
      Offset(-12, -104),
      Offset(15, -102),
      Offset(35, -84),
      Offset(10, -77),
      Offset(-19, -68),
    ]) {
      canvas.drawCircle(
        foot + crown,
        crown.dx.abs() > 25 ? 24 : 29,
        Paint()
          ..color = crown.dy < -95
              ? const Color(0xFF87AB59)
              : const Color(0xFF4F7946),
      );
    }
    for (final leaf in const [
      Offset(-45, -88),
      Offset(-36, -104),
      Offset(-21, -117),
      Offset(5, -121),
      Offset(25, -115),
      Offset(45, -91),
      Offset(26, -70),
      Offset(-15, -73),
      Offset(-40, -66),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: foot + leaf, width: 16, height: 9),
        Paint()..color = const Color(0xFFA4C667),
      );
    }
    for (final leaf in const [
      Offset(-51, -78),
      Offset(-43, -113),
      Offset(-33, -121),
      Offset(-19, -97),
      Offset(-8, -128),
      Offset(4, -110),
      Offset(16, -127),
      Offset(31, -105),
      Offset(46, -99),
      Offset(52, -84),
      Offset(34, -66),
      Offset(12, -64),
      Offset(-5, -81),
      Offset(-30, -74),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: foot + leaf, width: 9, height: 5),
        Paint()
          ..color = leaf.dx.isNegative
              ? const Color(0xFFB0CE72)
              : const Color(0xFF6F9D53),
      );
    }
    for (final accent in const [
      Offset(-28, -91),
      Offset(16, -102),
      Offset(31, -81),
    ]) {
      if (zone == 0) {
        _flower(canvas, foot + accent, const Color(0xFFF3E5DB), 5);
      } else if (zone == 2) {
        canvas.drawCircle(
          foot + accent,
          5,
          Paint()..color = const Color(0xFFD66D4F),
        );
      }
    }
  }

  void _shrub(Canvas canvas, Offset point, double radius, int zone) {
    if (_sprites.draw(
      canvas,
      'commun_buisson_haie_ordinaire_00.png',
      point.translate(0, 10),
      radius * 3.0,
      radius * 1.9,
    )) {
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: point.translate(1, 6),
        width: radius * 3.4,
        height: radius * 1.4,
      ),
      Paint()..color = const Color(0x5547683F),
    );
    for (final part in const [
      Offset(-1.1, 0),
      Offset(-0.45, -0.45),
      Offset(0.4, -0.5),
      Offset(1.1, -0.05),
    ]) {
      canvas.drawCircle(
        point.translate(part.dx * radius, part.dy * radius),
        radius * 0.76,
        Paint()
          ..color = part.dx < 0
              ? const Color(0xFF557E4A)
              : const Color(0xFF7BA658),
      );
    }
    for (final highlight in const [
      Offset(-8, -9),
      Offset(8, -12),
      Offset(17, -4),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: point + highlight,
          width: radius * 0.55,
          height: radius * 0.25,
        ),
        Paint()..color = const Color(0xFFA7C76B),
      );
    }
    for (final leaf in const [
      Offset(-19, -5),
      Offset(-14, -15),
      Offset(-5, -18),
      Offset(3, -13),
      Offset(11, -18),
      Offset(18, -8),
      Offset(-3, -4),
      Offset(9, -2),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: point + leaf, width: 8, height: 4),
        Paint()
          ..color = leaf.dx.isNegative
              ? const Color(0xFF9ABC63)
              : const Color(0xFFB4CF76),
      );
    }
    if (zone == 0) {
      _flower(canvas, point.translate(6, -9), const Color(0xFFF4E5DD), 4);
    } else if (zone == 2) {
      canvas.drawCircle(
        point.translate(7, -8),
        3,
        Paint()..color = const Color(0xFFD86E58),
      );
    }
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
