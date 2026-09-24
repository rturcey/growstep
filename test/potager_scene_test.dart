import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_game.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/main.dart';
import 'package:growstep/steps/fake_step_provider.dart';

/// Acceptance tests for #23: a complete, playable potager island rendered at a
/// fixed apparent scale on both reference and small phone sizes. The scene uses
/// one island at a time (no lateral camera), the zone name lives in the Flutter
/// UI, and tapping a planting location selects it through the 80 × 40 anchors.
void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool allPotagerSlots = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    if (allPotagerSlots) {
      final initial = await database.load();
      await database.save(
        initial.copyWith(
          zones: {
            ...initial.zones,
            ZoneType.potager: List<Plant?>.filled(
              ZoneType.potager.maxSlots,
              null,
            ),
          },
        ),
      );
    }
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Screen position of a scene anchor, accounting for the fixed 1.0 scale and
  /// the centered 390 × 450 canvas origin.
  Offset slotScreen(WidgetTester tester, Offset sceneAnchor) {
    final topLeft = tester.getTopLeft(find.byKey(const Key('garden-viewport')));
    final viewport = tester.getSize(find.byKey(const Key('garden-viewport')));
    final origin = Offset(
      (viewport.width - 390) / 2,
      (viewport.height - 450) / 2,
    );
    return topLeft + origin + sceneAnchor;
  }

  testWidgets("l'îlot potager est cadré et un emplacement est sélectionnable", (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(390, 844));

    final viewport = tester.getSize(find.byKey(const Key('garden-viewport')));
    expect(viewport.width, 390);
    expect(viewport.height, greaterThanOrEqualTo(560));
    // The zone name lives in the Flutter UI, not on an in-world title board.
    expect(find.text('Potager'), findsWidgets);
    expect(find.text('Votre potager'), findsOneWidget);

    // Tap the front-left planting location (stable anchor 75, 310).
    await tester.tapAt(slotScreen(tester, const Offset(75, 310)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Emplacement 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "le cadrage et l'interaction restent valables sur le petit écran",
    (tester) async {
      await pumpApp(tester, size: const Size(375, 667));

      final viewport = tester.getSize(find.byKey(const Key('garden-viewport')));
      expect(viewport.width, 375);
      expect(viewport.height, greaterThanOrEqualTo(430));
      expect(find.text('Potager'), findsWidgets);

      await tester.tapAt(slotScreen(tester, const Offset(75, 310)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Emplacement 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("le changement de taille préserve le cadrage", (tester) async {
    await pumpApp(tester, size: const Size(390, 844));
    final large = tester.getSize(find.byKey(const Key('garden-viewport')));
    expect(large.width, 390);

    await tester.binding.setSurfaceSize(const Size(375, 667));
    await tester.pump(const Duration(milliseconds: 300));

    final small = tester.getSize(find.byKey(const Key('garden-viewport')));
    expect(small.width, 375);
    // The island and its Flutter controls remain present without exception.
    expect(find.text('Potager'), findsWidgets);
    expect(find.text('Gérer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(375, 667)]) {
    testWidgets('les huit contacts historiques restent tapables à $size', (
      tester,
    ) async {
      await pumpApp(tester, size: size, allPotagerSlots: true);
      for (final (index, contact) in GardenGame.anchorsFor(
        ZoneType.potager,
      ).indexed) {
        await tester.tapAt(slotScreen(tester, contact));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Emplacement ${index + 1}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
