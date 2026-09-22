import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/main.dart';
import 'package:growstep/steps/fake_step_provider.dart';

void main() {
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
}
