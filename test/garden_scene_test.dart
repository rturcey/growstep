import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_scene.dart';
import 'package:growstep/garden/garden_scene_renderer.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/garden/potager_sprites.dart';

void main() {
  test('artboard and viewport use one reversible transform on both phones', () {
    expect(GardenGame.touchSize, greaterThanOrEqualTo(44));

    for (final viewport in [const ui.Size(390, 844), const ui.Size(375, 667)]) {
      final transform = GardenArtboardTransform(viewport);

      expect(transform.scale, 1);

      expect(
        transform.origin,
        ui.Offset((viewport.width - 390) / 2, (viewport.height - 450) / 2),
      );

      for (final contact in PotagerSprites.plotAnchors) {
        expect(transform.toArtboard(transform.toViewport(contact)), contact);
      }
    }
  });

  test('depth order remains stable for non-Tiled dynamic objects', () {
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
  });

  test('potager uses eight stable orthogonal plot contacts', () {
    expect(
      GardenGame.anchorsFor(ZoneType.potager),
      PotagerSprites.plotAnchors,
    );

    expect(PotagerSprites.plotAnchors, const [
      ui.Offset(115, 145),
      ui.Offset(195, 145),
      ui.Offset(275, 145),
      ui.Offset(115, 225),
      ui.Offset(275, 225),
      ui.Offset(115, 305),
      ui.Offset(195, 305),
      ui.Offset(275, 305),
    ]);
  });

  test('20x20 map fits the fixed artboard without isometric projection', () {
    expect(PotagerSprites.renderTileSize, 16);

    expect(PotagerSprites.renderedMapSize, const ui.Size(320, 320));

    expect(PotagerSprites.mapOffset, const ui.Offset(35, 65));
  });

  test('Growstep species map to four Fantasy Farm growth stages', () {
    for (final species in [
      Species.tomate,
      Species.carotte,
      Species.courgette,
    ]) {
      expect(PotagerSprites.tilesFor(species), hasLength(4));
    }

    expect(PotagerSprites.tilesFor(Species.tomate), [
      3,
      7,
      11,
      11,
    ]);

    expect(PotagerSprites.tilesFor(Species.carotte), [
      19,
      23,
      27,
      27,
    ]);

    expect(PotagerSprites.tilesFor(Species.courgette), [
      55,
      59,
      63,
      67,
    ]);
  });
}
