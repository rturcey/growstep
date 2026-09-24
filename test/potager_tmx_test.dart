import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/potager_grid_adapter.dart';
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

Future<TiledMap> _loadMap([String? source]) => TiledMap.fromString(
  source ?? File('assets/maps/potager.tmx').readAsStringSync(),
  (filename) async => _FileTsxProvider(filename),
);

void main() {
  test('TMX plots preserve the eight historical contacts by stable name', () async {
    const adapter = PotagerGridAdapter();
    final map = await _loadMap();
    expect(map.orientation, MapOrientation.isometric);
    expect(
      (map.width, map.height, map.tileWidth, map.tileHeight),
      (14, 14, 80, 40),
    );

    final plots =
        map.layers.singleWhere((layer) => layer.name == 'plots') as ObjectGroup;
    expect(plots.colorHex, isNot(ObjectGroup.defaultColorHex));
    expect(plots.objects, hasLength(8));

    // Integer custom properties encode half-cell coordinates around the
    // historical Potager origin. The values below come from its saved contacts.
    const expected = <String, (int, int, double, double)>{
      'plot_0': (-7, -1, 75, 150),
      'plot_1': (2, -2, 275, 230),
      'plot_2': (1, 7, 75, 310),
      'plot_3': (7, 1, 315, 310),
      'plot_4': (-4, -4, 195, 150),
      'plot_5': (-2, 2, 115, 230),
      'plot_6': (4, 4, 195, 310),
      'plot_7': (-1, -7, 315, 150),
    };
    expect(
      plots.objects.map((object) => object.name).toSet(),
      expected.keys.toSet(),
    );
    for (final plot in plots.objects) {
      final (col, row, x, y) = expected[plot.name]!;
      expect(plot.isPoint, isTrue, reason: plot.name);
      expect(plot.class_, 'plot', reason: plot.name);
      expect(plot.properties.getValue<int>('gridCol'), col, reason: plot.name);
      expect(plot.properties.getValue<int>('gridRow'), row, reason: plot.name);
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
      expect(195 + (col - row) * 20, x, reason: plot.name);
      expect(230 + (col + row) * 10, y, reason: plot.name);
      expect(plot.x, 300 + col * 20, reason: plot.name);
      expect(plot.y, 380 + row * 20, reason: plot.name);
      expect(560 + plot.x - plot.y, 480 + (col - row) * 20, reason: plot.name);
      expect((plot.x + plot.y) / 2, 340 + (col + row) * 10, reason: plot.name);
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
            plot.properties.getValue<int>('gridCol'),
            plot.properties.getValue<int>('gridRow'),
          ),
      },
      {
        for (final entry in expected.entries)
          entry.key: (entry.value.$1, entry.value.$2),
      },
    );
  });

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
    expect(rock.properties.getValue<int>('gridCol'), 0);
    expect(rock.properties.getValue<int>('gridRow'), -8);
    expect((rock.x, rock.y), (300, 220));
    expect((560 + rock.x - rock.y, (rock.x + rock.y) / 2), (640, 260));
    expect((195 + (0 - -8) * 20, 230 + (0 + -8) * 10), (355, 150));
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
      'path',
      'plots',
      'props',
    ]);
    final tileset = map.tilesets.single;
    expect(tileset.objectAlignment, ObjectAlignment.bottom);
    expect(tileset.image, isNull); // collection of individual images

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
    for (final tile in tileset.tiles.take(6)) {
      expect((tile.image?.width, tile.image?.height), (80, 40));
      expect(File('assets/maps/${tile.image!.source}').existsSync(), isTrue);
    }
  });
}
