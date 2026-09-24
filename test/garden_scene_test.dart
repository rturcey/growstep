import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_scene.dart';
import 'package:growstep/garden/garden_scene_renderer.dart';
import 'package:growstep/garden/garden_sprites.dart';
import 'package:growstep/garden/garden_state.dart';
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
  }) {
    events.add('sprite:$name:$includeContactShadow');
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('artboard and viewport use one reversible transform on both phones', () {
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

  const bedVariants = {
    'potager_decor_bac_potager_statique_ordinaire_00.png',
    'potager_decor_bac_potager_statique_ordinaire_01.png',
    'potager_decor_bac_potager_statique_ordinaire_02.png',
    'potager_decor_bac_potager_statique_ordinaire_03.png',
  };

  const neutralBedVariant = 'potager_decor_bac_potager_statique_ordinaire_00.png';

  test('potager beds preserve the eight existing ground contacts', () {
    expect(PotagerBeds.beds.length, 8);
    expect(
      PotagerBeds.beds.map((bed) => bed.contact),
      GardenGame.anchorsFor(ZoneType.potager),
    );
  });

  test('potager beds reference only neutral authored variants', () async {
    for (final bed in PotagerBeds.beds) {
      expect(bedVariants, contains(bed.asset));
      expect(
        bed.asset,
        neutralBedVariant,
        reason:
            'only variant 00 (bois + terre, no integrated stone or foliage) '
            'is neutral enough to frame all crops without crossing them',
      );
    }
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/sprites/manifest.json'),
    ) as Map<String, dynamic>;
    for (final bed in PotagerBeds.beds) {
      expect(manifest.containsKey(bed.asset), isTrue);
    }
  });

  test('potager bed variant mapping is deterministic', () {
    expect(PotagerBeds.beds, same(PotagerBeds.beds));
    final firstPass = PotagerBeds.beds.map((bed) => bed.asset).toList();
    final secondPass = PotagerBeds.beds.map((bed) => bed.asset).toList();
    expect(secondPass, firstPass);
  });

  test('each potager bed draws its authored variant via the sprite renderer', () {
    final sprites = _RecordingSprites();
    for (final bed in PotagerBeds.beds) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      sprites.events.clear();
      GardenSceneRenderer.drawSprite(canvas, bed, sprites);
      expect(sprites.events, [
        'shadow',
        'sprite:${bed.asset}:false',
      ]);
      recorder.endRecording().dispose();
    }
  });

  test('potager beds have unique stable IDs for depth sorting', () {
    final ids = PotagerBeds.beds.map((bed) => bed.id).toList();
    expect(ids.toSet().length, 8, reason: 'each bed has a unique ID');
    for (var index = 0; index < 8; index++) {
      expect(ids[index], 'bed_$index');
    }
  });
}
