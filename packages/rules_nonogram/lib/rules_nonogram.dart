/// Nonogram (Picross) rule for puzzle_engine.
///
/// Everything here is pure Dart and deterministic: the same
/// `(difficulty, seed)` always produces the same picture, which is what
/// lets the daily puzzle work without a server.
library;

export 'src/cell.dart';
export 'src/line_solver.dart';
export 'src/nonogram_solver.dart';
export 'src/nonogram_generator.dart';
export 'src/nonogram_rule.dart';
export 'src/shapes.dart';
