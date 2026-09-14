import 'cell.dart';

/// Everything a nonogram can be reasoned about happens one line at a time:
/// take a row or column's clue, take what the player has already decided,
/// and work out which cells every legal arrangement agrees on.
///
/// The whole rule package is built on this — uniqueness checking, the
/// difficulty rating and the hints all come from repeatedly asking a line
/// what it can prove.
///
/// The obvious implementation enumerates arrangements, which blows up on a
/// 20-wide line. Instead this walks positions with memoisation and records,
/// per cell, whether *any* legal arrangement fills it and whether any
/// leaves it blank. A cell where only one of those is true is forced.
class LineSolver {
  LineSolver(this.clue, this.length)
      : assert(length > 0),
        _minimumWidth = _widthOf(clue);

  /// Run lengths, e.g. `[3, 1]` = three filled, at least one blank, one
  /// filled. An empty clue (or `[0]`) means the line is entirely blank.
  final List<int> clue;

  /// Number of cells in the line.
  final int length;

  final int _minimumWidth;

  /// Space the clue needs at minimum: the runs plus one gap between each.
  static int _widthOf(List<int> clue) {
    final runs = clue.where((r) => r > 0).toList();
    if (runs.isEmpty) return 0;
    return runs.fold<int>(0, (a, b) => a + b) + runs.length - 1;
  }

  /// True when the clue cannot fit at all — a malformed puzzle.
  bool get isImpossible => _minimumWidth > length;

  /// Cells this line can prove from [current], as a sparse map of
  /// index-within-the-line to [Cell.filled] or [Cell.crossed].
  ///
  /// Returns an empty map when nothing new is forced. Returns `null` when
  /// [current] already contradicts the clue, which is how the solver
  /// detects a dead end.
  Map<int, int>? deduce(List<int> current) {
    assert(current.length == length);

    final canFill = List<bool>.filled(length, false);
    final canBlank = List<bool>.filled(length, false);
    final memo = <int, bool>{};

    if (!_walk(0, 0, current, canFill, canBlank, memo)) return null;

    final forced = <int, int>{};
    for (var i = 0; i < length; i++) {
      if (Cell.isDecided(current[i])) continue;
      if (canFill[i] && !canBlank[i]) {
        forced[i] = Cell.filled;
      } else if (canBlank[i] && !canFill[i]) {
        forced[i] = Cell.crossed;
      }
    }
    return forced;
  }

  /// True when at least one arrangement is consistent with [current].
  bool isConsistent(List<int> current) => deduce(current) != null;

  /// Number of arrangements consistent with [current], capped at [cap].
  ///
  /// Used for uniqueness: the generator only needs to know whether a line
  /// still has one arrangement or more than one, so counting stops early.
  int countArrangements(List<int> current, {int cap = 2}) {
    var found = 0;
    void recurse(int runIndex, int pos) {
      if (found >= cap) return;
      if (runIndex == _runs.length) {
        for (var i = pos; i < length; i++) {
          if (current[i] == Cell.filled) return;
        }
        found++;
        return;
      }
      final run = _runs[runIndex];
      final latest = length - _tailWidth(runIndex);
      for (var start = pos; start <= latest; start++) {
        if (!_fits(current, start, run)) continue;
        var clean = true;
        for (var i = pos; i < start; i++) {
          if (current[i] == Cell.filled) {
            clean = false;
            break;
          }
        }
        if (!clean) break;
        final after = start + run;
        if (after < length && current[after] == Cell.filled) continue;
        recurse(runIndex + 1, after + 1);
        if (found >= cap) return;
      }
    }

    recurse(0, 0);
    return found;
  }

  late final List<int> _runs = clue.where((r) => r > 0).toList();

  /// Width still needed from [runIndex] onwards, including separating gaps.
  int _tailWidth(int runIndex) {
    var width = 0;
    for (var i = runIndex; i < _runs.length; i++) {
      width += _runs[i];
      if (i != _runs.length - 1) width += 1;
    }
    return width;
  }

  /// Can a run of [run] cells sit at [start] without contradicting cells the
  /// player has already crossed out?
  bool _fits(List<int> current, int start, int run) {
    if (start + run > length) return false;
    for (var i = start; i < start + run; i++) {
      if (current[i] == Cell.crossed) return false;
    }
    return true;
  }

  /// Walk every legal placement, marking which cells can be filled and
  /// which can be blank. Returns false when no placement exists.
  ///
  /// Memoised on (runIndex, pos): whether that suffix is satisfiable. The
  /// per-cell flags are still set on every successful path, so the memo only
  /// prunes provably dead branches — it never hides a reachable cell.
  bool _walk(
    int runIndex,
    int pos,
    List<int> current,
    List<bool> canFill,
    List<bool> canBlank,
    Map<int, bool> memo,
  ) {
    if (runIndex == _runs.length) {
      // Every remaining cell must be blank.
      for (var i = pos; i < length; i++) {
        if (current[i] == Cell.filled) return false;
      }
      for (var i = pos; i < length; i++) {
        canBlank[i] = true;
      }
      return true;
    }

    final key = runIndex * (length + 1) + pos;
    final cached = memo[key];
    if (cached == false) return false;

    final run = _runs[runIndex];
    final latest = length - _tailWidth(runIndex);
    var any = false;

    for (var start = pos; start <= latest; start++) {
      // Cells skipped before this run must be able to be blank.
      var skippable = true;
      for (var i = pos; i < start; i++) {
        if (current[i] == Cell.filled) {
          skippable = false;
          break;
        }
      }
      if (!skippable) break;

      if (!_fits(current, start, run)) continue;

      final after = start + run;
      // The cell right after a run must be blank (or the line ends).
      if (after < length && current[after] == Cell.filled) continue;

      if (_walk(runIndex + 1, after + 1, current, canFill, canBlank, memo)) {
        any = true;
        for (var i = pos; i < start; i++) {
          canBlank[i] = true;
        }
        for (var i = start; i < after; i++) {
          canFill[i] = true;
        }
        if (after < length) canBlank[after] = true;
      }
    }

    memo[key] = any;
    return any;
  }

  /// The clue a fully solved line produces — used to build puzzles from
  /// shapes and to verify a finished board.
  static List<int> clueFor(List<int> line) {
    final clue = <int>[];
    var run = 0;
    for (final value in line) {
      if (value == Cell.filled) {
        run++;
      } else if (run > 0) {
        clue.add(run);
        run = 0;
      }
    }
    if (run > 0) clue.add(run);
    return clue.isEmpty ? const [0] : clue;
  }
}
