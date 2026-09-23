import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/main.dart';
import 'package:growstep/steps/fake_step_provider.dart';

void main() {
  testWidgets('le jardin tient dans une fenêtre de référence portrait', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = GardenDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final viewport = tester.getSize(find.byKey(const Key('garden-viewport')));
    expect(viewport.width, 390);
    expect(viewport.height, greaterThanOrEqualTo(560));
    expect(find.text('Growstep'), findsOneWidget);
    expect(find.text('Gérer'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('Gérer')).dy, lessThan(780));
    expect(tester.takeException(), isNull);
  });

  testWidgets('le joueur choisit sa graine offerte et la plante', (
    tester,
  ) async {
    final database = GardenDatabase(NativeDatabase.memory());
    final steps = FakeStepProvider();
    await tester.pumpWidget(GrowstepApp(database: database, steps: steps));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Choisis une graine offerte'), findsOneWidget);
    await tester.ensureVisible(find.text('Tomate'));
    await tester.tap(find.text('Tomate'));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.text('Planter Tomate').first);
    await tester.tap(find.text('Planter Tomate').first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Tomate · Graine germée'), findsOneWidget);
    expect(find.text('0/300 pas'), findsOneWidget);

    for (var step = 0; step < 3; step++) {
      await tester.ensureVisible(find.text('+100'));
      await tester.tap(find.text('+100'));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Tomate · Jeune plant'), findsOneWidget);
    expect(find.text('300/700 pas'), findsOneWidget);
  });

  testWidgets('la récolte groupée montre le gain exact avant confirmation', (
    tester,
  ) async {
    final database = GardenDatabase(NativeDatabase.memory());
    final initial = GardenSnapshot.initial();
    final zones = {
      for (final entry in initial.zones.entries) entry.key: [...entry.value],
    };
    zones[ZoneType.potager]![0] = const Plant(
      species: Species.tomate,
      progressSteps: 1000,
      pendingHarvest: HarvestReward(ordinarySeeds: 2),
    );
    zones[ZoneType.jardinFleuri]![0] = const Plant(
      species: Species.tulipe,
      tier: GrowthTier.brillante,
      progressSteps: 15000,
      pendingHarvest: HarvestReward(ordinarySeeds: 1, brilliantSeeds: 1),
    );
    await database.save(initial.copyWith(zones: zones));
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.text('Récolter 2 plantes'));
    await tester.tap(find.text('Récolter 2 plantes'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Tomate ×2'), findsWidgets);
    expect(find.textContaining('Tulipe brillante ×1'), findsWidgets);
    expect(find.textContaining('17 florins'), findsOneWidget);

    await tester.tap(find.text('Confirmer la récolte'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Récolter 2 plantes'), findsNothing);
    expect(find.textContaining('Tomate ×2'), findsWidgets);
    expect(find.textContaining('Tulipe brillante ×1'), findsWidgets);
    expect(find.textContaining('Florins : 17'), findsOneWidget);
  });

  testWidgets('le joueur applique un engrais et voit le compteur accélérer', (
    tester,
  ) async {
    final database = GardenDatabase(NativeDatabase.memory());
    final initial = GardenSnapshot.initial();
    final zones = {
      for (final entry in initial.zones.entries) entry.key: [...entry.value],
    };
    zones[ZoneType.potager] = [
      const Plant(species: Species.tomate),
      null,
      null,
      null,
    ];
    await database.save(
      initial.copyWith(
        zones: zones,
        starterFertilizerGranted: true,
        fertilizers: {FertilizerType.basique: 1},
      ),
    );
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.text('Engrais basique ×1'));
    await tester.tap(find.text('Engrais basique ×1'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.textContaining('Engrais actif : Basique ×1,25'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('+100'));
    await tester.tap(find.text('+100'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('125/300 pas'), findsOneWidget);
  });
}
