import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_scene.dart';
import 'package:growstep/garden/garden_scene_renderer.dart';
import 'package:growstep/garden/garden_sprites.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/garden/potager_path.dart';
import 'package:growstep/garden/potager_grid_adapter.dart';
import 'package:growstep/garden/potager_scene.dart';

class _RecordingSprites extends GardenSprites {
  final events = <String>[];

  @override
  bool hasContactShadow(String name) => true;

  @override
  void drawContactShadow(
    ui.Canvas canvas,
    ui.Offset contact,
    double width,
    double height,
  ) {
    events.add('shadow');
  }

  @override
  bool draw(
    ui.Canvas canvas,
    String name,
    ui.Offset contact,
    double width,
    double height, {
    double opacity = 1,
    bool includeContactShadow = true,
    ui.ColorFilter? colorFilter,
  }) {
    events.add('sprite:$name:$includeContactShadow');
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('artboard and viewport use one reversible transform on both phones', () {
    expect(GardenGame.touchSize, greaterThanOrEqualTo(44));
    for (final viewport in [const ui.Size(390, 844), const ui.Size(375, 667)]) {
      final transform = GardenArtboardTransform(viewport);
      expect(transform.scale, 1);
      expect(
        transform.origin,
        ui.Offset((viewport.width - 390) / 2, (viewport.height - 450) / 2),
      );
      for (final contact in [
        const ui.Offset(355, 150),
        const ui.Offset(355, 230),
      ]) {
        expect(transform.toArtboard(transform.toViewport(contact)), contact);
      }
    }
  });

  test(
    'pilot composition is fixed, distinct, and names known assets',
    () async {
      expect(PotagerPilotScene.objects.map((object) => object.id), [
        'east_upper_rock',
        'east_barrel',
      ]);
      expect(PotagerPilotScene.rock.layer, GardenLayer.depth);
      expect(PotagerPilotScene.rock.contact, const ui.Offset(355, 150));
      expect(PotagerPilotScene.barrel.contact, const ui.Offset(355, 230));
      expect(PotagerPilotScene.rock.asset, contains('rochers_herbe'));
      expect(PotagerPilotScene.barrel.asset, contains('tonneau_bois'));
      expect(PotagerPilotScene.objects, same(PotagerPilotScene.objects));
      final manifest = jsonDecode(
        await rootBundle.loadString('assets/sprites/manifest.json'),
      ) as Map<String, dynamic>;
      for (final object in PotagerPilotScene.objects) {
        expect(manifest.containsKey(object.asset), isTrue);
      }
    },
  );

  test('depth uses ground Y, z bias, ID and stable legacy order', () {
    final objects = <GardenPlacedObject>[
      const GardenPlacedObject('zeta', ui.Offset(0, 20)),
      const GardenPlacedObject('back', ui.Offset(0, 10)),
      const GardenPlacedObject('alpha', ui.Offset(0, 20)),
      const GardenPlacedObject('biased', ui.Offset(0, 19), zBias: 2),
    ];
    expect(GardenSceneRenderer.depthOrder(objects).map((object) => object.id), [
      'back',
      'alpha',
      'zeta',
      'biased',
    ]);
    final anonymous = [
      GardenPlacedObject('', const ui.Offset(0, 20)),
      GardenPlacedObject('', const ui.Offset(0, 20)),
    ];
    expect(GardenSceneRenderer.depthOrder(anonymous), orderedEquals(anonymous));
  });

  test('fixed layers precede the shared depth phase', () {
    final order = GardenSceneRenderer.depthOrder([
      PotagerPilotScene.rock,
      const GardenSpriteObject(
        id: 'flat_ground',
        asset: 'fixture.png',
        contact: ui.Offset(100, 400),
        size: ui.Size(20, 10),
        layer: GardenLayer.ground,
      ),
    ]);
    expect(order.map((object) => object.id), [
      'flat_ground',
      'east_upper_rock',
    ]);
  });

  test('contact shadow is painted once directly before its sprite', () {
    final sprites = _RecordingSprites();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    GardenSceneRenderer.drawSprite(canvas, PotagerPilotScene.barrel, sprites);
    expect(sprites.events, [
      'shadow',
      'sprite:${PotagerPilotScene.barrel.asset}:false',
    ]);
    recorder.endRecording().dispose();
  });

  test('flat path sprites do not receive a second contact shadow', () {
    final sprites = _RecordingSprites();
    final recorder = ui.PictureRecorder();
    GardenSceneRenderer.drawSprite(
      ui.Canvas(recorder),
      PotagerPath.stones.first,
      sprites,
    );
    expect(sprites.events, ['sprite:${PotagerPath.stones.first.asset}:false']);
    recorder.endRecording().dispose();
  });

  test('eight saved plot indexes retain their historical grid contacts', () {
    const historical = <ui.Offset>[
      ui.Offset(75, 150),
      ui.Offset(275, 230),
      ui.Offset(75, 310),
      ui.Offset(315, 310),
      ui.Offset(195, 150),
      ui.Offset(115, 230),
      ui.Offset(195, 310),
      ui.Offset(315, 150),
    ];
    expect(
      PotagerPlots.plots.map((plot) => plot.index),
      List.generate(8, (i) => i),
    );
    expect(PotagerPlots.contacts, historical);
    expect(GardenGame.anchorsFor(ZoneType.potager), PotagerPlots.contacts);
    for (final plot in PotagerPlots.plots) {
      expect(plot.contact, PotagerPlots.grid.toScreen(plot.gridI, plot.gridJ));
      expect(plot.id, 'soil_plot_${plot.index}');
    }
  });

  test('Potager grid adapter projects representative cells', () {
    const adapter = PotagerGridAdapter();
    expect(adapter.toArtboard(0, 0), const ui.Offset(195, 230));
    expect(adapter.toArtboard(1, 0), const ui.Offset(235, 250));
    expect(adapter.toArtboard(0, 1), const ui.Offset(155, 250));
    expect(adapter.toArtboard(1, 1), const ui.Offset(195, 270));
  });

  test('purchased states reveal exactly 4, 6, or 8 soil plots', () {
    for (final count in [4, 6, 8]) {
      final visible = PotagerPlots.visible(count).toList();
      expect(visible.length, count);
      expect(visible.map((plot) => plot.index), List.generate(count, (i) => i));
      expect(
        visible.map((plot) => plot.contact),
        PotagerPlots.contacts.take(count),
      );
    }
    expect(PotagerPlots.plots, same(PotagerPlots.plots));
  });

  test('every flat footprint uses the same inset 2:1 grid geometry', () {
    expect(IsoGrid.cellWidth, 80);
    expect(IsoGrid.cellHeight, 40);
    expect(PotagerPlots.footprintWidth, lessThan(IsoGrid.cellWidth));
    expect(PotagerPlots.footprintHeight, lessThan(IsoGrid.cellHeight));
    expect(
      PotagerPlots.footprintWidth / PotagerPlots.footprintHeight,
      closeTo(2, 0.01),
    );
    for (final plot in PotagerPlots.plots) {
      final path = PotagerPlots.footprintAt(plot.contact);
      final bounds = path.getBounds();
      expect(bounds.center, plot.contact);
      expect(bounds.width, PotagerPlots.footprintWidth);
      expect(bounds.height, PotagerPlots.footprintHeight);
      expect(path.contains(plot.contact), isTrue);
    }
  });
}
