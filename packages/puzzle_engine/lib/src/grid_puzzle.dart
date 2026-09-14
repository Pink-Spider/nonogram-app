import 'package:meta/meta.dart';

import 'difficulty.dart';

/// An immutable, fully specified grid puzzle: the givens the player starts
/// with and the unique solution.
///
/// Cells are stored row-major in a flat list of length `size * size`.
/// `0` means "empty" in [givens]. Values are `1..size`.
@immutable
class GridPuzzle {
  GridPuzzle({
    required this.ruleId,
    required this.size,
    required List<int> givens,
    required List<int> solution,
    required this.difficulty,
    required this.seed,
    Map<String, Object?> extras = const {},
  })  : assert(givens.length == size * size, 'givens must be size*size'),
        assert(solution.length == size * size, 'solution must be size*size'),
        givens = List.unmodifiable(givens),
        solution = List.unmodifiable(solution),
        extras = Map.unmodifiable(extras);

  /// Identifier of the rule package that produced this puzzle (e.g. `sudoku`).
  final String ruleId;

  /// Board edge length (9 for classic Sudoku).
  final int size;

  /// Starting values, `0` for empty.
  final List<int> givens;

  /// The unique solution.
  final List<int> solution;

  final Difficulty difficulty;

  /// Seed used to generate the puzzle; `ruleId + difficulty + seed` fully
  /// reproduces it, which is how the daily puzzle works without a server.
  final int seed;

  /// Rule-specific data (e.g. Killer Sudoku cages). Must be JSON-encodable.
  final Map<String, Object?> extras;

  int get cellCount => size * size;

  int get givenCount => givens.where((v) => v != 0).length;

  /// Stable id, usable as a storage key.
  String get id => '$ruleId:${difficulty.id}:$seed';

  int indexOf(int row, int col) => row * size + col;

  bool isGiven(int index) => givens[index] != 0;

  Map<String, Object?> toJson() => {
        'ruleId': ruleId,
        'size': size,
        'givens': givens,
        'solution': solution,
        'difficulty': difficulty.id,
        'seed': seed,
        'extras': extras,
      };

  factory GridPuzzle.fromJson(Map<String, Object?> json) => GridPuzzle(
        ruleId: json['ruleId'] as String,
        size: json['size'] as int,
        givens: (json['givens'] as List<Object?>).cast<int>(),
        solution: (json['solution'] as List<Object?>).cast<int>(),
        difficulty: Difficulty.fromId(json['difficulty'] as String),
        seed: json['seed'] as int,
        extras: (json['extras'] as Map<String, Object?>?) ?? const {},
      );

  @override
  bool operator ==(Object other) => other is GridPuzzle && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GridPuzzle($id, givens=$givenCount)';
}
