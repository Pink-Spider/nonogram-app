import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:rules_nonogram/rules_nonogram.dart';
import 'package:test/test.dart';

void main() {
  group('determinism — the daily puzzle depends on this', () {
    test('same seed and difficulty gives the same picture', () {
      for (final d in Difficulty.values) {
        final a = NonogramGenerator.generate(difficulty: d, seed: 20260914);
        final b = NonogramGenerator.generate(difficulty: d, seed: 20260914);
        expect(a.solution, b.solution, reason: d.name);
        expect(a.extras['shapeId'], b.extras['shapeId'], reason: d.name);
        expect(a.id, b.id, reason: d.name);
      }
    });

    test('different seeds spread across the library', () {
      final ids = <String>{};
      for (var seed = 0; seed < 40; seed++) {
        final p = NonogramGenerator.generate(
          difficulty: Difficulty.medium,
          seed: seed,
        );
        ids.add(p.extras['shapeId']! as String);
      }
      // Not every shape necessarily appears, but a single one would mean
      // the seed is being ignored.
      expect(ids.length, greaterThan(1));
    });
  });

  group('board shape', () {
    test('size follows the difficulty tier', () {
      expect(NonogramGenerator.sizeFor(Difficulty.easy), 5);
      expect(NonogramGenerator.sizeFor(Difficulty.medium), 10);
      expect(NonogramGenerator.sizeFor(Difficulty.hard), 15);
      expect(NonogramGenerator.sizeFor(Difficulty.expert), 20);
    });

    test('starts empty — the clues are the givens', () {
      final p = NonogramGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 1,
      );
      expect(p.givens.every((v) => v == Cell.unknown), isTrue);
      expect(p.givenCount, 0);
    });

    test('carries clues sized to the board', () {
      for (final d in Difficulty.values) {
        final p = NonogramGenerator.generate(difficulty: d, seed: 7);
        expect(NonogramGenerator.rowCluesOf(p).length, p.size, reason: d.name);
        expect(NonogramGenerator.colCluesOf(p).length, p.size, reason: d.name);
      }
    });

    test('clues match the solution they were read from', () {
      final p = NonogramGenerator.generate(
        difficulty: Difficulty.medium,
        seed: 3,
      );
      final expected = NonogramSolver.cluesFor(
        p.solution,
        width: p.size,
        height: p.size,
      );
      expect(NonogramGenerator.rowCluesOf(p), expected.rows);
      expect(NonogramGenerator.colCluesOf(p), expected.cols);
    });
  });

  group('solvability', () {
    test('every generated puzzle solves by logic alone', () {
      for (final d in Difficulty.values) {
        for (var seed = 0; seed < 8; seed++) {
          final p = NonogramGenerator.generate(difficulty: d, seed: seed);
          final result = NonogramSolver(
            rowClues: NonogramGenerator.rowCluesOf(p),
            colClues: NonogramGenerator.colCluesOf(p),
          ).solve();
          expect(result.solved, isTrue, reason: '${d.name} seed $seed');
          expect(result.hardest, isNot(Technique.search),
              reason: '${d.name} seed $seed');
          // The solver marks blanks as crossed; the solution leaves them
          // unknown. Same picture, different notation — compare meaning.
          for (var i = 0; i < p.solution.length; i++) {
            expect(Cell.matchesSolution(result.board[i], p.solution[i]), isTrue,
                reason: '${d.name} seed $seed cell $i');
          }
        }
      }
    });
  });

  group('serialisation — saved games must survive a restart', () {
    test('round-trips through JSON with clues intact', () {
      final p = NonogramGenerator.generate(
        difficulty: Difficulty.hard,
        seed: 99,
      );
      final restored = GridPuzzle.fromJson(p.toJson());
      expect(restored.solution, p.solution);
      expect(NonogramGenerator.rowCluesOf(restored),
          NonogramGenerator.rowCluesOf(p));
      expect(NonogramGenerator.colCluesOf(restored),
          NonogramGenerator.colCluesOf(p));
      expect(NonogramGenerator.shapeOf(restored)?.id,
          NonogramGenerator.shapeOf(p)?.id);
    });
  });

  group('rule behaviour', () {
    test('a finished board is recognised, crosses and blanks alike', () {
      final p = NonogramGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 5,
      );
      // Fill exactly the solution, leave the rest untouched.
      final board = List<int>.from(p.solution);
      expect(NonogramRule.isSolved(board, p), isTrue);

      // Crossing out the blanks must not change the verdict.
      final crossed = [
        for (final v in p.solution) v == Cell.filled ? Cell.filled : Cell.crossed
      ];
      expect(NonogramRule.isSolved(crossed, p), isTrue);
    });

    test('a wrong fill is not solved', () {
      final p = NonogramGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 5,
      );
      final board = List<int>.from(p.solution);
      final blank = board.indexOf(Cell.unknown);
      board[blank] = Cell.filled;
      expect(NonogramRule.isSolved(board, p), isFalse);
    });

    test('hints only ever state something logic forces', () {
      final p = NonogramGenerator.generate(
        difficulty: Difficulty.medium,
        seed: 11,
      );
      final rule = NonogramRule(size: p.size);
      final board = List<int>.filled(p.size * p.size, Cell.unknown);

      var given = 0;
      while (given < 40) {
        final hint = rule.nextHint(board, p);
        if (hint == null) break;
        final wantsFill = hint.value == Cell.filled;
        final isFilled = p.solution[hint.index] == Cell.filled;
        expect(wantsFill, isFilled,
            reason: 'hint ${hint.techniqueId} contradicts the picture');
        board[hint.index] = hint.value;
        given++;
      }
      expect(given, greaterThan(0), reason: 'no hint on an empty board');
    });

    test('crossing a blank counts as correct, not a mistake', () {
      final p = NonogramGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 5,
      );
      final rule = NonogramRule(size: p.size);
      final blank = p.solution.indexOf(Cell.unknown);
      final filled = p.solution.indexOf(Cell.filled);

      expect(rule.isCorrect(blank, Cell.crossed, p.solution), isTrue);
      expect(rule.isCorrect(filled, Cell.filled, p.solution), isTrue);
      // ...and the two ways to be wrong
      expect(rule.isCorrect(blank, Cell.filled, p.solution), isFalse);
      expect(rule.isCorrect(filled, Cell.crossed, p.solution), isFalse);
    });

    test('peers are the row and column through the cell', () {
      const rule = NonogramRule(size: 5);
      final peers = rule.peers(12); // row 2, col 2
      expect(peers.length, 8); // 4 in the row + 4 in the column
      expect(peers, isNot(contains(12)));
      expect(peers, containsAll([10, 11, 13, 14])); // row 2
      expect(peers, containsAll([2, 7, 17, 22])); // col 2
    });
  });
}
