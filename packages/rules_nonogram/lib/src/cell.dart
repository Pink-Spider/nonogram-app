/// Cell values on a nonogram board.
///
/// The engine stores boards as `List<int>` with `0` meaning empty, so these
/// are plain ints rather than an enum. [unknown] is "not decided yet",
/// which is what an untouched cell holds.
///
/// [crossed] is a player annotation — "this one is definitely blank". It is
/// never part of a solution; solutions only ever hold [unknown] or
/// [filled]. Marking crosses is how anyone actually solves a nonogram, so
/// it is a first-class value rather than a note.
abstract final class Cell {
  static const int unknown = 0;
  static const int filled = 1;
  static const int crossed = 2;

  /// True when [value] settles the cell one way or the other.
  static bool isDecided(int value) => value != unknown;

  /// How a decided cell reads against a solution, where a solution cell is
  /// either [filled] or [unknown] (meaning blank).
  static bool matchesSolution(int boardValue, int solutionValue) {
    final shouldBeFilled = solutionValue == filled;
    return shouldBeFilled ? boardValue == filled : boardValue != filled;
  }
}
