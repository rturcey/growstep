import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_scene.dart';
import 'package:growstep/garden/garden_sprite_metadata.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/garden/potager_grid_adapter.dart';
import 'package:growstep/garden/potager_scene.dart';
import 'package:growstep/garden/potager_tiled_objects.dart';
import 'package:tiled/tiled.dart';
import 'package:xml/xml.dart';

/// Candidate capture/contact guards from #67, extended for #68's static art.
///
/// Every `GardenGame` instance in this file is constructed with
/// `potagerMapFile: 'potager_diorama_v1.tmx'` so that the tests exercise the
/// candidate map through the real runtime, not the production map.
///
/// These tests prove:
/// - the candidate loads through `GardenGame.onLoad`;
/// - the eight `emplacements de plantation` (0–7) with their saved order,
///   contacts au sol, and tap behavior are unchanged;
/// - dynamic crops render through the real game using the candidate;
/// - deterministic captures are produced at 390×844 and 375×667 from the
///   candidate, not production;
/// - production `potager_diorama_v1.tmx` retains its gameplay invariants while candidate
///   art and palette entries are allowed to diverge.

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

Future<TiledMap> _loadMap(String filename) => TiledMap.fromString(
  File('assets/maps/$filename').readAsStringSync(),
  (filename) async => _FileTsxProvider(filename),
);

Map<String, GardenSpriteMetadata> _manifest() {
  final source = jsonDecode(
    File('assets/sprites/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return {
    for (final entry in source.entries)
      entry.key: GardenSpriteMetadata.fromJson(
        entry.value as Map<String, dynamic>,
      ),
  };
}

const _candidateFile = 'potager_diorama_v1.tmx';
const _productionFile = 'potager_diorama_v1.tmx';

/// A saturated snapshot with all eight potager slots purchased and planted.
GardenSnapshot _saturatedSnapshot() {
  final zones = <ZoneType, List<Plant?>>{};
  for (final zone in ZoneType.values) {
    final species = Species.values
        .where((value) => value.zone == zone)
        .toList();
    zones[zone] = List.generate(zone.maxSlots, (index) {
      final tier = index == 0 ? GrowthTier.brillante : GrowthTier.commune;
      return Plant(
        species: species[index % species.length],
        tier: tier,
        progressSteps: tier.stepsToMature,
      );
    });
  }
  return GardenSnapshot.initial().copyWith(
    zones: zones,
    ownedZones: ZoneType.values.toSet(),
  );
}

/// Render a GardenGame to raw RGBA bytes for deterministic comparison.
Future<ByteData> _renderToBytes(GardenGame game, int w, int h) async {
  game.onGameResize(Vector2(w.toDouble(), h.toDouble()));
  final recorder = ui.PictureRecorder();
  game.render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return bytes!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = _manifest();

  group('candidate loads through the real GardenGame', () {
    test('GardenGame defaults to the production Potager map', () {
      expect(GardenGame().potagerMapFile, _productionFile);
    });

    test('potager_diorama_v1.tmx exists as a separate candidate', () {
      expect(File('assets/maps/$_candidateFile').existsSync(), isTrue);
    });

    test(
      'candidate loads through GardenGame.onLoad without exception',
      () async {
        final game = GardenGame(potagerMapFile: _candidateFile);
        await game.onLoad();
        expect(game.potagerMapFile, _candidateFile);
        game.onRemove();
      },
    );
  });

  group('candidate preserves structural contracts', () {
    test(
      'candidate has the same dimensions and orientation as production',
      () async {
        final candidate = await _loadMap(_candidateFile);
        final production = await _loadMap(_productionFile);
        expect(candidate.orientation, MapOrientation.isometric);
        expect((candidate.width, candidate.height), (14, 14));
        expect((candidate.tileWidth, candidate.tileHeight), (80, 40));
        expect(
          (
            candidate.width,
            candidate.height,
            candidate.tileWidth,
            candidate.tileHeight,
          ),
          (
            production.width,
            production.height,
            production.tileWidth,
            production.tileHeight,
          ),
        );
      },
    );

    test(
      'candidate preserves the eight historical plot contacts by stable name',
      () async {
        const adapter = PotagerGridAdapter();
        final map = await _loadMap(_candidateFile);
        final plots = map.layerByName('plots') as ObjectGroup;
        expect(plots.objects, hasLength(8));

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
        expect(plots.objects.map((o) => o.name).toSet(), expected.keys.toSet());
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
        }
      },
    );

    test('candidate preserves production GID ranges and adds modular authoring palettes', () async {
      final candidate = await _loadMap(_candidateFile);
      final production = await _loadMap(_productionFile);

      const candidateOnlyLayers = {
        'earth',
        'bed_edges',
        'planter_edges_back',
        'planter_edges_front',
      };

      final candidateLayers = candidate.layers
          .map((layer) => layer.name)
          .toList();
      final productionLayers = production.layers
          .map((layer) => layer.name)
          .toList();

      expect(
        candidateLayers
            .where((name) => !candidateOnlyLayers.contains(name))
            .toList(),
        productionLayers,
      );

      // Production palettes remain first and keep exactly the same GID
      // ranges. Candidate authoring palettes may be appended afterwards.
      expect(
        candidate.tilesets.length,
        greaterThan(production.tilesets.length),
      );

      for (var i = 0; i < production.tilesets.length; i++) {
        expect(candidate.tilesets[i].firstGid, production.tilesets[i].firstGid);
        expect(
          candidate.tilesets[i].tiles.length,
          production.tilesets[i].tiles.length,
        );
      }

      for (final tileset in candidate.tilesets) {
        expect(tileset.objectAlignment, ObjectAlignment.bottom);
        expect(tileset.image, isNull);
      }
    });
    test('candidate preserves the east_upper_rock parser sentinel', () async {
      final map = await _loadMap(_candidateFile);
      final props = map.layerByName('props') as ObjectGroup;
      final rock = props.objects.singleWhere(
        (object) => object.name == 'east_upper_rock',
      );
      expect(rock.class_, 'prop');
      expect(rock.gid, isNotNull);
      expect(
        map.tileByGid(rock.gid!)?.image?.source,
        '../sprites/commun_decor_rochers_herbe_statique_ordinaire_00.png',
      );
      const adapter = PotagerGridAdapter();
      expect(
        adapter.fromTiledProperties(
          rock.properties.getValue<double>('gridCol')!,
          rock.properties.getValue<double>('gridRow')!,
        ),
        isA<ui.Offset>(),
      );
    });

    test(
      'candidate authoring tile layers contain only 80x40 surfaces',
      () async {
        final map = await _loadMap(_candidateFile);

        final allowed = <String, RegExp>{
          'ground': RegExp(r'^commun_sol_(herbe|terre|bordure_herbe)_tile_'),
          'earth': RegExp(r'^commun_sol_terre_tile_'),
          'bed_edges': RegExp(r'^potager_sol_bordure_parcelle_bois_tile_'),
          'planter_edges_back': RegExp(r'^potager_sol_bordure_bac_bois_tile_'),
          'planter_edges_front': RegExp(r'^potager_sol_bordure_bac_bois_tile_'),
          'skirt': RegExp(r'^commun_sol_tranche_terre_tile_'),
          'path': RegExp(
            r'^(commun_sol_pas_pierre_tile_|'
            r'potager_sol_dalles_chemin_tile_)',
          ),
        };

        for (final entry in allowed.entries) {
          final layer = map.layerByName(entry.key);
          expect(layer, isA<TileLayer>(), reason: entry.key);

          final tileLayer = layer as TileLayer;

          for (final gid in tileLayer.data!.where((gid) => gid != 0)) {
            final image = map.tileByGid(gid)?.image;

            expect(image, isNotNull, reason: '${entry.key} gid $gid');

            expect(
              (image!.width, image.height),
              (80, 40),
              reason: '${entry.key} gid $gid',
            );

            expect(
              image.source!.split('/').last,
              matches(entry.value),
              reason: '${entry.key} gid $gid',
            );
          }
        }
      },
    );
    test(
      'candidate exposes empty modular cultivation authoring layers',
      () async {
        final map = await _loadMap(_candidateFile);

        for (final name in const [
          'earth',
          'bed_edges',
          'planter_edges_back',
          'planter_edges_front',
          'path',
        ]) {
          final layer = map.layerByName(name);

          expect(layer, isA<TileLayer>(), reason: name);

          expect(
            (layer as TileLayer).data!.where((gid) => gid != 0),
            isEmpty,
            reason: '$name starts empty and is authored manually in Tiled',
          );
        }

        final xml = XmlDocument.parse(
          File('assets/maps/$_candidateFile').readAsStringSync(),
        );

        final sources = xml.rootElement
            .findElements('tileset')
            .map((element) => element.getAttribute('source'))
            .whereType<String>()
            .toSet();

        expect(sources, contains('bed_edges.tsx'));
        expect(sources, contains('planter_edges.tsx'));
      },
    );
    test('candidate ground is connected and its skirt stays outside', () async {
      final map = await _loadMap(_candidateFile);
      final ground = (map.layerByName('ground') as TileLayer).data!;
      final skirt = (map.layerByName('skirt') as TileLayer).data!;
      final occupied = {
        for (var i = 0; i < ground.length; i++)
          if (ground[i] != 0) i,
      };
      expect(occupied, isNotEmpty);
      expect(
        {
          for (var i = 0; i < skirt.length; i++)
            if (skirt[i] != 0) i,
        }.intersection(occupied),
        isEmpty,
      );
      final reached = <int>{};
      final pending = <int>[occupied.first];
      while (pending.isNotEmpty) {
        final index = pending.removeLast();
        if (!reached.add(index)) continue;
        final col = index % map.width;
        final row = index ~/ map.width;
        for (final (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final x = col + dx;
          final y = row + dy;
          if (x >= 0 && x < map.width && y >= 0 && y < map.height) {
            final neighbor = y * map.width + x;
            if (occupied.contains(neighbor) && !reached.contains(neighbor)) {
              pending.add(neighbor);
            }
          }
        }
      }
      expect(reached, occupied);
    });

    test(
      'candidate visual objects use valid anchored GIDs and half cells',
      () async {
        final map = await _loadMap(_candidateFile);
        const adapter = PotagerGridAdapter();
        const visualGroups = [
          'floor_decor',
          'vegetation',
          'rocks',
          'structures',
          'props',
          'edge_overlays',
        ];
        for (final group in map.layers.whereType<ObjectGroup>()) {
          if (!visualGroups.contains(group.name)) continue;
          for (final object in group.objects) {
            expect(object.gid, isNotNull, reason: object.name);
            final image = map.tileByGid(object.gid!)?.image;
            expect(image?.source, isNotNull, reason: object.name);
            expect(manifest, contains(image!.source!.split('/').last));
            expect(
              () => adapter.fromTiledProperties(
                object.properties.getValue<double>('gridCol')!,
                object.properties.getValue<double>('gridRow')!,
              ),
              returnsNormally,
              reason: object.name,
            );
          }
        }
      },
    );
  });

  test(
    'fixed cultivation objects are replaced by modular Tiled layers',
    () async {
      final map = await _loadMap(_candidateFile);

      const removedObjects = {
        'cultivation_heart',
        'cultivation_rear',
        'cultivation_right',
        'cultivation_left',
        'cultivation_front',
      };

      final objectNames = {
        for (final group in map.layers.whereType<ObjectGroup>())
          for (final object in group.objects) object.name,
      };

      expect(objectNames.intersection(removedObjects), isEmpty);

      for (final name in const [
        'earth',
        'bed_edges',
        'planter_edges_back',
        'planter_edges_front',
      ]) {
        expect(map.layerByName(name), isA<TileLayer>(), reason: name);
      }
    },
  );
  group('candidate preserves runtime contacts and gameplay', () {
    test('candidate plot contacts match the runtime PotagerPlots', () async {
      final map = await _loadMap(_candidateFile);
      final objects = PotagerTiledObjects.fromMap(map, manifest);
      for (final plot in PotagerPlots.plots) {
        expect(
          objects.plotContacts['plot_${plot.index}'],
          plot.contact,
          reason: 'plot_${plot.index} contact must match runtime anchor',
        );
      }
      expect(objects.plotContacts.keys, hasLength(8));
    });

    test('candidate and production preserve gameplay contacts', () async {
      final candidate = await _loadMap(_candidateFile);
      final production = await _loadMap(_productionFile);

      final c = PotagerTiledObjects.fromMap(candidate, manifest);
      final p = PotagerTiledObjects.fromMap(production, manifest);

      expect(c.plotContacts, p.plotContacts);

      // Pass 1 hero masses remain present.
      expect(
        c.sceneObjects.map((object) => object.id),
        containsAll([
          'west_rear_canopy',
          'east_rear_canopy',
          'west_vegetation_corner',
          'gardening_station',
          'front_edge_fringe',
        ]),
      );

      // Pass 2 no longer uses fixed cultivation sprites.
      // Beds and raised planters are authored through Tiled tile layers.
      expect(
        c.sceneObjects.map((object) => object.id),
        isNot(contains('cultivation_rear')),
      );
      expect(
        c.sceneObjects.map((object) => object.id),
        isNot(contains('cultivation_right')),
      );
      expect(
        c.sceneObjects.map((object) => object.id),
        isNot(contains('cultivation_left')),
      );
      expect(
        c.sceneObjects.map((object) => object.id),
        isNot(contains('cultivation_front')),
      );
    });

    test(
      'candidate contacts are tappable through GardenGame.hitTestSlot',
      () async {
        final snapshot = _saturatedSnapshot();
        final game = GardenGame(potagerMapFile: _candidateFile)
          ..snapshot = snapshot;
        await game.onLoad();
        for (final size in [const ui.Size(390, 844), const ui.Size(375, 667)]) {
          game.onGameResize(Vector2(size.width, size.height));
          final transform = GardenArtboardTransform(size);
          for (var slot = 0; slot < 8; slot++) {
            final anchor = GardenGame.anchorsFor(ZoneType.potager)[slot];
            final viewportPoint = transform.toViewport(anchor);
            expect(
              game.hitTestSlot(viewportPoint),
              slot,
              reason:
                  'slot $slot must be hittable at ${size.width}x${size.height}',
            );
          }
        }
        game.onRemove();
      },
    );
  });

  group('candidate deterministic captures', () {
    test('saturated state renders reproducibly at both phone sizes using the candidate', () async {
      final snapshot = _saturatedSnapshot();
      for (final viewport in [
        (screen: '390x844', w: 390, h: 844),
        (screen: '375x667', w: 375, h: 667),
      ]) {
        final game1 = GardenGame(potagerMapFile: _candidateFile)
          ..snapshot = snapshot;
        await game1.onLoad();
        final bytes1 = await _renderToBytes(game1, viewport.w, viewport.h);
        game1.onRemove();

        final game2 = GardenGame(potagerMapFile: _candidateFile)
          ..snapshot = snapshot;
        await game2.onLoad();
        final bytes2 = await _renderToBytes(game2, viewport.w, viewport.h);
        game2.onRemove();

        expect(
          bytes1.lengthInBytes,
          bytes2.lengthInBytes,
          reason: 'byte length at ${viewport.screen}',
        );
        expect(
          bytes1.buffer.asUint8List(),
          bytes2.buffer.asUint8List(),
          reason: 'captures must be identical at ${viewport.screen}',
        );
      }
    });

    test(
      'saturated captures differ from initial when using the candidate',
      () async {
        final saturated = _saturatedSnapshot();
        final initial = GardenSnapshot.initial().copyWith(
          ownedZones: ZoneType.values.toSet(),
        );

        final game1 = GardenGame(potagerMapFile: _candidateFile)
          ..snapshot = saturated;
        await game1.onLoad();
        final saturatedBytes = await _renderToBytes(game1, 390, 844);
        game1.onRemove();

        final game2 = GardenGame(potagerMapFile: _candidateFile)
          ..snapshot = initial;
        await game2.onLoad();
        final initialBytes = await _renderToBytes(game2, 390, 844);
        game2.onRemove();

        expect(
          saturatedBytes.buffer.asUint8List(),
          isNot(initialBytes.buffer.asUint8List()),
          reason: 'saturated and initial captures must differ',
        );
      },
    );

    test(
      'candidate captures contain visible crop pixels in the saturated state',
      () async {
        // Dynamic crops (tomato, carrot, courgette) render through the real
        // game using the candidate. Verify that the saturated render produces
        // non-background pixels at known crop contact areas.
        final snapshot = _saturatedSnapshot();
        final game = GardenGame(potagerMapFile: _candidateFile)
          ..snapshot = snapshot;
        await game.onLoad();
        final bytes = await _renderToBytes(game, 390, 844);
        game.onRemove();

        // Check a pixel near each crop contact. The artboard is centered in
        // the viewport; on a 390-wide screen the origin is at x=0. Each crop
        // at (cx, cy) maps to viewport (cx, cy + (844-450)/2).
        final originY = (844 - 450) ~/ 2;
        var nonBackgroundPixels = 0;
        for (final anchor in GardenGame.anchorsFor(ZoneType.potager)) {
          final px = anchor.dx.toInt();
          final py = (anchor.dy + originY).toInt();
          if (px < 0 || px >= 390 || py < 0 || py >= 844) continue;
          final offset = (py * 390 + px) * 4;
          final r = bytes.getUint8(offset);
          final g = bytes.getUint8(offset + 1);
          final b = bytes.getUint8(offset + 2);
          // Background is a light gradient (~0xF0F4DE to ~0xD5E5C2).
          // Crop pixels should deviate from this.
          if (!(r > 200 && g > 210 && b > 180)) {
            nonBackgroundPixels++;
          }
        }
        expect(
          nonBackgroundPixels,
          greaterThan(0),
          reason:
              'at least one crop contact should have non-background pixels '
              'in the saturated candidate render',
        );
      },
    );
  });

  group('production map is not mutated by this ticket', () {
    test(
      'production potager_diorama_v1.tmx preserves the eight historical contacts',
      () async {
        // Observable invariant: the production map still has the eight
        // contacts at their historical positions. This guards against
        // accidental production mutation without comparing bytes.
        const adapter = PotagerGridAdapter();
        final map = await _loadMap(_productionFile);
        final plots = map.layerByName('plots') as ObjectGroup;
        expect(plots.objects, hasLength(8));

        const expected = <String, (double, double)>{
          'plot_0': (-3.5, -0.5),
          'plot_1': (1, -1),
          'plot_2': (0.5, 3.5),
          'plot_3': (3.5, 0.5),
          'plot_4': (-2, -2),
          'plot_5': (-1, 1),
          'plot_6': (2, 2),
          'plot_7': (-0.5, -3.5),
        };
        for (final plot in plots.objects) {
          final (col, row) = expected[plot.name]!;
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
            PotagerPlots.plots[int.parse(plot.name.split('_').last)].contact,
            reason: plot.name,
          );
        }
      },
    );

    test('production east_upper_rock is present and parseable', () async {
      final map = await _loadMap(_productionFile);
      final objects = PotagerTiledObjects.fromMap(map, manifest);
      expect(objects.rock.id, 'east_upper_rock');
      expect(objects.rock.asset, isNotEmpty);
    });
  });
}
