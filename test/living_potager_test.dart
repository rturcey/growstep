import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/main.dart';
import 'package:growstep/steps/fake_step_provider.dart';

/// GrowstepApp-level acceptance tests for #24: a new game shows a living
/// potager with starter plants, survives a restart, migrates an old save, and
/// supports guided planting in the front-left slot.
void main() {
  testWidgets('une nouvelle partie montre le potager vivant', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Tomate'), findsWidgets);
    expect(find.textContaining('Carotte'), findsWidgets);
    expect(find.textContaining('Choisis'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la reprise conserve les plantes offertes', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = GardenDatabase(NativeDatabase.memory());
    await database.load();
    await database.close();

    final database2 = GardenDatabase(NativeDatabase.memory());
    addTearDown(database2.close);
    await tester.pumpWidget(
      GrowstepApp(database: database2, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Tomate'), findsWidgets);
    expect(find.textContaining('Carotte'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une sauvegarde ancienne préserve ses données', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = GardenDatabase(NativeDatabase.memory());
    await database.save(GardenSnapshot.initial().copyWith(
      florins: 42,
      zones: {
        for (final zone in ZoneType.values)
          zone: List<Plant?>.filled(zone.initialSlots, null),
      },
    ));
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Florins : 42'), findsOneWidget);
    expect(find.textContaining('Choisis'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la plantation guidée utilise l’avant gauche', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Tomate').first);
    await tester.tap(find.text('Tomate').first);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.text('Planter Tomate').first);
    await tester.tap(find.text('Planter Tomate').first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Tomate · Graine germée'), findsOneWidget);
    expect(find.text('0/300 pas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
