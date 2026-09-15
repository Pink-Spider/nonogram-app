/// Streak arithmetic over the calendar dates whose daily was completed.
///
/// Keys are `DailySeed.dateKey` strings (`yyyy-MM-dd`, local calendar
/// dates). Pure functions over a set of keys, so they test without
/// SharedPreferences and never care how the dates are stored.
library;

/// Parsed as UTC so day arithmetic never trips over a DST transition.
DateTime _day(String key) => DateTime.parse('${key}T00:00:00Z');

/// A [DateTime] back to its `yyyy-MM-dd` key, for membership checks
/// against [Set]s of done dates.
String dateKeyOf(DateTime date) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

/// The longest run of consecutive completed days, ever.
int longestStreak(Set<String> doneDates) {
  if (doneDates.isEmpty) return 0;
  final days = doneDates.map(_day).toList()..sort();
  var longest = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    run = days[i].difference(days[i - 1]).inDays == 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }
  return longest;
}

/// The player's current unbroken run of dailies — the number next to the
/// flame on the stats screen.
///
/// Midnight-grace rule (the Duolingo model): a not-yet-played today does
/// not break the run, it just does not count yet. The morning after a
/// 5-day run still reads "5", and solving today turns it into "6". The
/// alternative — counting strictly back from today — would reset the
/// display to 0 every morning, which punishes exactly the players who
/// showed up.
int currentStreak(Set<String> doneDates, DateTime today) {
  var streak = 0;
  var day = DateTime.utc(today.year, today.month, today.day);
  if (doneDates.contains(dateKeyOf(day))) streak++;
  day = day.subtract(const Duration(days: 1));
  while (doneDates.contains(dateKeyOf(day))) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
