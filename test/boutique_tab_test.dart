import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/main.dart';
import 'package:growstep/steps/fake_step_provider.dart';

/// Acceptance tests for #77 : l'onglet Boutique & Récompenses — achat de
/// graines, engrais et décors, solde insuffisant, suppression de graines et
/// paliers quotidiens en lecture seule.
void main() {
  Future<void> pumpBoutique(WidgetTester tester, {GardenSnapshot? initial}) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.save(initial ?? GardenSnapshot.initial().copyWith(florins: 200));
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Boutique'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('les trois raretés de graines affichent leur prix', (tester) async {
    await pumpBoutique(tester);
    expect(find.text('Graine commune'), findsOneWidget);
    expect(find.text('Graine peu commune'), findsOneWidget);
    expect(find.text('Graine rare'), findsOneWidget);
    expect(find.text('5 florins'), findsOneWidget);
    expect(find.text('60 florins'), findsOneWidget);
  });

  testWidgets('acheter une graine débite les florins et met à jour le stock', (
    tester,
  ) async {
    await pumpBoutique(tester);
    expect(find.text('200 florins'), findsOneWidget);
    await tester.tap(find.text('Acheter graine commune'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('195 florins'), findsOneWidget);
    await tester.ensureVisible(find.text('Tomate ×1'));
    expect(find.text('Tomate ×1'), findsOneWidget);
  });

  testWidgets('acheter un engrais et un décor incrémente l’inventaire', (
    tester,
  ) async {
    await pumpBoutique(tester);
    await tester.ensureVisible(find.text('Acheter engrais Basique'));
    await tester.tap(find.text('Acheter engrais Basique'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Acheter Arrosoir'));
    await tester.tap(find.text('Acheter Arrosoir'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Arrosoir ×1'));
    expect(find.text('Arrosoir ×1'), findsOneWidget);
    expect(find.textContaining('en stock : 1'), findsWidgets);
  });

  testWidgets('un solde insuffisant refuse l’achat avec un message clair', (
    tester,
  ) async {
    await pumpBoutique(
      tester,
      initial: GardenSnapshot.initial().copyWith(florins: 3),
    );
    await tester.tap(find.text('Acheter graine commune'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Pas assez de florins pour cet achat.'), findsOneWidget);
  });

  testWidgets('les paliers quotidiens affichent seuil, chance et état', (
    tester,
  ) async {
    await pumpBoutique(
      tester,
      initial: GardenSnapshot.initial().copyWith(
        florins: 200,
        creditedSteps: 3000,
        creditedDay: localDayKey(DateTime.now()),
      ),
    );
    expect(find.text('Palier 1000 pas'), findsOneWidget);
    expect(find.text('Palier 3000 pas'), findsOneWidget);
    expect(find.text('Palier 6000 pas'), findsOneWidget);
    expect(find.text('Palier 10000 pas'), findsOneWidget);
    expect(find.text('Chance de graine brillante : 2 %'), findsOneWidget);
    expect(find.text('Chance de graine brillante : 3 %'), findsOneWidget);
    expect(find.text('Chance de graine brillante : 4 %'), findsOneWidget);
    expect(find.text('Chance de graine brillante : 5 %'), findsOneWidget);
    expect(find.text('Atteint'), findsNWidgets(2));
    expect(find.text('Non atteint'), findsNWidgets(2));
  });

  testWidgets('supprimer une graine excédentaire réduit le stock', (tester) async {
    await pumpBoutique(
      tester,
      initial: GardenSnapshot.initial().copyWith(
        florins: 200,
        seeds: {Species.tomate: 2},
      ),
    );
    await tester.ensureVisible(find.text('Tomate ×2'));
    await tester.tap(find.text('Supprimer'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Tomate ×2'), findsNothing);
    expect(find.text('Tomate ×1'), findsOneWidget);
  });
}
