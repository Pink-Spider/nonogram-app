import 'dart:math';

import 'package:puzzle_engine/puzzle_engine.dart';

import 'cell.dart';
import 'nonogram_solver.dart';
import 'shapes.dart';

/// Turns a shape into a playable puzzle.
///
/// Unlike Sudoku there is nothing to carve away: a nonogram *is* its
/// picture plus the clues read off it. So generation is picking a shape,
/// reading the clues, and confirming line logic can recover it. The
/// difficulty comes from the board size and from how much row/column
/// back-and-forth the picture demands.
///
/// Deterministic in `(difficulty, seed)` — the daily puzzle depends on it.
abstract final class NonogramGenerator {
  /// Bump when shape data or rating changes, so a stored daily puzzle that
  /// no longer matches is regenerated instead of silently differing.
  ///
  /// v2: pre-release library expansion, 21 → 48 shapes across all sizes.
  static const int algorithmVersion = 2;

  static const String ruleId = 'nonogram';

  /// Board edge length per tier. Bigger boards are harder mostly because
  /// there is more to track, which is how nonogram difficulty actually
  /// works — a 5x5 cannot be made expert-hard.
  static int sizeFor(Difficulty difficulty) => switch (difficulty) {
        Difficulty.easy => 5,
        Difficulty.medium => 10,
        Difficulty.hard => 15,
        Difficulty.expert => 20,
      };

  /// Generate deterministically.
  ///
  /// Walks the shape list from a seed-derived offset so the same seed
  /// always yields the same picture, and consecutive seeds spread across
  /// the library rather than repeating.
  static GridPuzzle generate({
    required Difficulty difficulty,
    required int seed,
  }) {
    final size = sizeFor(difficulty);
    final shapes = ShapeLibrary.forSize(size);
    if (shapes.isEmpty) {
      throw StateError('no shapes for size $size (difficulty $difficulty)');
    }

    final random = Random(seed);
    final offset = random.nextInt(shapes.length);

    for (var attempt = 0; attempt < shapes.length; attempt++) {
      final shape = shapes[(offset + attempt) % shapes.length];
      final puzzle = _build(shape, difficulty, seed);
      if (puzzle != null) return puzzle;
    }

    // Every shape for this size is checked by the test suite, so reaching
    // here means the library and the solver disagree.
    throw StateError(
      'no solvable shape for size $size — shape library is out of sync '
      'with the solver',
    );
  }

  /// The picture behind a puzzle, for the reveal screen.
  static Shape? shapeOf(GridPuzzle puzzle) {
    final id = puzzle.extras['shapeId'];
    return id is String ? ShapeLibrary.byId(id) : null;
  }

  /// Row clues stored on the puzzle.
  static List<List<int>> rowCluesOf(GridPuzzle puzzle) =>
      _clues(puzzle.extras['rowClues']);

  /// Column clues stored on the puzzle.
  static List<List<int>> colCluesOf(GridPuzzle puzzle) =>
      _clues(puzzle.extras['colClues']);

  static List<List<int>> _clues(Object? raw) {
    final outer = raw as List<Object?>? ?? const [];
    return outer
        .map((inner) => (inner as List<Object?>).cast<int>().toList())
        .toList();
  }

  static GridPuzzle? _build(Shape shape, Difficulty difficulty, int seed) {
    final solution = shape.toGrid();
    final clues = NonogramSolver.cluesFor(
      solution,
      width: shape.size,
      height: shape.size,
    );

    final result = NonogramSolver(
      rowClues: clues.rows,
      colClues: clues.cols,
    ).solve();

    // Only ship pictures a player can actually deduce.
    if (!result.solved || result.hardest == Technique.search) return null;

    return GridPuzzle(
      ruleId: ruleId,
      size: shape.size,
      // A nonogram starts empty — the clues are the givens.
      givens: List<int>.filled(shape.size * shape.size, Cell.unknown),
      solution: solution,
      difficulty: difficulty,
      seed: seed,
      extras: {
        'shapeId': shape.id,
        'rowClues': clues.rows,
        'colClues': clues.cols,
        'technique': result.hardest.name,
        'passes': result.passes,
        'algorithmVersion': algorithmVersion,
      },
    );
  }
}
