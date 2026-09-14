import 'cell.dart';
import 'line_solver.dart';

/// What a board needed to be solved. Ordered: a puzzle is rated by the
/// hardest step it forces.
enum Technique {
  /// A run long enough that its middle is filled wherever it sits. The
  /// first thing anyone learns, and the only one that needs no context.
  overlap,

  /// A line where what is already decided leaves exactly one arrangement.
  lineComplete,

  /// A line that proves something only after other lines have contributed
  /// — the row/column back-and-forth that is most of nonogram solving.
  crossReference,

  /// Nothing was forced; the solver had to guess and check. Puzzles that
  /// need this are excluded, because a player cannot be expected to.
  search,
}

/// Result of solving a board.
class SolveResult {
  const SolveResult({
    required this.solved,
    required this.unique,
    required this.hardest,
    required this.board,
    required this.passes,
  });

  /// Every cell decided and consistent with the clues.
  final bool solved;

  /// No second solution exists.
  final bool unique;

  /// Hardest technique the solve needed.
  final Technique hardest;

  /// Board as far as logic took it.
  final List<int> board;

  /// How many full row+column sweeps it took. A rough proxy for how much
  /// back-and-forth the player faces.
  final int passes;
}

/// Solves a nonogram the way a person does: sweep the rows, sweep the
/// columns, repeat until nothing new is forced.
///
/// Deliberately has no search fallback for rating. If line logic stalls,
/// the puzzle needs guessing and the generator throws it away — so every
/// puzzle that ships is solvable by pure deduction.
class NonogramSolver {
  NonogramSolver({required this.rowClues, required this.colClues})
      : height = rowClues.length,
        width = colClues.length;

  final List<List<int>> rowClues;
  final List<List<int>> colClues;
  final int height;
  final int width;

  int _index(int row, int col) => row * width + col;

  List<int> _row(List<int> board, int row) =>
      List.generate(width, (c) => board[_index(row, c)]);

  List<int> _col(List<int> board, int col) =>
      List.generate(height, (r) => board[_index(r, col)]);

  /// Solve from an empty board (or from [start], for hints).
  SolveResult solve({List<int>? start}) {
    final board = start != null
        ? List<int>.from(start)
        : List<int>.filled(width * height, Cell.unknown);

    var hardest = Technique.overlap;
    var passes = 0;
    var progress = true;

    while (progress) {
      progress = false;
      passes++;

      for (var r = 0; r < height; r++) {
        final solver = LineSolver(rowClues[r], width);
        final forced = solver.deduce(_row(board, r));
        if (forced == null) {
          return SolveResult(
            solved: false,
            unique: false,
            hardest: Technique.search,
            board: board,
            passes: passes,
          );
        }
        if (forced.isNotEmpty) {
          forced.forEach((c, v) => board[_index(r, c)] = v);
          progress = true;
          // Anything proved after the opening sweep needed the other axis.
          if (passes > 1) hardest = _atLeast(hardest, Technique.crossReference);
        }
      }

      for (var c = 0; c < width; c++) {
        final solver = LineSolver(colClues[c], height);
        final forced = solver.deduce(_col(board, c));
        if (forced == null) {
          return SolveResult(
            solved: false,
            unique: false,
            hardest: Technique.search,
            board: board,
            passes: passes,
          );
        }
        if (forced.isNotEmpty) {
          forced.forEach((r, v) => board[_index(r, c)] = v);
          progress = true;
          hardest = _atLeast(hardest, Technique.lineComplete);
          if (passes > 1) hardest = _atLeast(hardest, Technique.crossReference);
        }
      }
    }

    final decided = board.every(Cell.isDecided);
    if (!decided) {
      // Line logic ran dry. The puzzle may still have a unique solution,
      // but not one a player can reason out, so it does not ship.
      return SolveResult(
        solved: false,
        unique: false,
        hardest: Technique.search,
        board: board,
        passes: passes,
      );
    }

    return SolveResult(
      solved: true,
      unique: true,
      hardest: hardest,
      board: board,
      passes: passes,
    );
  }

  static Technique _atLeast(Technique current, Technique candidate) =>
      candidate.index > current.index ? candidate : current;

  /// Clues for a finished grid, row-major, `1` = filled.
  static ({List<List<int>> rows, List<List<int>> cols}) cluesFor(
    List<int> solution, {
    required int width,
    required int height,
  }) {
    final rows = <List<int>>[];
    for (var r = 0; r < height; r++) {
      rows.add(LineSolver.clueFor(
        List.generate(width, (c) => solution[r * width + c]),
      ));
    }
    final cols = <List<int>>[];
    for (var c = 0; c < width; c++) {
      cols.add(LineSolver.clueFor(
        List.generate(height, (r) => solution[r * width + c]),
      ));
    }
    return (rows: rows, cols: cols);
  }

  /// Does [board] contradict the clues? Used for live mistake marking.
  ///
  /// Only reports a contradiction the player can already see — a line whose
  /// decided cells cannot be completed — rather than comparing against the
  /// solution, so crossing out a cell you have not proved yet is not
  /// punished.
  bool isConsistent(List<int> board) {
    for (var r = 0; r < height; r++) {
      if (!LineSolver(rowClues[r], width).isConsistent(_row(board, r))) {
        return false;
      }
    }
    for (var c = 0; c < width; c++) {
      if (!LineSolver(colClues[c], height).isConsistent(_col(board, c))) {
        return false;
      }
    }
    return true;
  }
}
