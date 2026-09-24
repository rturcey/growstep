import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/main.dart';
import 'package:growstep/steps/fake_step_provider.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(375, 667)]) {
    for (final zone in ZoneType.values) {
      testWidgets('${zone.label} : contact et index conservés à $size', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final initial = await database.load();
        await database.save(
          initial.copyWith(
            zones: {
              for (final currentZone in ZoneType.values)
                currentZone: List<Plant?>.filled(currentZone.maxSlots, null),
            },
            ownedZones: ZoneType.values.toSet(),
          ),
        );
        await tester.pumpWidget(
          GrowstepApp(
            database: database,
            steps: FakeStepProvider(),
            initialZone: zone,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final viewportFinder = find.byKey(const Key('garden-viewport'));
        final topLeft = tester.getTopLeft(viewportFinder);
        final viewport = tester.getSize(viewportFinder);
        expect(viewport.width, size.width);
        final origin = Offset(
          (viewport.width - 390) / 2,
          (viewport.height - 450) / 2,
        );

        // Every saved index must still select its own visible contact after
        // the scene geometry changes, including the added locations.
        for (final (index, anchor) in GardenGame.anchorsFor(zone).indexed) {
          await tester.tapAt(topLeft + origin + anchor);
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.text('Emplacement ${index + 1}'), findsOneWidget);
        }
      });
    }
  }
}
