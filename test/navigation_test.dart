import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/main.dart';
import 'package:growstep/steps/fake_step_provider.dart';

void main() {
  late GardenDatabase database;
  late FakeStepProvider steps;

  setUp(() {
    database = GardenDatabase(NativeDatabase.memory());
    steps = FakeStepProvider();
  });

  tearDown(() => database.close);

  Future<void> pumpApp(WidgetTester tester, {int initialIndex = 0}) async {
    await tester.pumpWidget(GrowstepApp(
      database: database,
      steps: steps,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('affiche trois onglets dans la bottom navigation', (tester) async {
    await pumpApp(tester);
    expect(find.text('Jardin'), findsWidgets);
    expect(find.text('Boutique'), findsWidgets);
    expect(find.text('Pauses'), findsWidgets);
  });

  testWidgets('onglet Jardin est sélectionné par défaut', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('garden-viewport')), findsOneWidget);
  });

  testWidgets('le panneau dev +100 pas est visible avec FakeStepProvider', (tester) async {
    await pumpApp(tester);
    expect(find.text('+100'), findsOneWidget);
  });

  testWidgets('le bouton +100 incrémente les pas', (tester) async {
    await pumpApp(tester);
    expect(find.text('0 pas'), findsWidgets);
    await tester.tap(find.text('+100'));
    await tester.pumpAndSettle();
    expect(find.text('100 pas'), findsWidgets);
  });

  testWidgets('navigue vers l\'onglet Boutique', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Boutique'));
    await tester.pumpAndSettle();
    expect(find.text('Boutique'), findsWidgets);
  });

  testWidgets('navigue vers l\'onglet Pauses', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Pauses'));
    await tester.pumpAndSettle();
    expect(find.text('Pauses'), findsWidgets);
  });

  testWidgets('le compteur de pas est visible dans l\'onglet Jardin', (tester) async {
    await pumpApp(tester);
    expect(find.text('0 pas'), findsWidgets);
  });

  testWidgets('le compteur de pas est visible dans l\'onglet Pauses', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Pauses'));
    await tester.pumpAndSettle();
    expect(find.text('0 pas'), findsWidgets);
  });

  testWidgets('le solde de florins est visible dans tous les onglets', (tester) async {
    await pumpApp(tester);
    expect(find.textContaining('Florins'), findsWidgets);
    await tester.tap(find.text('Boutique'));
    await tester.pumpAndSettle();
    expect(find.textContaining('florin'), findsWidgets);
  });
}
