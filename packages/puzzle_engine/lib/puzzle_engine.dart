/// Rule-agnostic grid puzzle framework.
///
/// Everything a grid logic puzzle app needs *except* the rules of a specific
/// puzzle: the immutable puzzle definition, a mutable game session with
/// undo / notes / mistakes / hints, difficulty levels, and deterministic
/// daily seeds. Concrete puzzles (Sudoku, Killer Sudoku, Nonogram, ...)
/// implement [PuzzleRule] in their own package.
library;

export 'src/daily.dart';
export 'src/difficulty.dart';
export 'src/game_session.dart';
export 'src/grid_puzzle.dart';
export 'src/hint.dart';
export 'src/move.dart';
export 'src/puzzle_rule.dart';
