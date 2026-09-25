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

/// Acceptance tests for #67: candidate capture seam + contact guard.
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
/// - production `potager.tmx` is not mutated by this ticket (observable
///   invariants, not a tautological byte comparison).

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
const _productionFile = 'potager.tmx';

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
          (candidate.width, candidate.height, candidate.tileWidth,
              candidate.tileHeight),
          (production.width, production.height, production.tileWidth,
              production.tileHeight),
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
        expect(
          plots.objects.map((o) => o.name).toSet(),
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
        }
      },
    );

    test('candidate preserves layer order and tileset count', () async {
      final candidate = await _loadMap(_candidateFile);
      final production = await _loadMap(_productionFile);
      expect(
        candidate.layers.map((l) => l.name).toList(),
        production.layers.map((l) => l.name).toList(),
      );
      expect(candidate.tilesets, hasLength(production.tilesets.length));
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
      // The rock's gridCol/gridRow match production exactly (values may
      // change as the production map evolves; the candidate must follow).
      final prodMap = await _loadMap(_productionFile);
      final prodRock = (prodMap.layerByName('props') as ObjectGroup)
          .objects
          .singleWhere((object) => object.name == 'east_upper_rock');
      expect(
        rock.properties.getValue<double>('gridCol'),
        prodRock.properties.getValue<double>('gridCol'),
      );
      expect(
        rock.properties.getValue<double>('gridRow'),
        prodRock.properties.getValue<double>('gridRow'),
      );
    });

    test('candidate tile layers contain only 80x40 surface tiles', () async {
      final map = await _loadMap(_candidateFile);
      final allowed = {
        'ground': RegExp(r'^commun_sol_(herbe|terre|bordure_herbe)_tile_'),
        'skirt': RegExp(r'^commun_sol_tranche_terre_tile_'),
        'path': RegExp(r'^commun_sol_pas_pierre_tile_'),
      };
      for (final name in ['ground', 'skirt', 'path']) {
        final layer = map.layerByName(name) as TileLayer;
        for (final gid in layer.data!.where((gid) => gid != 0)) {
          final image = map.tileByGid(gid)?.image;
          expect(image, isNotNull, reason: '$name gid $gid');
          expect(
            (image!.width, image.height),
            (80, 40),
            reason: '$name gid $gid',
          );
          expect(
            image.source!.split('/').last,
            matches(allowed[name]!),
            reason: '$name gid $gid',
          );
        }
      }
    });
  });

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

    test(
      'candidate and production produce identical PotagerTiledObjects',
      () async {
        final candidate = await _loadMap(_candidateFile);
        final production = await _loadMap(_productionFile);
        final c = PotagerTiledObjects.fromMap(candidate, manifest);
        final p = PotagerTiledObjects.fromMap(production, manifest);

        expect(c.plotContacts, p.plotContacts);
        expect(c.rock.id, p.rock.id);
        expect(c.rock.asset, p.rock.asset);
        expect(c.rock.contact, p.rock.contact);
        expect(c.rock.size, p.rock.size);
        expect(c.rock.opacity, p.rock.opacity);
        expect(c.rockAnchorDelta, p.rockAnchorDelta);
        expect(c.sceneObjects.length, p.sceneObjects.length);
        for (var i = 0; i < c.sceneObjects.length; i++) {
          expect(c.sceneObjects[i].id, p.sceneObjects[i].id,
              reason: 'scene object $i');
          expect(c.sceneObjects[i].asset, p.sceneObjects[i].asset,
              reason: 'scene object $i');
          expect(c.sceneObjects[i].contact, p.sceneObjects[i].contact,
              reason: 'scene object $i');
          expect(c.sceneObjects[i].size, p.sceneObjects[i].size,
              reason: 'scene object $i');
          expect(c.sceneObjects[i].opacity, p.sceneObjects[i].opacity,
              reason: 'scene object $i');
        }
      },
    );

    test(
      'candidate contacts are tappable through GardenGame.hitTestSlot',
      () async {
        final snapshot = _saturatedSnapshot();
        final game = GardenGame(potagerMapFile: _candidateFile)
          ..snapshot = snapshot;
        await game.onLoad();
        game.onGameResize(Vector2(390, 844));
        final transform = GardenArtboardTransform(const ui.Size(390, 844));
        for (var slot = 0; slot < 8; slot++) {
          final anchor = GardenGame.anchorsFor(ZoneType.potager)[slot];
          final viewportPoint = transform.toViewport(anchor);
          expect(
            game.hitTestSlot(viewportPoint),
            slot,
            reason: 'slot $slot must be hittable at its contact',
          );
        }
        game.onRemove();
      },
    );
  });

  group('candidate deterministic captures', () {
    test(
      'saturated state renders reproducibly at both phone sizes using the candidate',
      () async {
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
      },
    );

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
      'production potager.tmx preserves the eight historical contacts',
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
