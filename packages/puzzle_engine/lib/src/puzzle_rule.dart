import 'difficulty.dart';
import 'grid_puzzle.dart';
import 'hint.dart';

/// The contract a concrete puzzle type implements.
///
/// The engine and the app UI are written against this interface only, so a
/// new puzzle (Killer Sudoku, Kakuro, Tango, ...) is a new implementation of
/// this class plus its own generator / solver — nothing else changes.
abstract class PuzzleRule {
  const PuzzleRule();

  /// Stable identifier, e.g. `sudoku`, `killer_sudoku`.
  String get id;

  /// Board edge length.
  int get size;

  /// Largest value a cell can hold (`size` for Sudoku).
  int get maxValue => size;

  /// Deterministically generate a puzzle. Same `(difficulty, seed)` must
  /// always yield the same puzzle — the daily challenge depends on it.
  GridPuzzle generate({required Difficulty difficulty, required int seed});

  /// Indices of cells that conflict with [index] holding [value] on
  /// [board] (a flat row-major list, `0` = empty). Used for live mistake
  /// highlighting. Must not include [index] itself.
  List<int> conflicts(List<int> board, int index, int value);

  /// Indices of cells "related" to [index] (same row / column / box for
  /// Sudoku). Used purely for UI highlighting.
  List<int> peers(int index);

  /// Produce the next logical step for the player, or `null` if the rule
  /// package cannot explain one (the engine then falls back to revealing
  /// a solution cell).
  Hint? nextHint(List<int> board, GridPuzzle puzzle) => null;

  /// Is putting [value] into [index] right, given [solution]?
  ///
  /// Defaults to an exact match, which is what a fill-in-the-number puzzle
  /// wants. Rules with values that are annotations rather than answers
  /// override this — a nonogram's cross means "blank", and blank is stored
  /// as `0` in the solution, so the two never compare equal.
  bool isCorrect(int index, int value, List<int> solution) =>
      value == solution[index];
}
