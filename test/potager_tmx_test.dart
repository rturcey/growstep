import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_scene.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/garden/potager_sprites.dart';
import 'package:tiled/tiled.dart';
import 'package:xml/xml.dart';

class _FileTsxProvider implements TsxProvider {
  _FileTsxProvider(this.filename);

  @override
  final String filename;

  @override
  Parser getSource(String filename) => XmlParser(
    XmlDocument.parse(File('assets/maps/$filename').readAsStringSync())
        .rootElement,
  );

  @override
  Parser? getCachedSource() => null;
}

Future<TiledMap> _loadMap() => TiledMap.fromString(
  File('assets/maps/potager_2d_v1.tmx').readAsStringSync(),
  (filename) async => _FileTsxProvider(filename),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('potager v1 is a 20x20 orthogonal 32px Tiled map', () async {
    final map = await _loadMap();

    expect(map.orientation, MapOrientation.orthogonal);

    expect(
      (map.width, map.height, map.tileWidth, map.tileHeight),
      (20, 20, 32, 32),
    );
  });

  test('potager contains the canonical 2D visual layers', () async {
    final map = await _loadMap();

    expect(map.layers.map((layer) => layer.name).toList(), [
      'ground',
      'paths',
      'soil',
      'orchard_preview',
      'plants_preview',
      'decor',
      'plots',
    ]);

    for (final name in [
      'ground',
      'paths',
      'soil',
      'orchard_preview',
      'plants_preview',
      'decor',
    ]) {
      final layer = map.layerByName(name);

      expect(layer, isA<TileLayer>(), reason: name);

      expect((layer as TileLayer).data, hasLength(400), reason: name);
    }
  });

  test(
    'ground is completely authored and crops preview stays authored',
    () async {
      final map = await _loadMap();

      final ground = map.layerByName('ground') as TileLayer;

      expect(ground.data!.where((gid) => gid != 0), hasLength(400));

      final crops = map.layerByName('plants_preview') as TileLayer;

      expect(crops.data!.where((gid) => gid != 0), isNotEmpty);
    },
  );

  test('eight Tiled plot points map exactly to runtime contacts', () async {
    final map = await _loadMap();

    final plots = map.layerByName('plots') as ObjectGroup;

    expect(plots.objects, hasLength(8));

    const gridCoordinates = [
      (4, 4),
      (9, 4),
      (14, 4),
      (4, 9),
      (14, 9),
      (4, 14),
      (9, 14),
      (14, 14),
    ];

    for (var index = 0; index < 8; index++) {
      final object = plots.objects.singleWhere(
        (object) => object.name == 'plot_$index',
      );

      final (gridX, gridY) = gridCoordinates[index];

      expect(object.isPoint, isTrue);

      expect(object.class_, 'plot');

      expect(object.properties.getValue<int>('gridX'), gridX);

      expect(object.properties.getValue<int>('gridY'), gridY);

      expect(object.x, (gridX + 1) * 32);

      expect(object.y, (gridY + 1) * 32);

      final rendered =
          PotagerSprites.mapOffset +
          ui.Offset(object.x * 0.5, object.y * 0.5);

      expect(rendered, GardenGame.anchorsFor(ZoneType.potager)[index]);
    }
  });

  test('all eight 2D contacts are tappable on both phone sizes', () async {
    final game = GardenGame()
      ..snapshot = GardenSnapshot.initial().copyWith(
        zones: {
          ...GardenSnapshot.initial().zones,
          ZoneType.potager: List<Plant?>.filled(8, null),
        },
      );

    await game.onLoad();

    for (final size in [const ui.Size(390, 844), const ui.Size(375, 667)]) {
      game.onGameResize(Vector2(size.width, size.height));

      final transform = GardenArtboardTransform(size);

      for (final (slot, anchor) in GardenGame.anchorsFor(
        ZoneType.potager,
      ).indexed) {
        expect(
          game.hitTestSlot(transform.toViewport(anchor)),
          slot,
          reason: 'slot $slot at $size',
        );
      }
    }

    game.onRemove();
  });
}
