import 'package:flutter_test/flutter_test.dart';
import 'package:nonogram/features/stats/streak.dart';

void main() {
  group('longestStreak', () {
    test('empty history is 0', () {
      expect(longestStreak({}), 0);
    });

    test('a single day is 1', () {
      expect(longestStreak({'2026-09-14'}), 1);
    });

    test('finds the longest run, not the latest', () {
      expect(
        longestStreak({
          // A 3-day run in August...
          '2026-08-01', '2026-08-02', '2026-08-03',
          // ...beats the current 2-day run.
          '2026-09-13', '2026-09-14',
        }),
        3,
      );
    });

    test('a run across a month boundary counts as one', () {
      expect(
        longestStreak({'2026-08-30', '2026-08-31', '2026-09-01'}),
        3,
      );
    });
  });

  group('currentStreak (midnight grace)', () {
    // Fixed "today" so the tests never depend on the wall clock.
    final today = DateTime(2026, 9, 14);

    test('no history is 0', () {
      expect(currentStreak({}, today), 0);
    });

    test('only today counts as 1', () {
      expect(currentStreak({'2026-09-14'}, today), 1);
    });

    test('an unfinished today does not break the run — the whole point '
        'of the grace rule', () {
      expect(currentStreak({'2026-09-12', '2026-09-13'}, today), 2);
    });

    test('solving today extends yesterday\'s run', () {
      expect(
        currentStreak({'2026-09-12', '2026-09-13', '2026-09-14'}, today),
        3,
      );
    });

    test('a missed yesterday really does break it', () {
      // Day before yesterday was done, yesterday skipped, today done.
      expect(currentStreak({'2026-09-12', '2026-09-14'}, today), 1);
    });

    test('yesterday and today both missed is 0', () {
      expect(currentStreak({'2026-09-11', '2026-09-12'}, today), 0);
    });

    test('runs across a month boundary', () {
      expect(
        currentStreak(
          {'2026-08-31', '2026-09-01'},
          DateTime(2026, 9, 1),
        ),
        2,
      );
    });
  });
}
