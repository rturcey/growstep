import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/garden/potager_composition.dart';
import 'package:growstep/garden/potager_path.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('les pas restent sur le treillis, reliés et proches des huit lits', () {
    final routes = PotagerPath.routes;
    final contacts = routes.expand((route) => route).toSet();
    expect(contacts, contains(const ui.Offset(195, 410)));
    expect(routes[1].first, routes[0][7]);
    expect(routes[2].first, routes[0][4]);
    expect(routes[3].first, routes[0].last);
    expect(routes[4].first, routes[0].last);

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

    for (final bed in GardenGame.anchorsFor(ZoneType.potager)) {
      // A stone approaches the bed while remaining outside its 44 × 44
      // selection target, including the stone's own half-width/height.
      expect(
        contacts
            .map((point) => (point - bed).distance)
            .reduce((a, b) => a < b ? a : b),
        lessThan(46),
      );
      for (final point in contacts) {
        expect(
          (point.dx - bed.dx).abs() >= 35 || (point.dy - bed.dy).abs() >= 30,
          isTrue,
        );
      }
    }
  });

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

    // Broad entrance and rear approach regions stay readable even if individual
    // stepping stones are repositioned during visual review.
    expect(
      creamPixels(const ui.Rect.fromLTRB(155, 345, 235, 405)),
      greaterThan(100),
    );
    expect(
      creamPixels(const ui.Rect.fromLTRB(100, 145, 175, 185)),
      greaterThan(30),
    );
    expect(
      creamPixels(const ui.Rect.fromLTRB(215, 145, 290, 185)),
      greaterThan(30),
    );
  });
}
