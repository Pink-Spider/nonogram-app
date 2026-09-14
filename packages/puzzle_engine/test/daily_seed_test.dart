import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  test('same calendar day gives same seed regardless of time', () {
    final a = DailySeed.forDate(DateTime(2026, 9, 9, 0, 1));
    final b = DailySeed.forDate(DateTime(2026, 9, 9, 23, 59));
    expect(a, b);
  });

  test('consecutive days differ', () {
    final a = DailySeed.forDate(DateTime(2026, 9, 9));
    final b = DailySeed.forDate(DateTime(2026, 9, 10));
    expect(a, isNot(b));
  });

  test('salt separates rule packages', () {
    final d = DateTime(2026, 9, 9);
    expect(DailySeed.forDate(d), isNot(DailySeed.forDate(d, salt: 1)));
  });

  test('dateKey is zero padded', () {
    expect(DailySeed.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
