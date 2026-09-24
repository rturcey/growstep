import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/garden/garden_scene.dart';
import 'package:growstep/garden/potager_composition.dart';
import 'package:growstep/garden/potager_path.dart';
import 'package:growstep/garden/potager_scene.dart';

/// Ignore the almost transparent painted shadow when measuring stone clearance.
Future<ui.Rect> _paintedBounds(String asset) async {
  final bytes = File('assets/sprites/$asset').readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  var left = image.width;
  var top = image.height;
  var right = 0;
  var bottom = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (pixels.getUint8((y * image.width + x) * 4 + 3) <= 32) continue;
      if (x < left) left = x;
      if (y < top) top = y;
      if (x + 1 > right) right = x + 1;
      if (y + 1 > bottom) bottom = y + 1;
    }
  }
  image.dispose();
  codec.dispose();
  if (right == 0) throw StateError('Sprite sans pixels visibles : $asset');
  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'le réseau de pas reste connecté et ses branches approchent les cultures',
    () {
      final routes = PotagerPath.routes;
      final contacts = routes.expand((route) => route).toSet();
      expect(contacts, contains(const ui.Offset(195, 410)));
      final connected = routes.first.toSet();
      for (final route in routes.skip(1)) {
        expect(connected, contains(route.first));
        connected.addAll(route);
      }

      for (final route in routes) {
        for (final (index, point) in route.indexed) {
          final i = ((point.dy - 230) / 20 + (point.dx - 195) / 40) / 2;
          final j = ((point.dy - 230) / 20 - (point.dx - 195) / 40) / 2;
          expect(i * 2, closeTo((i * 2).round(), 0.001));
          expect(j * 2, closeTo((j * 2).round(), 0.001));
          if (index > 0) {
            expect((point - route[index - 1]).distance, lessThan(46));
          }
        }
      }

      final plots = GardenGame.anchorsFor(ZoneType.potager);
      for (final branch in routes.skip(1)) {
        expect(
          plots
              .map((plot) => (branch.last - plot).distance)
              .reduce((a, b) => a < b ? a : b),
          lessThan(46),
        );
      }
      for (final index in [4, 6]) {
        expect(
          PotagerPath.stones
              .map((stone) => (stone.contact - plots[index]).distance)
              .reduce((a, b) => a < b ? a : b),
          lessThan(46),
        );
      }
    },
  );

  test(
    'les pierres déclarées sont déterministes, espacées et hors des sols',
    () async {
      final manifest = jsonDecode(
        File('assets/sprites/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final stones = PotagerPath.stones;
      final routeContacts = PotagerPath.routes.expand((route) => route).toSet();
      final ids = <String>{};
      final variants = <String>{};
      final bounds = <(String, ui.Rect)>[];
      final paintedBounds = <String, ui.Rect>{};

      expect(identical(stones, PotagerPath.stones), isTrue);
      expect(stones.first.contact, const ui.Offset(195, 410));
      for (final stone in stones) {
        expect(ids.add(stone.id), isTrue, reason: stone.id);
        expect(stone.layer, GardenLayer.path);
        expect(routeContacts, contains(stone.contact));
        expect(File('assets/sprites/${stone.asset}').existsSync(), isTrue);
        final metadata = manifest[stone.asset] as Map<String, dynamic>;
        final bbox = (metadata['bbox'] as List<dynamic>).cast<num>();
        final anchor = (metadata['anchor'] as List<dynamic>).cast<num>();
        final nativeWidth = (bbox[2] - bbox[0]) / 4;
        final nativeHeight = (bbox[3] - bbox[1]) / 4;
        final scale = stone.size.width / nativeWidth;
        expect(
          [0.8, 1.0, 1.2].any((value) => (scale - value).abs() < 0.001),
          isTrue,
        );
        expect(stone.size.height, closeTo(nativeHeight * scale, 0.01));
        final painted = paintedBounds[stone.asset] ??= await _paintedBounds(
          stone.asset,
        );
        final rect = ui.Rect.fromLTRB(
          stone.contact.dx + (painted.left - anchor[0]) / 4 * scale,
          stone.contact.dy + (painted.top - anchor[1]) / 4 * scale,
          stone.contact.dx + (painted.right - anchor[0]) / 4 * scale,
          stone.contact.dy + (painted.bottom - anchor[1]) / 4 * scale,
        );
        for (final (earlierId, earlier) in bounds) {
          // The painted silhouettes leave at least a narrow grass gap.
          expect(
            rect.inflate(2).overlaps(earlier.inflate(2)),
            isFalse,
            reason: '$earlierId / ${stone.id}',
          );
        }
        for (final plot in PotagerPlots.plots) {
          final touch = ui.Rect.fromCenter(
            center: plot.contact,
            width: GardenGame.touchSize,
            height: GardenGame.touchSize,
          );
          expect(
            rect.overlaps(touch),
            isFalse,
            reason: '${stone.id} / ${plot.id}',
          );
          final soil = PotagerPlots.footprintAt(plot.contact);
          for (var y = rect.top; y <= rect.bottom; y += 2) {
            for (var x = rect.left; x <= rect.right; x += 2) {
              expect(
                soil.contains(ui.Offset(x, y)),
                isFalse,
                reason: '${stone.id} / ${plot.id}',
              );
            }
          }
        }
        bounds.add((stone.id, rect));
        variants.add(stone.asset);
      }
      expect(variants.length, 6);
    },
  );

  test('les masses et les accessoires du potager suivent le treillis', () {
    final contacts = <ui.Offset>[
      PotagerComposition.trellisAnchor,
      PotagerComposition.barrelAnchor,
      PotagerComposition.wateringCanAnchor,
      PotagerComposition.nurseryCrateAnchor,
      ...PotagerComposition.rimGrass,
      for (final mass in PotagerComposition.masses) ...[
        for (final shrub in mass.shrubs) shrub.anchor,
        for (final rock in mass.rocks) rock.anchor,
      ],
    ];
    for (final point in contacts) {
      final i = ((point.dy - 230) / 20 + (point.dx - 195) / 40) / 2;
      final j = ((point.dy - 230) / 20 - (point.dx - 195) / 40) / 2;
      expect(i * 2, closeTo((i * 2).round(), 0.001));
      expect(j * 2, closeTo((j * 2).round(), 0.001));
    }
  });

  test('le potager montre un chemin en pierre depuis son entrée', () async {
    final game = GardenGame();
    await game.onLoad();
    game.onGameResize(Vector2(390, 450));
    final recorder = ui.PictureRecorder();
    game.render(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(390, 450);
    addTearDown(() {
      image.dispose();
      picture.dispose();
      game.onRemove();
    });

    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = bytes!;
    int creamPixels(ui.Rect region) {
      var count = 0;
      for (var y = region.top.toInt(); y < region.bottom; y++) {
        for (var x = region.left.toInt(); x < region.right; x++) {
          final pixel = (y * 390 + x) * 4;
          final red = pixels.getUint8(pixel);
          final green = pixels.getUint8(pixel + 1);
          final blue = pixels.getUint8(pixel + 2);
          if (red > 190 && green > 170 && blue > 140) count++;
        }
      }
      return count;
    }

    // The entrance, central bend, and right branch remain visible in the
    // rendered scene; geometry tests above check actual spacing and clearance.
    expect(
      creamPixels(const ui.Rect.fromLTRB(170, 360, 220, 415)),
      greaterThan(50),
    );
    expect(
      creamPixels(const ui.Rect.fromLTRB(125, 265, 215, 335)),
      greaterThan(100),
    );
    expect(
      creamPixels(const ui.Rect.fromLTRB(215, 185, 255, 220)),
      greaterThan(30),
    );
  });
}
