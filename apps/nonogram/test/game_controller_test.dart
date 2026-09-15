import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonogram/app/providers.dart';
import 'package:nonogram/features/game/game_controller.dart';
import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:rules_nonogram/rules_nonogram.dart';

import 'test_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late GameController controller;

  setUp(() async {
    container = ProviderContainer(overrides: await testOverrides());
    controller = container.read(gameControllerProvider.notifier);
  });

  tearDown(() async {
    await controller.abandon();
    container.dispose();
  });

  GameViewState state() => container.read(gameControllerProvider)!;

  /// First cell the picture fills, and the first it leaves blank.
  int firstFilled() => state().puzzle.solution.indexOf(Cell.filled);
  int firstBlank() => state().puzzle.solution.indexOf(Cell.unknown);

  test('startNew sizes the board from the difficulty', () async {
    await controller.startNew(Difficulty.easy, seed: 1);
    expect(state().board.length, 5 * 5);
    expect(state().status, GameStatus.playing);
    expect(container.read(gamePersistenceProvider).hasSession, isTrue);

    await controller.startNew(Difficulty.medium, seed: 1);
    expect(state().board.length, 10 * 10);
  });

  test('the board starts empty — clues are the only givens', () async {
    await controller.startNew(Difficulty.easy, seed: 1);
    expect(state().board.every((v) => v == Cell.unknown), isTrue);
    expect(NonogramGenerator.rowCluesOf(state().puzzle).length, 5);
    expect(NonogramGenerator.colCluesOf(state().puzzle).length, 5);
  });

  group('tapping', () {
    test('fills, and tapping again clears', () async {
      await controller.startNew(Difficulty.easy, seed: 2);
      final cell = firstFilled();

      controller.tapCell(cell);
      expect(state().board[cell], Cell.filled);

      controller.tapCell(cell);
      expect(state().board[cell], Cell.unknown);
    });

    test('cross mode leaves a cross instead', () async {
      await controller.startNew(Difficulty.easy, seed: 2);
      final cell = firstBlank();

      controller.toggleCrossMode();
      expect(state().crossMode, isTrue);

      controller.tapCell(cell);
      expect(state().board[cell], Cell.crossed);
    });

    test('crossing a genuinely blank cell is not a mistake', () async {
      await controller.startNew(Difficulty.easy, seed: 2);
      controller.toggleCrossMode();
      controller.tapCell(firstBlank());
      // The whole point of the isCorrect hook: crossing is how people
      // solve nonograms, and must not burn the mistake budget.
      expect(state().mistakes, 0);
    });

    test('filling a blank cell is a mistake and gets flagged', () async {
      await controller.startNew(Difficulty.easy, seed: 2);
      final cell = firstBlank();

      controller.tapCell(cell);
      expect(state().mistakes, 1);
      expect(state().mistakeCells, contains(cell));
    });

    test('crossing a cell that should be filled costs a mistake but is not '
        'drawn — showing it would give the answer away', () async {
      await controller.startNew(Difficulty.easy, seed: 2);
      final cell = firstFilled();

      controller.toggleCrossMode();
      controller.tapCell(cell);
      expect(state().mistakes, 1);
      expect(state().mistakeCells, isNot(contains(cell)));
    });
  });

  group('dragging', () {
    test('paints across cells', () async {
      await controller.startNew(Difficulty.medium, seed: 3);
      final s = state();
      final targets = [
        for (var i = 0; i < s.puzzle.cellCount; i++)
          if (s.puzzle.solution[i] == Cell.filled) i,
      ].take(4).toList();

      for (final i in targets) {
        controller.dragCell(i);
      }
      for (final i in targets) {
        expect(state().board[i], Cell.filled);
      }
    });

    test('does not toggle a cell it passes over twice', () async {
      await controller.startNew(Difficulty.easy, seed: 3);
      final cell = firstFilled();

      controller.dragCell(cell);
      controller.dragCell(cell);
      // A drag that flickered cells off would make painting unusable.
      expect(state().board[cell], Cell.filled);
    });
  });

  test('hints only state what the clues force', () async {
    await controller.startNew(Difficulty.medium, seed: 4);
    final before = state().board.where(Cell.isDecided).length;

    final outcome = await controller.requestHint();
    expect(outcome, HintOutcome.applied);

    final s = state();
    expect(s.board.where(Cell.isDecided).length, greaterThan(before));
    expect(s.lastHint, isNotNull);
    final hint = s.lastHint!;
    expect(
      Cell.matchesSolution(s.board[hint.index], s.puzzle.solution[hint.index]),
      isTrue,
    );
  });

  test('undo steps back', () async {
    await controller.startNew(Difficulty.easy, seed: 5);
    final cell = firstFilled();

    controller.tapCell(cell);
    expect(state().board[cell], Cell.filled);

    controller.undo();
    expect(state().board[cell], Cell.unknown);
  });

  test('completing the picture solves it, crosses optional', () async {
    await controller.startNew(Difficulty.easy, seed: 6);
    final solution = List<int>.from(state().puzzle.solution);

    for (var i = 0; i < solution.length; i++) {
      if (solution[i] == Cell.filled) controller.tapCell(i);
    }

    expect(state().status, GameStatus.solved);
  });

  test('crosses left on blank cells do not block completion', () async {
    await controller.startNew(Difficulty.easy, seed: 6);
    final solution = List<int>.from(state().puzzle.solution);

    // Cross a few genuinely blank cells first — solving with X marks on
    // the board is how the game is actually played, and the win must not
    // require erasing them (regression: isSolved compared board ==
    // solution exactly, so any X held the win hostage).
    controller.toggleCrossMode();
    final blanks = [
      for (var i = 0; i < solution.length; i++)
        if (solution[i] != Cell.filled) i,
    ];
    for (final i in blanks.take(3)) {
      controller.tapCell(i);
    }
    controller.toggleCrossMode();

    for (var i = 0; i < solution.length; i++) {
      if (solution[i] == Cell.filled) controller.tapCell(i);
    }

    expect(state().board.where((v) => v == Cell.crossed).length, 3);
    expect(state().status, GameStatus.solved);
  });

  test('resume restores a saved session with its clues', () async {
    await controller.startNew(Difficulty.medium, seed: 7);
    final cell = firstFilled();
    controller.tapCell(cell);
    final expected = state().puzzle.id;

    // Reuse the same overrides — a second testOverrides() call would wipe
    // SharedPreferences and there would be nothing left to resume.
    final fresh = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(container.read(appConfigProvider)),
      adServiceProvider.overrideWithValue(container.read(adServiceProvider)),
      sharedPreferencesProvider
          .overrideWithValue(container.read(sharedPreferencesProvider)),
    ]);
    addTearDown(fresh.dispose);
    final restored = fresh.read(gameControllerProvider.notifier);
    expect(restored.resume(), isTrue);

    final s = fresh.read(gameControllerProvider)!;
    expect(s.puzzle.id, expected);
    expect(s.board[cell], Cell.filled);
    // Clues must survive the round trip or the board cannot be drawn.
    expect(NonogramGenerator.rowCluesOf(s.puzzle), isNotEmpty);
  });
}
