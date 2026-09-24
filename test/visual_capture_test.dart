import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_state.dart';

const captureDirectory = String.fromEnvironment('GROWSTEP_CAPTURE_DIR');

GardenSnapshot _fixture(String state) {
  final initial = GardenSnapshot.initial();
  if (state == 'initial') {
    return initial.copyWith(ownedZones: ZoneType.values.toSet());
  }

  if (state == 'intermediaire') {
    Plant young(Species species) {
      final seed = Plant(species: species);
      return Plant(
        species: species,
        progressSteps: seed.stageThresholds.first + 1,
      );
    }

    final zones = {
      for (final zone in ZoneType.values)
        zone: List<Plant?>.filled(zone.maxSlots, null),
    };
    // Intermediate state: 6 purchased potager slots (not the full 8).
    zones[ZoneType.potager] = List<Plant?>.filled(6, null);
    zones[ZoneType.potager]![0] = young(Species.tomate);
    zones[ZoneType.potager]![1] = young(Species.carotte);
    zones[ZoneType.potager]![2] = young(Species.courgette);
    zones[ZoneType.jardinFleuri]![0] = young(Species.tournesol);
    zones[ZoneType.jardinFleuri]![1] = young(Species.tulipe);
    zones[ZoneType.jardinFleuri]![2] = young(Species.lavande);
    zones[ZoneType.verger]![0] = young(Species.pommier);
    zones[ZoneType.verger]![1] = young(Species.poirier);
    return initial.copyWith(zones: zones, ownedZones: ZoneType.values.toSet());
  }

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
  return initial.copyWith(zones: zones, ownedZones: ZoneType.values.toSet());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('captures déterministes des trois îlots', () async {
    final output = Directory(captureDirectory)..createSync(recursive: true);
    for (final viewport in [
      (screen: '390x844', width: 390, height: 450),
      (screen: '375x667', width: 375, height: 380),
    ]) {
      for (final state in ['initial', 'intermediaire', 'sature']) {
        for (final zone in ZoneType.values) {
          final game = GardenGame()
            ..snapshot = _fixture(state)
            ..currentZone = zone;
          await game.onLoad();
          game.onGameResize(
            Vector2(viewport.width.toDouble(), viewport.height.toDouble()),
          );
          for (final grayscale in [false, true]) {
            final recorder = ui.PictureRecorder();
            final canvas = ui.Canvas(recorder);
            if (grayscale) {
              canvas.saveLayer(
                ui.Rect.fromLTWH(
                  0,
                  0,
                  viewport.width.toDouble(),
                  viewport.height.toDouble(),
                ),
                ui.Paint()
                  ..colorFilter = const ui.ColorFilter.matrix([
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
              );
            }
            game.render(canvas);
            if (grayscale) canvas.restore();
            final picture = recorder.endRecording();
            final image = await picture.toImage(
              viewport.width,
              viewport.height,
            );
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            picture.dispose();
            if (bytes == null) throw StateError('La capture PNG est vide');
            final suffix = grayscale ? '_gris' : '';
            final name = '${zone.name}_${state}_${viewport.screen}$suffix.png';
            File('${output.path}/$name')
                .writeAsBytesSync(bytes.buffer.asUint8List());
          }
          game.onRemove();
        }
      }
    }
  }, skip: captureDirectory.isEmpty);
}
