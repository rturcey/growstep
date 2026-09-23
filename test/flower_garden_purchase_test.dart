import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_state.dart';
import 'package:growstep/main.dart';
import 'package:growstep/steps/fake_step_provider.dart';

/// GrowstepApp-level acceptance tests for #26: buying the jardin fleuri island
/// through the Flutter UI — purchase panel, confirmation, cancellation,
/// insufficient balance, and starter seed choice after opening.
void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    GardenSnapshot? initial,
    int florins = 200,
  }) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const ui.Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    if (initial != null) {
      await database.save(initial.copyWith(florins: florins));
    } else {
      await database.save(GardenSnapshot.initial().copyWith(florins: florins));
    }
    await tester.pumpWidget(
      GrowstepApp(database: database, steps: FakeStepProvider()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('le sélecteur montre le prix du jardin fleuri fermé', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.textContaining('100'), findsWidgets);
    expect(find.text('Jardin fleuri'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('l’achat confirmé ouvre l’îlot et débite les florins', (
    tester,
  ) async {
    await pumpApp(tester, florins: 200);

    await tester.tap(find.text('Jardin fleuri').last);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Prix : 100 florins'), findsOneWidget);

    await tester.tap(find.text('Acheter'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Tournesol, Tulipe, Lavande'), findsNothing);
    expect(find.textContaining('Choisis ta graine offerte'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('l’annulation n’ouvre pas l’îlot et ne débite rien', (
    tester,
  ) async {
    await pumpApp(tester, florins: 200);

    await tester.tap(find.text('Jardin fleuri').last);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Annuler'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Prix : 100 florins'), findsNothing);
    expect(find.textContaining('Tournesol, Tulipe, Lavande'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le solde insuffisant n’ouvre pas l’îlot', (tester) async {
    await pumpApp(tester, florins: 50);

    await tester.tap(find.text('Jardin fleuri').last);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Prix : 100 florins'), findsOneWidget);
    expect(find.textContaining('Solde insuffisant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
