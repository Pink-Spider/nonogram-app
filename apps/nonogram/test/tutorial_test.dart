import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonogram/app/app.dart';
import 'package:nonogram/app/providers.dart';
import 'package:nonogram/features/game/widgets/nonogram_board.dart';

import 'test_overrides.dart';

void main() {
  testWidgets('first run opens the tutorial; skip lands on home and sticks',
      (tester) async {
    final overrides = await testOverrides(tutorialDone: false);
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const NonogramApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('How to play'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Daily challenge'), findsOneWidget);
  });

  testWidgets('tutorial does not reappear once done', (tester) async {
    final overrides = await testOverrides();
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const NonogramApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('How to play'), findsNothing);
    expect(find.text('Daily challenge'), findsOneWidget);
  });

  testWidgets('guided steps walk the heart to completion', (tester) async {
    final overrides = await testOverrides(tutorialDone: false);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const NonogramApp();
        }),
      ),
    );
    await tester.pumpAndSettle();

    // Drive the board through its public callbacks — the same entry point
    // real taps use, minus the coordinate arithmetic.
    void tap(int index) =>
        tester.widget<NonogramBoard>(find.byType(NonogramBoard)).onCellTap(index);

    Future<void> tapAll(List<int> cells) async {
      for (final i in cells) {
        tap(i);
        await tester.pump();
      }
    }

    expect(find.textContaining('A 5 means all five'), findsOneWidget);

    // A wrong cell is refused with a nudge, not applied.
    tap(0);
    await tester.pump();
    expect(find.textContaining('Not that square'), findsOneWidget);

    await tapAll([5, 6, 7, 8, 9]);
    expect(find.textContaining('This row is a 5 as well'), findsOneWidget);

    await tapAll([10, 11, 12, 13, 14]);
    expect(find.textContaining('Squares that stay empty'), findsOneWidget);

    await tapAll([20, 21, 23, 24]); // cross mode is scripted on this step
    expect(find.textContaining('finish the rest yourself'), findsOneWidget);

    await tapAll([1, 3, 16, 17, 18, 22]);
    await tester.pumpAndSettle();
    expect(find.textContaining('A heart!'), findsOneWidget);

    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    expect(find.text('Daily challenge'), findsOneWidget);
    expect(container.read(gamePersistenceProvider).isTutorialDone, isTrue);
  });
}
