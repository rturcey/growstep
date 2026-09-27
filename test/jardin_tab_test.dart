import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/main.dart';
import 'package:growstep/steps/fake_step_provider.dart';

/// Acceptance tests for #76 : l'onglet Jardin — sélection de zone via le
/// segmented control, dialogue d'achat d'îlot verrouillé, plantation d'une
/// graine offerte et récolte individuelle.
void main() {
  Future<void> pumpApp(WidgetTester tester, {GardenSnapshot? initial}) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.save(initial ?? GardenSnapshot.initial());
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('un îlot verrouillé affiche son prix et ouvre le dialogue d’achat', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('250 florins'), findsOneWidget);
    await tester.tap(find.text('Verger'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Acheter Verger ?'), findsOneWidget);
    expect(find.text('Prix : 250 florins'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Prix : 250 florins'), findsNothing);
  });

  testWidgets('acheter un îlot débloque la sélection et la plantation de sa graine offerte', (
    tester,
  ) async {
    await pumpApp(tester, initial: GardenSnapshot.initial().copyWith(florins: 300));
    await tester.tap(find.text('Jardin fleuri'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Acheter'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Choisis ta graine offerte'), findsWidgets);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Tournesol'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tournesol'));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.text('Planter Tournesol').first);
    await tester.tap(find.text('Planter Tournesol').first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Tournesol · Graine germée'), findsOneWidget);
  });

  testWidgets('récolter une plante mature libère son emplacement', (tester) async {
    final initial = GardenSnapshot.initial();
    final zones = {
      for (final entry in initial.zones.entries) entry.key: [...entry.value],
    };
    zones[ZoneType.potager]![0] = const Plant(
      species: Species.tomate,
      progressSteps: 1000,
      pendingHarvest: HarvestReward(ordinarySeeds: 1),
    );
    await pumpApp(tester, initial: initial.copyWith(zones: zones));

    await tester.ensureVisible(find.text('Récolter').first);
    await tester.tap(find.text('Récolter').first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Récolter'), findsNothing);
  });
}
