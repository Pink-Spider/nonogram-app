// Store screenshot harness.
//
//   ./tool/screenshots.sh
//
// Drives the real widget tree to a handful of chosen states and captures
// each one at the simulator's native resolution, for every supported
// locale. Deliberately does NOT go through bootstrap(): screenshots must
// be deterministic and ad-free, so ads are the no-op service, consent
// never runs, and every puzzle comes from a fixed seed.
import 'package:core_ads/core_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:rules_nonogram/rules_nonogram.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nonogram/app/app.dart';
import 'package:nonogram/app/app_config.dart';
import 'package:nonogram/app/providers.dart';
import 'package:nonogram/features/game/game_controller.dart';

/// Locales to shoot. Must stay in step with the ARB files.
const _locales = ['en', 'ko', 'ja', 'de'];

/// Fixed so a re-shoot produces the same board, which makes it obvious in
/// review when a screenshot changed because the UI changed.
const _seed = 20260909;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in _locales) {
    testWidgets('screenshots — $locale', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.prod()),
          adServiceProvider.overrideWithValue(NoopAdService()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: NonogramApp(locale: Locale(locale)),
        ),
      );
      await tester.pumpAndSettle();

      // iOS needs the Flutter surface converted before it can be read back.
      await binding.convertFlutterSurfaceToImage();

      Future<void> shoot(String name) async {
        await tester.pumpAndSettle();
        await binding.takeScreenshot('$locale-$name');
      }

      // 1. Home: difficulty choice and the daily challenge.
      await shoot('1-home');

      // 2. A board part-way through, with a cell selected so the row /
      //    column / box highlighting is visible.
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startNew(Difficulty.medium, seed: _seed);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      final state = container.read(gameControllerProvider)!;
      final solution = state.puzzle.solution;
      // Solve roughly the top third, so the picture is recognisable but
      // clearly unfinished — that is what the screenshot needs to sell.
      final upTo = (state.board.length * 0.35).round();
      for (var i = 0; i < upTo; i++) {
        if (solution[i] == Cell.filled) controller.tapCell(i);
      }
      await shoot('2-board');

      // 3. The explained hint — the thing rewarded ads are sold against.
      await controller.requestHint();
      await shoot('3-hint');

      // 4. Cross mode: the marks players use to rule cells out.
      final c2 = container.read(gameControllerProvider.notifier);
      c2.toggleCrossMode();
      var crossed = 0;
      for (var i = 0; i < state.board.length && crossed < 8; i++) {
        if (solution[i] != Cell.filled &&
            container.read(gameControllerProvider)!.board[i] == Cell.unknown) {
          c2.tapCell(i);
          crossed++;
        }
      }
      await shoot('4-crosses');

      container.read(gameControllerProvider.notifier).pause();
    });
  }
}
