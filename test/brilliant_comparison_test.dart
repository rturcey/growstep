import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_state.dart';

const captureDirectory = String.fromEnvironment('GROWSTEP_CAPTURE_DIR');

Future<List<int>> _render(Species species, GrowthTier tier) async {
  final initial = GardenSnapshot.initial();
  final zones = {
    for (final entry in initial.zones.entries)
      entry.key: List<Plant?>.filled(entry.value.length, null),
  };
  zones[species.zone]![0] = Plant(
    species: species,
    tier: tier,
    progressSteps: tier.stepsToMature,
  );
  final game = GardenGame()
    ..snapshot = initial.copyWith(
      zones: zones,
      ownedZones: ZoneType.values.toSet(),
    )
    ..currentZone = species.zone;
  await game.onLoad();
  game.onGameResize(Vector2(390, 450));
  final recorder = ui.PictureRecorder();
  game.render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(390, 450);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  game.onRemove();
  if (bytes == null) throw StateError('La capture PNG est vide');
  return bytes.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('comparaisons ordinaires et brillantes pour les huit espèces', () async {
    final output = Directory(captureDirectory)..createSync(recursive: true);
    for (final species in Species.values) {
      final ordinary = await _render(species, GrowthTier.commune);
      final brilliant = await _render(species, GrowthTier.brillante);
      expect(brilliant, isNot(equals(ordinary)), reason: species.name);
      File('${output.path}/comparaison_${species.name}_ordinaire.png')
          .writeAsBytesSync(ordinary);
      File('${output.path}/comparaison_${species.name}_brillante.png')
          .writeAsBytesSync(brilliant);
    }
  }, skip: captureDirectory.isEmpty);
}
