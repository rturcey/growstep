import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_scene.dart';
import 'package:growstep/garden/garden_scene_renderer.dart';
import 'package:growstep/garden/garden_sprite_metadata.dart';
import 'package:growstep/garden/garden_sprites.dart';
import 'package:growstep/garden/potager_grid_adapter.dart';
import 'package:growstep/garden/potager_tiled_objects.dart';
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

class _ShadowProbeSprites extends GardenSprites {
  final drawn = <GardenShadow>[];

  @override
  bool hasContactShadow(String name) => true;

  @override
  void drawContactShadow(
    ui.Canvas canvas,
    ui.Offset contact,
    double width,
    double height, {
    GardenShadow style = GardenShadow.medium,
  }) {
    drawn.add(style);
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
  }) => true;
}

Future<TiledMap> _loadMap([String? source]) => TiledMap.fromString(
  source ?? File('assets/maps/potager.tmx').readAsStringSync(),
  (filename) async => _FileTsxProvider(filename),
);

void main() {
  test(
    'TMX rock and shadow plots project through the sprite manifest',
    () async {
      final map = await _loadMap();
      final source = jsonDecode(
        File('assets/sprites/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final manifest = {
        for (final entry in source.entries)
          entry.key: GardenSpriteMetadata.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      };
      final objects = PotagerTiledObjects.fromMap(map, manifest);

      expect(objects.rock.id, 'east_upper_rock');
      expect(
        objects.rock.asset,
        'commun_decor_rochers_herbe_statique_ordinaire_00.png',
      );
      expect(objects.rock.layer, GardenLayer.depth);
      expect(objects.rock.opacity, 0.82);
      expect(objects.rock.size.width, closeTo(41.4, 0.001));
      expect(objects.rock.size.height, closeTo(25.2, 0.001));
      expect(objects.rockAnchorDelta, const ui.Offset(0, -2.925));
      expect(objects.rock.contact.dx, 355);
      expect(objects.rock.contact.dy, 150);
      expect(objects.rock.shadowOverride, isNull);
      expect(objects.plotContacts, {
        'plot_0': const ui.Offset(75, 150),
        'plot_1': const ui.Offset(275, 230),
        'plot_2': const ui.Offset(75, 310),
        'plot_3': const ui.Offset(315, 310),
        'plot_4': const ui.Offset(195, 150),
        'plot_5': const ui.Offset(115, 230),
        'plot_6': const ui.Offset(195, 310),
        'plot_7': const ui.Offset(315, 150),
      });

      final document = XmlDocument.parse(
        File('assets/maps/potager.tmx').readAsStringSync(),
      );
      final rock = document.descendants.whereType<XmlElement>().singleWhere(
        (element) =>
            element.name.local == 'object' &&
            element.getAttribute('name') == 'east_upper_rock',
      );
      final gridCol = rock.descendants.whereType<XmlElement>().singleWhere(
        (element) => element.getAttribute('name') == 'gridCol',
      );
      gridCol.setAttribute('value', '1');
      final moved = PotagerTiledObjects.fromMap(
        await _loadMap(document.toXmlString()),
        manifest,
      );
      expect(moved.rock.contact.dx, 395);
      expect(moved.rock.contact.dy, 170);
    },
  );

  test(
    'TMX plots preserve the eight historical contacts by stable name',
    () async {
      const adapter = PotagerGridAdapter();
      final map = await _loadMap();
      expect(map.orientation, MapOrientation.isometric);
      expect(
        (map.width, map.height, map.tileWidth, map.tileHeight),
        (14, 14, 80, 40),
      );

      final plots = map.layers.singleWhere(
        (layer) => layer.name == 'plots',
      ) as ObjectGroup;
      expect(plots.colorHex, isNot(ObjectGroup.defaultColorHex));
      expect(plots.objects, hasLength(8));

      // Authored decimal half-cells preserve the historical saved contacts.
      const expected = <String, (double, double, double, double)>{
        'plot_0': (-3.5, -0.5, 75, 150),
        'plot_1': (1, -1, 275, 230),
        'plot_2': (0.5, 3.5, 75, 310),
        'plot_3': (3.5, 0.5, 315, 310),
        'plot_4': (-2, -2, 195, 150),
        'plot_5': (-1, 1, 115, 230),
        'plot_6': (2, 2, 195, 310),
        'plot_7': (-0.5, -3.5, 315, 150),
      };
      expect(
        plots.objects.map((object) => object.name).toSet(),
        expected.keys.toSet(),
      );
      for (final plot in plots.objects) {
        final (col, row, x, y) = expected[plot.name]!;
        expect(plot.isPoint, isTrue, reason: plot.name);
        expect(plot.class_, 'plot', reason: plot.name);
        expect(
          plot.properties.getValue<double>('gridCol'),
          col,
          reason: plot.name,
        );
        expect(
          plot.properties.getValue<double>('gridRow'),
          row,
          reason: plot.name,
        );
        expect(
          adapter.fromTiledProperties(col, row),
          ui.Offset(x, y),
          reason: plot.name,
        );
        expect(
          adapter.fromTiledObject(plot.x, plot.y),
          ui.Offset(x, y),
          reason: plot.name,
        );
        expect(195 + (col - row) * 40, x, reason: plot.name);
        expect(230 + (col + row) * 20, y, reason: plot.name);
        expect(plot.x, 300 + col * 40, reason: plot.name);
        expect(plot.y, 380 + row * 40, reason: plot.name);
        expect(
          560 + plot.x - plot.y,
          480 + (col - row) * 40,
          reason: plot.name,
        );
        expect(
          (plot.x + plot.y) / 2,
          340 + (col + row) * 20,
          reason: plot.name,
        );
      }

      final document = XmlDocument.parse(
        File('assets/maps/potager.tmx').readAsStringSync(),
      );
      final objects = document.descendants.whereType<XmlElement>().where(
        (element) => element.name.local == 'object',
      );
      var changedId = 100;
      for (final object in objects) {
        object.setAttribute('id', '${changedId++}');
      }
      document.rootElement.setAttribute('nextobjectid', '$changedId');
      final renumberedMap = await _loadMap(document.toXmlString());
      final renumberedPlots = renumberedMap.layers.singleWhere(
        (layer) => layer.name == 'plots',
      ) as ObjectGroup;
      expect(
        {
          for (final plot in renumberedPlots.objects)
            plot.name: (
              plot.properties.getValue<double>('gridCol'),
              plot.properties.getValue<double>('gridRow'),
            ),
        },
        {
          for (final entry in expected.entries)
            entry.key: (entry.value.$1, entry.value.$2),
        },
      );
    },
  );

  test('TMX prop identifies the existing rock and its grid contact', () async {
    final map = await _loadMap();
    final props =
        map.layers.singleWhere((layer) => layer.name == 'props') as ObjectGroup;
    expect(props.objects, hasLength(1));
    final rock = props.objects.single;
    expect(rock.name, 'east_upper_rock');
    expect(rock.class_, 'prop');
    expect(rock.gid, isNotNull);
    expect(
      map.tileByGid(rock.gid!)?.image?.source,
      '../sprites/commun_decor_rochers_herbe_statique_ordinaire_00.png',
    );
    final rockImage = map.tileByGid(rock.gid!)!.image!;
    expect(
      rock.width / rock.height,
      closeTo(rockImage.width! / rockImage.height!, 0.001),
    );
    expect(rock.properties.getValue<double>('gridCol'), 0);
    expect(rock.properties.getValue<double>('gridRow'), -4);
    expect((rock.x, rock.y), (300, 220));
    expect((560 + rock.x - rock.y, (rock.x + rock.y) / 2), (640, 260));
    expect((195 + (0 - -4) * 40, 230 + (0 + -4) * 20), (355, 150));
  });

  test('TMX path contains painted stone tiles at named grid cells', () async {
    final map = await _loadMap();
    const adapter = PotagerGridAdapter();
    final offset = adapter.tileMapOffset(map);
    expect(offset, const ui.Offset(-285, -110));
    // flame_tiled anchors each 80 × 40 isometric tile at its image center.
    // Painted cell (6,8) is the logical (-1,-1) contact on the artboard.
    final tileContact = ui.Offset(
      (6 - 8 + map.height) * map.tileWidth / 2 + offset.dx,
      (6 + 8 + 1) * map.tileHeight / 2 + offset.dy,
    );
    expect(tileContact, adapter.toArtboard(-1, -1));
    expect(map.layers.map((layer) => layer.name).toList(), [
      'ground',
      'skirt',
      'path',
      'plots',
      'floor_decor',
      'edge_overlays',
      'props',
    ]);
    expect(map.tilesets, hasLength(8));
    for (final tileset in map.tilesets) {
      expect(tileset.objectAlignment, ObjectAlignment.bottom);
      expect(tileset.image, isNull); // collection of individual images
    }
    for (final name in ['ground', 'skirt']) {
      final layer = map.layerByName(name) as TileLayer;
      expect(
        layer.data,
        everyElement(0),
        reason: '$name stays empty until terrain migration',
      );
    }

    final path =
        map.layers.singleWhere((layer) => layer.name == 'path') as TileLayer;
    expect((path.width, path.height), (14, 14));
    final painted = <(int, int, String)>[];
    for (var row = 0; row < path.height; row++) {
      for (var col = 0; col < path.width; col++) {
        final gid = path.data![row * path.width + col];
        if (gid == 0) continue;
        painted.add((col, row, map.tileByGid(gid)!.image!.source!));
      }
    }
    expect(painted, [
      (6, 8, '../sprites/commun_sol_pas_pierre_tile_00.png'),
      (7, 9, '../sprites/commun_sol_pas_pierre_tile_01.png'),
      (8, 10, '../sprites/commun_sol_pas_pierre_tile_02.png'),
      (8, 11, '../sprites/commun_sol_pas_pierre_tile_03.png'),
      (9, 12, '../sprites/commun_sol_pas_pierre_tile_04.png'),
    ]);
    for (final tile in map.tilesets[1].tiles.take(6)) {
      expect((tile.image?.width, tile.image?.height), (80, 40));
      expect(File('assets/maps/${tile.image!.source}').existsSync(), isTrue);
    }
  });

  test('TMX accepts half-cell floats and validates shadow overrides', () async {
    final source = jsonDecode(
      File('assets/sprites/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final manifest = {
      for (final entry in source.entries)
        entry.key: GardenSpriteMetadata.fromJson(
          entry.value as Map<String, dynamic>,
        ),
    };
    final xml = XmlDocument.parse(
      File('assets/maps/potager.tmx').readAsStringSync(),
    );
    final rock = xml.descendants.whereType<XmlElement>().singleWhere(
      (element) =>
          element.name.local == 'object' &&
          element.getAttribute('name') == 'east_upper_rock',
    );
    final properties = rock.findElements('properties').single;
    properties.children.add(
      XmlElement(XmlName('property'), [
        XmlAttribute(XmlName('name'), 'shadow'),
        XmlAttribute(XmlName('value'), 'none'),
      ]),
    );
    final objects = PotagerTiledObjects.fromMap(
      await _loadMap(xml.toXmlString()),
      manifest,
    );
    expect(objects.rock.shadowOverride, GardenShadow.none);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final sprites = _ShadowProbeSprites();
    GardenSceneRenderer.drawSprite(canvas, objects.rock, sprites);
    expect(sprites.drawn, isEmpty);
    properties.findElements('property').last.setAttribute('value', 'elongated');
    final elongated = PotagerTiledObjects.fromMap(
      await _loadMap(xml.toXmlString()),
      manifest,
    );
    GardenSceneRenderer.drawSprite(canvas, elongated.rock, sprites);
    expect(sprites.drawn, [GardenShadow.elongated]);
    properties.findElements('property').last.setAttribute('value', 'none');
    GardenSceneRenderer.drawSprite(
      canvas,
      PotagerTiledObjects.fromMap(await _loadMap(), manifest).rock,
      sprites,
    );
    expect(sprites.drawn, [GardenShadow.elongated, GardenShadow.medium]);
    recorder.endRecording().dispose();
    final gridCol = properties
        .findElements('property')
        .singleWhere((element) => element.getAttribute('name') == 'gridCol');
    gridCol.setAttribute('value', '0.5');
    expect(
      PotagerTiledObjects.fromMap(
        await _loadMap(xml.toXmlString()),
        manifest,
      ).rock.contact,
      const ui.Offset(375, 160),
    );
    gridCol.setAttribute('value', '0.25');
    final invalidMap = await _loadMap(xml.toXmlString());
    expect(
      () => PotagerTiledObjects.fromMap(invalidMap, manifest),
      throwsFormatException,
    );
    gridCol.setAttribute('value', '0');
    properties.findElements('property').last.setAttribute('value', 'huge');
    final invalidShadow = await _loadMap(xml.toXmlString());
    expect(
      () => PotagerTiledObjects.fromMap(invalidShadow, manifest),
      throwsFormatException,
    );
  });
}
