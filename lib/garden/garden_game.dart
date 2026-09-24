import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'garden_scene.dart';
import 'garden_scene_renderer.dart';
import 'garden_state.dart';
import 'garden_sprites.dart';
import 'potager_composition.dart';
import 'landscape_mass.dart';
import 'potager_path.dart';
import 'potager_scene.dart';

/// Isometric grid engine: every scene position derives from the 80×40 rhombus
/// lattice with axes u = (40, 20) and v = (-40, 20). Origin is the grid center.
class IsoGrid {
  const IsoGrid(this.origin);

  /// Screen center of the grid.
  final Offset origin;

  /// Lattice (i, j) → screen coordinates. Integer = cell center, half-integer
  /// = edge midpoint, the only positions allowed for anchors and path nodes.
  Offset toScreen(double i, double j) =>
      Offset(origin.dx + (i - j) * 40, origin.dy + (i + j) * 20);

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
class _SceneObject extends GardenPlacedObject {
  _SceneObject(Offset contact, this.draw, {String id = '', double zBias = 0})
    : super(id, contact, zBias: zBias);

  final void Function(Canvas canvas) draw;
}

enum _TerrainTileVariant { grain, blades, clover, highlight }

class _TerrainTile {
  const _TerrainTile(this.center, this.variant, this.scale);

  final Offset center;
  final _TerrainTileVariant variant;
  final double scale;
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
  static const double referenceWidth = GardenArtboardTransform.width;
  static const double referenceHeight = GardenArtboardTransform.height;
  static const double touchSize = 44;
  static const double sceneScale = GardenArtboardTransform.fixedScale;
  static const double earthThickness = 24;
  static const bool _debugComposition =
      !kReleaseMode && bool.fromEnvironment('GROWSTEP_MAP_DEBUG');

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
    Offset(115, 330), // 1 front-left, on the half-cell lattice
    Offset(275, 330), // 2 front-right, on the half-cell lattice
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
    final scenePoint = _artboardTransform.toArtboard(localPosition);
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

  GardenArtboardTransform get _artboardTransform =>
      GardenArtboardTransform(Size(size.x, size.y));

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
    _artboardTransform.apply(canvas);
    _drawIsland(canvas, currentZone);
    canvas.restore();
  }

  // ─── Island rendering ──────────────────────────────────────────────────

  void _drawIsland(Canvas canvas, ZoneType zone) {
    // Collect ALL scene objects for proper depth sorting.
    final objects = <_SceneObject>[];

    // Terrain (drawn first, unsorted).
    _drawTerrain(canvas, zone);
    if (zone == ZoneType.potager) {
      PotagerComposition.drawGround(canvas, _islandContour(zone));
      PotagerPath.draw(canvas);
    }

    // Environment objects.
    for (final entry in _environmentObjects(zone)) {
      objects.add(entry);
    }

    // Slot objects (beds + plants).
    final anchors = anchorsFor(zone);
    final purchased = snapshot.zones[zone]!;
    for (var slot = 0; slot < purchased.length; slot++) {
      final point = anchors[slot];
      if (zone == ZoneType.potager) {
        final bed = PotagerBeds.beds[slot];
        objects.add(
          _SceneObject(
            point,
            (c) {
              if (!GardenSceneRenderer.drawSprite(c, bed, _sprites)) {
                _drawBed(c, point, zone);
              }
            },
            id: bed.id,
          ),
        );
      } else {
        objects.add(_SceneObject(point, (c) => _drawBed(c, point, zone)));
      }
      if (purchased[slot] != null) {
        objects.add(
          _SceneObject(
            point.translate(0, 0.1),
            (c) => _drawPlant(c, point, purchased[slot]!),
          ),
        );
      }
      if (zone == currentZone && selectedSlot == slot) {
        objects.add(
          _SceneObject(
            point.translate(0, 1),
            (c) => _drawSelection(c, point, zone),
          ),
        );
      }
    }

    // Depth sort by ground-contact Y.
    for (final obj in GardenSceneRenderer.depthOrder(objects)) {
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
    if (_debugComposition && zone == ZoneType.potager) {
      _drawCompositionDebug(canvas, anchors, purchased.length);
    }
  }

  void _drawCompositionDebug(Canvas canvas, List<Offset> anchors, int count) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, referenceWidth, referenceHeight),
      Paint()
        ..color = const Color(0xFFAE5A37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var index = 0; index < count; index++) {
      canvas.drawRect(
        Rect.fromCenter(
          center: anchors[index],
          width: touchSize,
          height: touchSize,
        ),
        Paint()
          ..color = const Color(0xFFAE5A37)
          ..style = PaintingStyle.stroke,
      );
    }
    for (final object in PotagerPilotScene.objects) {
      canvas.drawCircle(
        object.contact,
        3,
        Paint()..color = const Color(0xFFAE5A37),
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${object.id} · ${object.layer.name} · ${object.depth}',
          style: const TextStyle(fontSize: 9, color: Color(0xFF482A1D)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelOrigin = object.contact.translate(-label.width, 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            labelOrigin.dx - 2,
            labelOrigin.dy - 1,
            label.width + 4,
            label.height + 2,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xDDFBF8E9),
      );
      label.paint(canvas, labelOrigin);
    }
  }

  // ─── Terrain ───────────────────────────────────────────────────────────

  Path _islandContour(ZoneType zone) {
    final points = switch (zone) {
      ZoneType.potager => const <Offset>[
        Offset(24, 205),
        Offset(42, 118),
        Offset(116, 78),
        Offset(200, 68),
        Offset(284, 78),
        Offset(358, 118),
        Offset(376, 205),
        Offset(366, 300),
        Offset(330, 374),
        Offset(248, 410),
        Offset(142, 410),
        Offset(60, 374),
        Offset(24, 300),
      ],
      ZoneType.jardinFleuri => const <Offset>[
        Offset(22, 210),
        Offset(52, 112),
        Offset(136, 73),
        Offset(200, 64),
        Offset(264, 73),
        Offset(348, 112),
        Offset(378, 210),
        Offset(366, 306),
        Offset(324, 380),
        Offset(242, 416),
        Offset(158, 416),
        Offset(66, 380),
        Offset(34, 306),
      ],
      ZoneType.verger => const <Offset>[
        Offset(32, 240),
        Offset(84, 126),
        Offset(195, 88),
        Offset(306, 126),
        Offset(358, 240),
        Offset(332, 334),
        Offset(256, 405),
        Offset(134, 405),
        Offset(58, 334),
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

    // Sparse strata and grains make the exposed slice read as cut earth.
    final bounds = earth.getBounds();
    canvas.save();
    canvas.clipPath(earth);
    final earthRng = math.Random(710 + zone.index);
    for (var band = 0; band < 3; band++) {
      final y = bounds.bottom - 7 - band * 7.0;
      final strata = Path()..moveTo(bounds.left - 8, y);
      for (var step = 0; step < 8; step++) {
        final x = bounds.left - 8 + step * bounds.width / 7;
        strata.quadraticBezierTo(
          x + bounds.width / 28,
          y + (step.isEven ? 1.8 : -1.2),
          x + bounds.width / 14,
          y,
        );
      }
      canvas.drawPath(
        strata,
        Paint()
          ..color = band == 0
              ? const Color(0x3E674A35)
              : const Color(0x263F3028)
          ..style = PaintingStyle.stroke
          ..strokeWidth = band == 0 ? 2 : 1,
      );
    }
    for (var i = 0; i < 145; i++) {
      final x = bounds.left + earthRng.nextDouble() * bounds.width;
      final y = bounds.top + earthRng.nextDouble() * bounds.height;
      final length = 2.0 + earthRng.nextDouble() * 10;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + length, y + length * 0.12),
        Paint()
          ..color = i.isEven ? const Color(0x3960402D) : const Color(0x3ACDA47A)
          ..strokeWidth = i % 5 == 0 ? 1.5 : 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < 95; i++) {
      final x = bounds.left + earthRng.nextDouble() * bounds.width;
      final y = bounds.top + earthRng.nextDouble() * bounds.height;
      canvas.drawCircle(
        Offset(x, y),
        0.4 + earthRng.nextDouble() * 1.1,
        Paint()..color = const Color(0x4DD3B08A),
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

    // Irregular, low-contrast grass patches avoid a visible cell pattern.
    canvas.save();
    canvas.clipPath(contour);
    final rng = math.Random(42 + zone.index);
    _drawGrassTextureTiles(canvas, zone, contour.getBounds());
    for (var i = 0; i < 120; i++) {
      final x = bounds.left + rng.nextDouble() * bounds.width;
      final y = bounds.top + rng.nextDouble() * bounds.height;
      final r = 3.0 + rng.nextDouble() * 9;
      final patch = Path()
        ..moveTo(x - r, y)
        ..quadraticBezierTo(x - r * 0.7, y - r * 0.5, x, y - r * 0.35)
        ..quadraticBezierTo(x + r * 0.8, y - r * 0.4, x + r, y)
        ..quadraticBezierTo(x + r * 0.4, y + r * 0.5, x - r * 0.5, y + r * 0.3)
        ..close();
      canvas.drawPath(
        patch,
        Paint()
          ..color = Color.fromRGBO(
            130 + rng.nextInt(40),
            160 + rng.nextInt(40),
            80 + rng.nextInt(30),
            0.10 + rng.nextDouble() * 0.09,
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
        Paint()..color = const Color(0x20D1E294),
      );
    }
    // A fine, irregular grain gives the grass a painted fiber rather than a
    // flat fill. The marks stay short so the planting contacts remain clear.
    final bladeRng = math.Random(901 + zone.index);
    for (var i = 0; i < 115; i++) {
      final x = bounds.left + 18 + bladeRng.nextDouble() * (bounds.width - 36);
      final y = bounds.top + 22 + bladeRng.nextDouble() * (bounds.height - 54);
      final bladePaint = Paint()
        ..color = i.isEven ? const Color(0x5273974E) : const Color(0x42618147)
        ..strokeWidth = i % 5 == 0 ? 1.3 : 0.8
        ..strokeCap = StrokeCap.round;
      final lean = (bladeRng.nextDouble() - 0.5) * 3.5;
      final length = 2.5 + bladeRng.nextDouble() * 3.5;
      canvas.drawLine(Offset(x, y), Offset(x + lean, y - length), bladePaint);
      if (i % 4 == 0) {
        canvas.drawLine(
          Offset(x + 1, y),
          Offset(x - lean * 0.4, y - length * 0.72),
          bladePaint,
        );
      }
    }
    canvas.restore();

    // A fine grassy lip keeps the earth and top surface connected.
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

  List<_TerrainTile> _terrainTiles(ZoneType zone, Rect bounds) {
    final rng = math.Random(1200 + zone.index);
    final tiles = <_TerrainTile>[];
    for (var y = bounds.top + 18; y < bounds.bottom - 20; y += 26) {
      for (var x = bounds.left + 18; x < bounds.right - 18; x += 28) {
        final center = Offset(
          x + (rng.nextDouble() - 0.5) * 13,
          y + (rng.nextDouble() - 0.5) * 11,
        );
        final variant = _TerrainTileVariant.values[rng.nextInt(4)];
        tiles.add(
          _TerrainTile(center, variant, 0.75 + rng.nextDouble() * 0.55),
        );
      }
    }
    return tiles;
  }

  void _drawGrassTextureTiles(Canvas canvas, ZoneType zone, Rect bounds) {
    for (final tile in _terrainTiles(zone, bounds)) {
      canvas.save();
      canvas.translate(tile.center.dx, tile.center.dy);
      canvas.scale(tile.scale);
      final dark = Paint()
        ..color = const Color(0x4B5F8546)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      final light = Paint()
        ..color = const Color(0x4DABC86B)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      switch (tile.variant) {
        case _TerrainTileVariant.grain:
          canvas.drawCircle(const Offset(-2, 1), 1.1, dark);
          canvas.drawCircle(const Offset(2, -1), 0.8, light);
          canvas.drawLine(const Offset(-5, 4), const Offset(-2, 2), dark);
          canvas.drawLine(const Offset(2, 4), const Offset(5, 2), light);
        case _TerrainTileVariant.blades:
          canvas.drawLine(const Offset(-3, 4), const Offset(-4, -3), dark);
          canvas.drawLine(const Offset(0, 4), const Offset(1, -5), light);
          canvas.drawLine(const Offset(3, 4), const Offset(5, -2), dark);
        case _TerrainTileVariant.clover:
          for (final offset in const [
            Offset(-2, 0),
            Offset(2, 0),
            Offset(0, -2),
            Offset(0, 2),
          ]) {
            canvas.drawCircle(offset, 1.5, light);
          }
          canvas.drawCircle(Offset.zero, 0.8, dark);
        case _TerrainTileVariant.highlight:
          canvas.drawOval(
            const Rect.fromLTWH(-6, -2, 12, 4),
            Paint()..color = const Color(0x246E9B4B),
          );
          canvas.drawLine(const Offset(-4, 0), const Offset(3, -1), light);
      }
      canvas.restore();
    }
  }

  // ─── Environment objects ───────────────────────────────────────────────

  List<_SceneObject> _environmentObjects(ZoneType zone) {
    if (zone == ZoneType.potager) {
      return [
        for (final object in PotagerPilotScene.objects)
          _SceneObject(object.contact, (canvas) {
            if (!GardenSceneRenderer.drawSprite(canvas, object, _sprites)) {
              if (identical(object, PotagerPilotScene.rock)) {
                LandscapeMassPainter.drawRock(
                  canvas,
                  LandscapeRock(object.contact, object.size.height),
                );
              } else {
                PotagerComposition.drawBarrel(canvas);
              }
            }
          }, id: object.id, zBias: object.zBias),
        for (final mass in PotagerComposition.masses) ...[
          for (final shrub in mass.shrubs)
            _SceneObject(shrub.anchor, (canvas) {
              final upright = shrub.anchor.dy >= 170;
              final sprite = upright
                  ? 'commun_decor_bosquet_haut_statique_ordinaire_00.png'
                  : 'commun_decor_bosquet_bas_statique_ordinaire_00.png';
              if (!_sprites.draw(
                canvas,
                sprite,
                shrub.anchor,
                shrub.radius * (upright ? 2.5 : 2.8),
                shrub.radius * (upright ? 1.75 : 1.4),
                opacity: 0.9,
              )) {
                LandscapeMassPainter.drawShrub(canvas, shrub);
              }
            }),
          for (final rock in mass.rocks)
            _SceneObject(rock.anchor, (canvas) {
              if (!_sprites.draw(
                canvas,
                'commun_decor_rochers_herbe_statique_ordinaire_00.png',
                rock.anchor,
                rock.width * 1.8,
                rock.width * 1.0,
                opacity: 0.82,
              )) {
                LandscapeMassPainter.drawRock(canvas, rock);
              }
            }),
        ],
        for (final point in PotagerComposition.rimGrass)
          _SceneObject(point, (canvas) {
            if (!_sprites.draw(
              canvas,
              'commun_decor_bosquet_bas_statique_ordinaire_00.png',
              point,
              29,
              13,
              opacity: 0.8,
            )) {
              PotagerComposition.drawRimGrass(canvas, point);
            }
          }),
        _SceneObject(PotagerComposition.trellisAnchor, (canvas) {
          if (!_sprites.draw(
            canvas,
            'commun_decor_treillis_bois_statique_ordinaire_00.png',
            PotagerComposition.trellisAnchor,
            58,
            51,
            opacity: 0.86,
          )) {
            PotagerComposition.drawTrellis(canvas);
          }
        }),
        _SceneObject(PotagerComposition.wateringCanAnchor, (canvas) {
          if (!_sprites.draw(
            canvas,
            'potager_decor_arrosoir_metal_statique_ordinaire_00.png',
            PotagerComposition.wateringCanAnchor,
            26,
            22,
            opacity: 0.86,
          )) {
            _drawWateringCan(canvas, PotagerComposition.wateringCanAnchor);
          }
        }),
        _SceneObject(PotagerComposition.nurseryCrateAnchor, (canvas) {
          if (!_sprites.draw(
            canvas,
            'potager_decor_caisse_semis_statique_ordinaire_00.png',
            PotagerComposition.nurseryCrateAnchor,
            30,
            23,
            opacity: 0.82,
          )) {
            _drawNurseryCrate(canvas, PotagerComposition.nurseryCrateAnchor);
          }
        }),
      ];
    }

    final objects = <_SceneObject>[];

    // The high planting stays behind the interactive contacts.
    final borderShrubs = zone == ZoneType.verger
        ? const [
            Offset(122, 159),
            Offset(268, 159),
            Offset(62, 249),
            Offset(328, 249),
          ]
        : const [
            Offset(103, 130),
            Offset(145, 113),
            Offset(195, 102),
            Offset(245, 113),
            Offset(287, 130),
            Offset(51, 247),
            Offset(339, 247),
          ];
    for (final bush in borderShrubs) {
      objects.add(
        _SceneObject(
          bush.translate(0, 6),
          (c) => _drawShrub(c, bush, zone == ZoneType.verger ? 16 : 18, zone),
        ),
      );
    }

    // Front border hedge.
    for (final point in const [
      Offset(62, 354),
      Offset(112, 380),
      Offset(278, 380),
      Offset(328, 354),
    ]) {
      objects.add(
        _SceneObject(
          point.translate(0, 4),
          (c) => _drawShrub(c, point, 8, zone),
        ),
      );
    }

    // Grass tufts.
    for (final tuft in const [
      Offset(60, 178),
      Offset(330, 172),
      Offset(48, 298),
      Offset(342, 296),
      Offset(120, 386),
      Offset(270, 388),
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
      Offset(53, 212),
      Offset(337, 216),
      Offset(66, 336),
      Offset(327, 340),
      if (zone != ZoneType.potager) Offset(195, 390),
      if (zone == ZoneType.potager) Offset(235, 390),
    ]) {
      objects.add(
        _SceneObject(
          bloom.translate(0, 3),
          (c) => _drawFlowerClump(c, bloom, accent),
        ),
      );
    }

    // Zone-specific accessories.
    if (zone == ZoneType.jardinFleuri) {
      objects.add(
        _SceneObject(
          const Offset(330, 175).translate(0, 4),
          (c) => _drawBirdbath(c, const Offset(330, 175)),
        ),
      );
    }

    // Verger bench.
    if (zone == ZoneType.verger) {
      objects.add(
        _SceneObject(
          const Offset(195, 392),
          (c) => _drawBench(c, const Offset(195, 392)),
        ),
      );
    }

    return objects;
  }

  // ─── Beds ──────────────────────────────────────────────────────────────

  void _drawBed(Canvas canvas, Offset point, ZoneType zone) {
    if (zone == ZoneType.verger) {
      _drawTreeBase(canvas, point);
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
    final embedded =
        zone == ZoneType.potager &&
        PotagerComposition.embeddedBeds.contains(point);
    final fh = zone == ZoneType.potager ? (embedded ? 4.0 : 10.0) : 13.0;

    // Front-left face (darker, shadowed).
    final leftFace = Path()
      ..moveTo(point.dx - w, point.dy)
      ..lineTo(point.dx, point.dy + h)
      ..lineTo(point.dx, point.dy + h + fh)
      ..lineTo(point.dx - w, point.dy + fh)
      ..close();
    canvas.drawPath(
      leftFace,
      Paint()
        ..color = zone == ZoneType.potager
            ? (embedded ? const Color(0xFF687D4E) : const Color(0xFF927650))
            : const Color(0xFF8B6845),
    );

    // Front-right face (warmer, lit).
    final rightFace = Path()
      ..moveTo(point.dx, point.dy + h)
      ..lineTo(point.dx + w, point.dy)
      ..lineTo(point.dx + w, point.dy + fh)
      ..lineTo(point.dx, point.dy + h + fh)
      ..close();
    canvas.drawPath(
      rightFace,
      Paint()
        ..color = zone == ZoneType.potager
            ? (embedded ? const Color(0xFF82935D) : const Color(0xFFAD8C61))
            : const Color(0xFFB08258),
    );
    for (final (start, end) in [
      (point.translate(-33, 5), point.translate(-9, 18)),
      (point.translate(-21, 11), point.translate(-3, 20)),
      (point.translate(7, 20), point.translate(32, 6)),
      (point.translate(14, 25), point.translate(36, 12)),
    ]) {
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0x43805C3C)
          ..strokeWidth = 0.7,
      );
    }

    // Wood top rim — warm honey gradient.
    final topRim = embedded
        ? PotagerComposition.embeddedRim(point)
        : (Path()
            ..moveTo(point.dx, point.dy - h)
            ..lineTo(point.dx + w, point.dy)
            ..lineTo(point.dx, point.dy + h)
            ..lineTo(point.dx - w, point.dy)
            ..close());
    canvas.drawPath(
      topRim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: zone == ZoneType.potager
              ? (embedded
                    ? const [Color(0xFFA4AE75), Color(0xFF84965F)]
                    : const [Color(0xFFC7AF7C), Color(0xFFAE9369)])
              : const [Color(0xFFD9A86A), Color(0xFFC4905A)],
        ).createShader(topRim.getBounds()),
    );

    // Soil interior — dark, rich brown.
    const soilInset = 3.0;
    final soil = embedded
        ? PotagerComposition.embeddedSoil(point)
        : (Path()
            ..moveTo(point.dx, point.dy - h + soilInset)
            ..lineTo(point.dx + w - soilInset, point.dy)
            ..lineTo(point.dx, point.dy + h - soilInset)
            ..lineTo(point.dx - w + soilInset, point.dy)
            ..close());
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
    for (var i = 0; i < 17; i++) {
      final dx = (rng.nextDouble() - 0.5) * (w * 1.3);
      final dy = (rng.nextDouble() - 0.3) * (h * 1.2);
      final center = point.translate(dx, dy);
      final grain = 1.1 + rng.nextDouble() * 2.4;
      canvas.drawOval(
        Rect.fromCenter(center: center, width: grain * 1.8, height: grain),
        Paint()
          ..color = i.isEven
              ? const Color(0x6650382A)
              : const Color(0x557C5A40),
      );
    }
    canvas.restore();

    // Corner posts — small vertical pegs at the bed corners.
    for (final corner in [
      point.translate(-w, 0),
      point.translate(w, 0),
      point.translate(0, h),
    ]) {
      if (embedded) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: corner.translate(0, 1), width: 6, height: 10),
          const Radius.circular(2),
        ),
        Paint()
          ..color = zone == ZoneType.potager
              ? const Color(0xFFB39A6B)
              : const Color(0xFFC49260),
      );
      canvas.drawLine(
        corner.translate(-1, 0),
        corner.translate(-1, 8),
        Paint()
          ..color = zone == ZoneType.potager
              ? const Color(0xFFD9BD8C)
              : const Color(0xFFE6B57E)
          ..strokeWidth = 1,
      );
    }

    // Wood plank edge highlights.
    if (!embedded) {
      canvas.drawLine(
        point.translate(-w + 2, 1),
        point.translate(0, h + 1),
        Paint()
          ..color = zone == ZoneType.potager
              ? const Color(0xFFD2B889)
              : const Color(0xFFE7B781)
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        point.translate(1, h + 1),
        point.translate(w - 2, 1),
        Paint()
          ..color = zone == ZoneType.potager
              ? const Color(0xFFC9AA7D)
              : const Color(0xFFE1AB75)
          ..strokeWidth = 1.5,
      );
    }
    if (zone == ZoneType.potager) {
      PotagerComposition.drawBedOvergrowth(canvas, point);
    }
  }

  void _drawTreeBase(Canvas canvas, Offset point) {
    final patch = Path()
      ..moveTo(point.dx - 33, point.dy + 3)
      ..quadraticBezierTo(
        point.dx - 26,
        point.dy - 14,
        point.dx - 6,
        point.dy - 14,
      )
      ..quadraticBezierTo(
        point.dx + 20,
        point.dy - 16,
        point.dx + 34,
        point.dy + 2,
      )
      ..quadraticBezierTo(
        point.dx + 13,
        point.dy + 15,
        point.dx - 10,
        point.dy + 13,
      )
      ..close();
    canvas.drawPath(patch, Paint()..color = const Color(0x6682A962));
    canvas.drawOval(
      Rect.fromCenter(center: point, width: 16, height: 7),
      Paint()..color = const Color(0x996C503C),
    );
    for (final dx in [-26.0, -17.0, 19.0, 28.0]) {
      _drawGrassTuft(canvas, point.translate(dx, 2));
    }
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
    final produce =
        plant.isReadyToHarvest ||
        (plant.completedCycles > 0 &&
            plant.progressSteps >= plant.targetSteps / 2);
    final spriteStage = switch (plant.stage) {
      PlantStage.graineGermee || PlantStage.jeunePlant => 'jeune',
      PlantStage.presqueMature => 'adulte_sans_production',
      PlantStage.mature => produce ? 'recoltable' : 'adulte_sans_production',
    };
    final spriteName = '${spritePrefix}_${spriteStage}_ordinaire_00.png';
    final spriteSize = _sprites.visibleSize(spriteName);
    final reusedStageScale = switch (plant.stage) {
      PlantStage.graineGermee => 0.63,
      PlantStage.presqueMature => 0.83,
      PlantStage.jeunePlant || PlantStage.mature => 1.0,
    };
    if (spriteSize != null &&
        _sprites.draw(
          canvas,
          spriteName,
          point,
          spriteSize.width * reusedStageScale,
          spriteSize.height * reusedStageScale,
        )) {
      if (plant.tier == GrowthTier.brillante) {
        _drawBrilliantOverlay(
          canvas,
          point,
          plant.species,
          spriteSize * reusedStageScale,
        );
      }
      return;
    }
    _drawPlantShape(canvas, point, plant, produce);
  }

  void _drawBrilliantOverlay(
    Canvas canvas,
    Offset foot,
    Species species,
    Size size,
  ) {
    final marks = switch (species) {
      Species.tomate => const [Offset(-0.21, -0.48), Offset(0.18, -0.62)],
      Species.carotte => const [Offset(-0.30, -0.58), Offset(0.13, -0.73)],
      Species.courgette => const [Offset(-0.23, -0.37), Offset(0.25, -0.62)],
      Species.tournesol => const [Offset(-0.12, -0.84), Offset(0.20, -0.56)],
      Species.tulipe => const [Offset(-0.26, -0.77), Offset(0.18, -0.70)],
      Species.lavande => const [Offset(-0.28, -0.55), Offset(0.22, -0.81)],
      Species.pommier => const [Offset(-0.30, -0.72), Offset(0.20, -0.52)],
      Species.poirier => const [Offset(-0.16, -0.83), Offset(0.28, -0.62)],
    };
    final accent = switch (species) {
      Species.tomate || Species.pommier => const Color(0xFFF4D99B),
      Species.carotte ||
      Species.courgette ||
      Species.poirier => const Color(0xFFDFE5A6),
      Species.tournesol => const Color(0xFFFFEDAD),
      Species.tulipe => const Color(0xFFF8D4DE),
      Species.lavande => const Color(0xFFE4DAF2),
    };
    for (final (index, mark) in marks.indexed) {
      final center = foot.translate(
        mark.dx * size.width,
        mark.dy * size.height,
      );
      final leaf = Path()
        ..moveTo(center.dx - 4, center.dy + 1)
        ..quadraticBezierTo(
          center.dx - 1,
          center.dy - 3 - index,
          center.dx + 4,
          center.dy - 2,
        )
        ..quadraticBezierTo(
          center.dx + 1,
          center.dy + 2,
          center.dx - 4,
          center.dy + 1,
        )
        ..close();
      canvas.drawPath(leaf, Paint()..color = accent.withValues(alpha: 0.88));
      canvas.drawLine(
        center.translate(-2, 0),
        center.translate(2, -1),
        Paint()
          ..color = const Color(0xB5FFF8E9)
          ..strokeWidth = 0.8,
      );
      final ink = Paint()
        ..color = const Color(0xEFFFFCF0)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      switch (species) {
        case Species.tomate:
          canvas.drawLine(center.translate(0, -4), center.translate(0, 3), ink);
          canvas.drawLine(
            center.translate(-3, -1),
            center.translate(3, 0),
            ink,
          );
          break;
        case Species.carotte:
          for (var row = 0; row < 2; row++) {
            final y = row * 3.0 - 3;
            canvas.drawLine(
              center.translate(-3, y),
              center.translate(0, y + 2),
              ink,
            );
            canvas.drawLine(
              center.translate(0, y + 2),
              center.translate(3, y),
              ink,
            );
          }
          break;
        case Species.courgette:
          for (var stripe = -1; stripe <= 1; stripe++) {
            canvas.drawLine(
              center.translate(stripe * 2.0 - 1, -3),
              center.translate(stripe * 2.0 + 1, 2),
              ink,
            );
          }
          break;
        case Species.tournesol:
          for (var dot = 0; dot < 5; dot++) {
            final angle = dot * math.pi * 2 / 5;
            canvas.drawCircle(
              center.translate(math.cos(angle) * 3, math.sin(angle) * 3),
              0.8,
              Paint()..color = const Color(0xFFFFFCF0),
            );
          }
          break;
        case Species.tulipe:
          canvas.drawLine(
            center.translate(-3, -3),
            center.translate(0, 2),
            ink,
          );
          canvas.drawLine(center.translate(0, 2), center.translate(3, -3), ink);
          break;
        case Species.lavande:
          for (var dot = -1; dot <= 1; dot++) {
            canvas.drawCircle(
              center.translate(dot * 2.0, -dot * 2.0),
              1.1,
              Paint()..color = const Color(0xFFFFFCF0),
            );
          }
          break;
        case Species.pommier:
          final diamond = Path()
            ..moveTo(center.dx, center.dy - 5)
            ..lineTo(center.dx + 4, center.dy)
            ..lineTo(center.dx, center.dy + 5)
            ..lineTo(center.dx - 4, center.dy)
            ..close();
          canvas.drawPath(diamond, ink);
          break;
        case Species.poirier:
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: 4),
            -math.pi * 0.8,
            math.pi * 1.2,
            false,
            ink,
          );
          break;
      }
    }
    _brilliantSparkle(
      canvas,
      foot.translate(
        marks.first.dx * size.width - 3,
        marks.first.dy * size.height - 3,
      ),
    );
    if (species.zone == ZoneType.verger) {
      _brilliantSparkle(
        canvas,
        foot.translate(
          marks.last.dx * size.width + 4,
          marks.last.dy * size.height - 4,
        ),
      );
    }
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

  void _drawTomate(
    Canvas c,
    Offset p,
    PlantStage stage,
    bool produce,
    bool brilliant,
  ) {
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
        Rect.fromCenter(
          center: p.translate(-14, -h * 0.45),
          width: 10,
          height: 5,
        ),
        Paint()..color = const Color(0x55A5C46B),
      );
      c.drawOval(
        Rect.fromCenter(
          center: p.translate(10, -h * 0.82),
          width: 8,
          height: 4,
        ),
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
        c.drawCircle(
          fruit.translate(-1.5, -1.5),
          2,
          Paint()..color = const Color(0xFFE08A70),
        );
      }
    }
    if (brilliant) {
      _brilliantSparkle(c, p.translate(-8, -h * 0.8));
    }
  }

  void _drawCarotte(
    Canvas c,
    Offset p,
    PlantStage stage,
    bool produce,
    bool brilliant,
  ) {
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
      _stem(
        c,
        p.translate(dx * 0.3, 0),
        h * (1 - dx.abs() * 0.02),
        const Color(0xFF52764F),
        2,
      );
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

  void _drawCourgette(
    Canvas c,
    Offset p,
    PlantStage stage,
    bool produce,
    bool brilliant,
  ) {
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
          Rect.fromCenter(
            center: center.translate(-2, -1),
            width: w * 0.5,
            height: hh * 0.4,
          ),
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
        Rect.fromCenter(
          center: p.translate(8, -h * 0.2 - 1),
          width: 12,
          height: 4,
        ),
        Paint()..color = const Color(0xFF6B9A55),
      );
    }
    if (brilliant) {
      _brilliantSparkle(c, p.translate(-6, -h * 0.7));
    }
  }

  // ─── Flower plants ─────────────────────────────────────────────────────

  void _drawTournesol(
    Canvas c,
    Offset p,
    PlantStage stage,
    bool produce,
    bool brilliant,
  ) {
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
        Rect.fromCenter(
          center: p.translate(-10, -h * 0.35),
          width: 16,
          height: 8,
        ),
        Paint()..color = const Color(0xFF5D8A51),
      );
      c.drawOval(
        Rect.fromCenter(
          center: p.translate(10, -h * 0.55),
          width: 16,
          height: 8,
        ),
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
          head.translate(
            math.cos(angle) * petalR * 0.7,
            math.sin(angle) * petalR * 0.7,
          ),
          petalR * 0.5,
          Paint()..color = const Color(0xFFF0C945),
        );
      }
      c.drawCircle(
        head,
        petalR * 0.45,
        Paint()..color = const Color(0xFF765338),
      );
      c.drawCircle(
        head.translate(-1, -1),
        petalR * 0.25,
        Paint()..color = const Color(0xFF9A6B45),
      );
    }
    if (brilliant) {
      _brilliantSparkle(c, p.translate(0, -h * 0.8));
    }
  }

  void _drawTulipe(
    Canvas c,
    Offset p,
    PlantStage stage,
    bool produce,
    bool brilliant,
  ) {
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
      _stem(
        c,
        p.translate(dx * 0.5, 0),
        h * (1 - dx.abs() * 0.01),
        const Color(0xFF52764F),
        2,
      );
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

  void _drawLavande(
    Canvas c,
    Offset p,
    PlantStage stage,
    bool produce,
    bool brilliant,
  ) {
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
      _stem(
        c,
        p.translate(dx * 0.4, 0),
        h * (1 - dx.abs() * 0.02),
        const Color(0xFF52764F),
        1.5,
      );
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

  void _drawTreeCanopy(
    Canvas c,
    Offset p,
    Species species,
    PlantStage stage,
    bool produce,
    bool brilliant,
  ) {
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
      c.drawLine(
        p.translate(-12, -h * 0.68),
        p.translate(-24, -h * 0.85),
        bark,
      );
      c.drawLine(p.translate(10, -h * 0.72), p.translate(22, -h * 0.88), bark);
    }
    // Crown — layered masses for depth.
    final tip = p.translate(0, -h);
    final crownR = h < 50
        ? 14.0
        : h < 80
        ? 26.0
        : 34.0;
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
      c.drawCircle(
        mass,
        crownR * 0.85,
        Paint()..color = const Color(0xFF4F7946),
      );
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
          center: tip.translate(
            math.cos(angle) * dist,
            math.sin(angle) * dist * 0.6 - 4,
          ),
          width: 8,
          height: 5,
        ),
        Paint()
          ..color = rng.nextBool()
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
        c.drawCircle(
          fruit.translate(-1.5, -1.5),
          2,
          Paint()..color = fruitHighlight,
        );
      }
    }
    if (brilliant) {
      _brilliantSparkle(c, tip.translate(-crownR * 0.3, -crownR * 0.3));
    }
  }

  // ─── Environment rendering ─────────────────────────────────────────────

  void _drawShrub(Canvas c, Offset point, double radius, ZoneType zone) {
    c.drawOval(
      Rect.fromCenter(
        center: point.translate(2, 4),
        width: radius * 2.7,
        height: radius * 0.8,
      ),
      Paint()
        ..color = const Color(0x28526941)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    final rng = math.Random(
      point.dx.round() * 47 + point.dy.round() * 11 + zone.index,
    );
    // Small overlapping leaves make a hedge silhouette without a smooth,
    // stone-like body. The uneven dark core is mostly hidden by foliage.
    for (var i = 0; i < 7; i++) {
      final x = point.dx + (i - 3) * radius * 0.29;
      final y = point.dy - radius * (0.36 + (i % 3) * 0.13);
      c.drawCircle(
        Offset(x, y),
        radius * (i.isEven ? 0.46 : 0.39),
        Paint()..color = const Color(0xFF4B7245),
      );
    }
    final leafCount = radius > 12 ? 150 : 46;
    const shades = [
      Color(0xFF456F43),
      Color(0xFF5B864E),
      Color(0xFF709A56),
      Color(0xFF89AD62),
      Color(0xFFA6C477),
    ];
    for (var i = 0; i < leafCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final distance = math.sqrt(rng.nextDouble());
      final x = point.dx + math.cos(angle) * distance * radius * 1.12;
      final y =
          point.dy - radius * 0.55 + math.sin(angle) * distance * radius * 0.73;
      final w = (radius > 12 ? 3.2 : 2.1) + rng.nextDouble() * 2.4;
      c.save();
      c.translate(x, y);
      c.rotate((rng.nextDouble() - 0.5) * 2.0);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 1.7, height: w * 0.85),
        Paint()
          ..color =
              shades[(rng.nextInt(4) + (y < point.dy - radius ? 1 : 0)).clamp(
                0,
                4,
              )],
      );
      c.restore();
    }
    // Zone accent flower.
    if (zone == ZoneType.jardinFleuri) {
      _drawSmallFlower(
        c,
        point.translate(radius * 0.3, -radius * 0.4),
        const Color(0xFFE8B0A8),
        3,
      );
    } else if (zone == ZoneType.verger) {
      c.drawCircle(
        point.translate(radius * 0.3, -radius * 0.4),
        2.5,
        Paint()..color = const Color(0xFFD86E58),
      );
    }
  }

  void _drawGrassTuft(Canvas c, Offset point) {
    final paint = Paint()
      ..color = const Color(0xFF779F61)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // Multiple blades at different angles for a natural look.
    for (final blade in [(-5, -8), (-2, -11), (1, -10), (4, -8), (-3, -6)]) {
      c.drawLine(
        point,
        point.translate(blade.$1.toDouble(), blade.$2.toDouble()),
        paint,
      );
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
        center.translate(
          math.cos(angle) * radius * 0.6,
          math.sin(angle) * radius * 0.6,
        ),
        radius * 0.5,
        Paint()..color = color,
      );
    }
    // Center.
    c.drawCircle(
      center,
      radius * 0.35,
      Paint()..color = const Color(0xFFE6C65D),
    );
  }

  void _drawWateringCan(Canvas c, Offset point) {
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
      math.pi * 0.3,
      math.pi * 0.9,
      false,
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
      Paint()
        ..color = const Color(0x44D0E0DB)
        ..strokeWidth = 2,
    );
  }

  void _drawNurseryCrate(Canvas c, Offset point) {
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
        ..shader =
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFC4C7B8), Color(0xFFA4A798)],
            ).createShader(
              Rect.fromCenter(
                center: point.translate(0, -6),
                width: 10,
                height: 28,
              ),
            ),
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

  void _drawBench(Canvas c, Offset foot) {
    c.drawOval(
      Rect.fromCenter(center: foot.translate(2, 1), width: 65, height: 11),
      Paint()
        ..color = const Color(0x28586C43)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    for (final x in [-24.0, 24.0]) {
      c.drawLine(
        foot.translate(x, -7),
        foot.translate(x + 2, -27),
        Paint()
          ..color = const Color(0xFF785B3F)
          ..strokeWidth = 5,
      );
    }
    final seat = Path()
      ..moveTo(foot.dx - 34, foot.dy - 18)
      ..lineTo(foot.dx + 25, foot.dy - 18)
      ..lineTo(foot.dx + 34, foot.dy - 12)
      ..lineTo(foot.dx - 25, foot.dy - 12)
      ..close();
    c.drawPath(seat, Paint()..color = const Color(0xFFB98A5A));
    c.drawLine(
      foot.translate(-33, -17),
      foot.translate(26, -17),
      Paint()
        ..color = const Color(0xFFE0B47C)
        ..strokeWidth = 2,
    );
    for (final y in [-39.0, -31.0]) {
      c.drawLine(
        foot.translate(-29, y),
        foot.translate(27, y),
        Paint()
          ..color = const Color(0xFFAD8155)
          ..strokeWidth = 6,
      );
      c.drawLine(
        foot.translate(-29, y - 2),
        foot.translate(27, y - 2),
        Paint()
          ..color = const Color(0xFFD5A66D)
          ..strokeWidth = 2,
      );
    }
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
      Rect.fromCenter(
        center: base.translate(2, -height + 1),
        width: 6,
        height: 3,
      ),
      Paint()..color = const Color(0xFFA0C46B),
    );
  }

  void _brilliantSparkle(Canvas c, Offset point) {
    final rays = Paint()
      ..color = const Color(0xF2FFF9DE)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    c.drawLine(point.translate(0, -5), point.translate(0, 5), rays);
    c.drawLine(point.translate(-5, 0), point.translate(5, 0), rays);
    c.drawCircle(point, 2.7, Paint()..color = const Color(0xCCF5EDDA));
    c.drawCircle(
      point.translate(-1, -1),
      1.5,
      Paint()..color = const Color(0xFFFFFFFF),
    );
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
