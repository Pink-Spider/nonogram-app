/// Deterministic seeds for the daily challenge.
///
/// Every device derives the same seed from the same calendar date, so all
/// players worldwide get the same puzzle with no backend involved.
class DailySeed {
  const DailySeed._();

  /// Local calendar date → stable seed. `salt` separates rule packages
  /// (and lets you re-roll a bad day without changing the formula).
  static int forDate(DateTime date, {int salt = 0}) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final epochDay = day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    // Mix so consecutive days do not produce visibly related puzzles.
    var x = (epochDay + salt) & 0x7fffffff;
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff;
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff;
    return x ^ (x >> 16);
  }

  /// `yyyy-MM-dd` key for storage / stats.
  static String dateKey(DateTime date) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
