import 'package:puzzle_engine/puzzle_engine.dart';

import 'cell.dart';
import 'line_solver.dart';
import 'nonogram_generator.dart';
import 'nonogram_solver.dart';

/// [PuzzleRule] for nonograms.
///
/// One instance per board size, because the engine's contract fixes [size]
/// while nonogram difficulty is largely *about* size.
class NonogramRule extends PuzzleRule {
  const NonogramRule({required this.size});

  NonogramRule.forDifficulty(Difficulty difficulty)
      : size = NonogramGenerator.sizeFor(difficulty);

  @override
  final int size;

  @override
  String get id => NonogramGenerator.ruleId;

  /// [Cell.filled] and [Cell.crossed]. Crossing is a real move here, not a
  /// note: it is how the player records "this one is blank".
  @override
  int get maxValue => Cell.crossed;

  @override
  GridPuzzle generate({required Difficulty difficulty, required int seed}) =>
      NonogramGenerator.generate(difficulty: difficulty, seed: seed);

  /// Cells that make the placement impossible.
  ///
  /// Returns the offending line rather than a set of individual cells,
  /// because in a nonogram nothing conflicts pairwise — a move is wrong
  /// only against a whole row or column clue.
  @override
  List<int> conflicts(List<int> board, int index, int value) {
    final puzzle = _puzzle;
    if (puzzle == null) return const [];

    final row = index ~/ size;
    final col = index % size;
    final trial = List<int>.from(board)..[index] = value;

    final bad = <int>[];
    final rowCells = List.generate(size, (c) => trial[row * size + c]);
    if (!LineSolver(puzzle.rowClues[row], size).isConsistent(rowCells)) {
      for (var c = 0; c < size; c++) {
        bad.add(row * size + c);
      }
    }
    final colCells = List.generate(size, (r) => trial[r * size + col]);
    if (!LineSolver(puzzle.colClues[col], size).isConsistent(colCells)) {
      for (var r = 0; r < size; r++) {
        final i = r * size + col;
        if (!bad.contains(i)) bad.add(i);
      }
    }
    bad.remove(index);
    return bad;
  }

  /// The row and column through [index] — what the player is reading when
  /// they work on a cell.
  @override
  List<int> peers(int index) {
    final row = index ~/ size;
    final col = index % size;
    final out = <int>[];
    for (var c = 0; c < size; c++) {
      final i = row * size + c;
      if (i != index) out.add(i);
    }
    for (var r = 0; r < size; r++) {
      final i = r * size + col;
      if (i != index) out.add(i);
    }
    return out;
  }

  /// A cross is right when the cell really is blank, and a fill is right
  /// when it really is filled.
  ///
  /// Without this the engine compares `crossed` (2) against a solution that
  /// only ever holds 0 or 1, and every cross counts as a mistake — which
  /// would punish the main way people solve nonograms.
  @override
  bool isCorrect(int index, int value, List<int> solution) =>
      Cell.matchesSolution(value, solution[index]);

  /// Next cell logic forces, with the line that forces it.
  ///
  /// Runs the same line solver the player would, so the hint is always a
  /// step they could have taken — never a peek at the solution.
  @override
  Hint? nextHint(List<int> board, GridPuzzle puzzle) {
    final rowClues = NonogramGenerator.rowCluesOf(puzzle);
    final colClues = NonogramGenerator.colCluesOf(puzzle);
    if (rowClues.isEmpty || colClues.isEmpty) return null;

    for (var r = 0; r < size; r++) {
      final cells = List.generate(size, (c) => board[r * size + c]);
      final forced = LineSolver(rowClues[r], size).deduce(cells);
      if (forced == null || forced.isEmpty) continue;
      final entry = forced.entries.first;
      return Hint(
        index: r * size + entry.key,
        value: entry.value,
        techniqueId: entry.value == Cell.filled ? 'row_forces' : 'row_blanks',
        highlight: [for (var c = 0; c < size; c++) r * size + c],
      );
    }

    for (var c = 0; c < size; c++) {
      final cells = List.generate(size, (r) => board[r * size + c]);
      final forced = LineSolver(colClues[c], size).deduce(cells);
      if (forced == null || forced.isEmpty) continue;
      final entry = forced.entries.first;
      return Hint(
        index: entry.key * size + c,
        value: entry.value,
        techniqueId: entry.value == Cell.filled ? 'col_forces' : 'col_blanks',
        highlight: [for (var r = 0; r < size; r++) r * size + c],
      );
    }

    // Nothing forced anywhere: either finished, or the player has gone
    // wrong. The engine falls back to revealing a solution cell.
    return null;
  }

  /// Clues for the puzzle currently being played.
  ///
  /// [conflicts] is called per keystroke and the engine does not pass the
  /// puzzle in, so the app sets this when a game starts.
  static _Clues? _puzzle;

  /// Tell the rule which puzzle is in play, so mistake marking can read
  /// its clues. Call on game start and on restore.
  static void bind(GridPuzzle puzzle) {
    _puzzle = _Clues(
      rowClues: NonogramGenerator.rowCluesOf(puzzle),
      colClues: NonogramGenerator.colCluesOf(puzzle),
    );
  }

  static void unbind() => _puzzle = null;

  /// Is the board finished? Every filled cell right, nothing missing.
  /// Crossed and untouched both count as blank, so a player who never
  /// crosses anything still wins.
  static bool isSolved(List<int> board, GridPuzzle puzzle) {
    for (var i = 0; i < board.length; i++) {
      if (!Cell.matchesSolution(board[i], puzzle.solution[i])) return false;
    }
    return true;
  }

  /// Consistency check against the clues, for live mistake marking.
  static bool isConsistent(List<int> board, GridPuzzle puzzle) {
    final solver = NonogramSolver(
      rowClues: NonogramGenerator.rowCluesOf(puzzle),
      colClues: NonogramGenerator.colCluesOf(puzzle),
    );
    return solver.isConsistent(board);
  }
}

class _Clues {
  const _Clues({required this.rowClues, required this.colClues});
  final List<List<int>> rowClues;
  final List<List<int>> colClues;
}
