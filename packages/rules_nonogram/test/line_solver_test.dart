import 'package:rules_nonogram/rules_nonogram.dart';
import 'package:test/test.dart';

/// Shorthand: '.' unknown, '#' filled, 'x' crossed.
List<int> line(String s) => s
    .split('')
    .map((c) => switch (c) {
          '#' => Cell.filled,
          'x' => Cell.crossed,
          _ => Cell.unknown,
        })
    .toList();

String show(List<int> cells) => cells
    .map((v) => switch (v) {
          Cell.filled => '#',
          Cell.crossed => 'x',
          _ => '.',
        })
    .join();

/// Apply what the solver proved so the result reads as a whole line.
String deduced(List<int> clue, String start) {
  final cells = line(start);
  final forced = LineSolver(clue, cells.length).deduce(cells);
  if (forced == null) return 'CONTRADICTION';
  forced.forEach((i, v) => cells[i] = v);
  return show(cells);
}

void main() {
  group('overlap — the first thing anyone learns', () {
    test('a run longer than half the line forces its middle', () {
      // 3 in a 5-line can start at 0, 1 or 2; cell 2 is filled either way.
      expect(deduced([3], '.....'), '..#..');
    });

    test('a run filling the line leaves nothing to decide', () {
      expect(deduced([5], '.....'), '#####');
    });

    test('a short run in a long line proves nothing', () {
      expect(deduced([1], '.....'), '.....');
    });

    test('two runs overlap independently', () {
      // [4,3] in 10: minimum width 8, so both runs have slack 2.
      expect(deduced([4, 3], '..........'), '..##...#..');
    });
  });

  group('using what is already on the board', () {
    test('a filled cell pins a run that only reaches it one way', () {
      // The single 2-run must cover cell 0, so cell 1 comes with it.
      expect(deduced([2], '#....'), '##xxx');
    });

    test('crossing out cells narrows where a run can sit', () {
      // With the left half blocked, 3 only fits at the right.
      expect(deduced([3], 'xx...'), 'xx###');
    });

    test('a completed line gets its remaining cells crossed', () {
      // Only one arrangement survives, so both gaps are blank.
      expect(deduced([2, 1], '##..#'), '##xx#');
    });

    test('an empty clue blanks the whole line', () {
      expect(deduced([0], '.....'), 'xxxxx');
    });
  });

  group('contradictions', () {
    test('a run that cannot fit anywhere', () {
      expect(deduced([3], 'x.x.x'), 'CONTRADICTION');
    });

    test('more filled cells than the clue allows', () {
      expect(deduced([1], '##...'), 'CONTRADICTION');
    });

    test('a clue wider than the line', () {
      expect(LineSolver([4, 4], 5).isImpossible, isTrue);
    });
  });

  group('counting arrangements — how uniqueness is decided', () {
    test('a pinned line has exactly one', () {
      expect(LineSolver([5], 5).countArrangements(line('.....')), 1);
    });

    test('slack means more than one', () {
      expect(LineSolver([1], 5).countArrangements(line('.....')), 2);
    });

    test('an impossible line has none', () {
      expect(LineSolver([3], 5).countArrangements(line('x.x.x')), 0);
    });
  });

  group('clueFor — reading a clue off a solved line', () {
    test('runs separated by blanks', () {
      expect(LineSolver.clueFor(line('##.#.')), [2, 1]);
    });

    test('a blank line is [0], not empty', () {
      expect(LineSolver.clueFor(line('.....')), [0]);
    });

    test('crossed cells count as blank', () {
      expect(LineSolver.clueFor(line('#x#')), [1, 1]);
    });

    test('the clue alone rarely pins the line back down', () {
      // '##.#.' reads as [2,1], but [2,1] also allows '##..#' and '.##.#',
      // so only the cell all three share is forced. A nonogram is solved
      // from rows *and* columns together, never one line in isolation.
      final clue = LineSolver.clueFor(line('##.#.'));
      expect(clue, [2, 1]);
      expect(deduced(clue, '.....'), '.#...');
    });
  });
}
