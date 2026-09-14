import 'package:core_ads/core_ads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime clock;
  late InterstitialGate gate;

  setUp(() {
    clock = DateTime(2026, 9, 9, 12);
    gate = InterstitialGate(
      config: const InterstitialGateConfig(
        everyNthEvent: 2,
        minInterval: Duration(seconds: 60),
        sessionGrace: Duration(seconds: 30),
      ),
      now: () => clock,
    )..startSession();
  });

  void tick(int seconds) => clock = clock.add(Duration(seconds: seconds));

  test('respects session grace and Nth event', () {
    expect(gate.shouldShowOnEvent(), isFalse); // grace
    tick(31);
    expect(gate.shouldShowOnEvent(), isTrue); // 2nd event, after grace
  });

  test('respects min interval after a show', () {
    tick(31);
    gate.shouldShowOnEvent();
    expect(gate.shouldShowOnEvent(), isTrue);
    gate.markShown();
    expect(gate.shouldShowOnEvent(), isFalse); // 1 of 2
    expect(gate.shouldShowOnEvent(), isFalse); // interval not elapsed
    tick(61);
    expect(gate.shouldShowOnEvent(), isTrue);
  });

  test('ad-free window blocks and expires', () {
    tick(31);
    gate.grantAdFree(const Duration(minutes: 10));
    expect(gate.isAdFree, isTrue);
    gate.shouldShowOnEvent();
    expect(gate.shouldShowOnEvent(), isFalse);
    tick(601);
    expect(gate.isAdFree, isFalse);
    expect(gate.shouldShowOnEvent(), isTrue);
  });

  test('kill switch', () {
    gate.config = gate.config.copyWith(enabled: false);
    tick(100);
    gate.shouldShowOnEvent();
    expect(gate.shouldShowOnEvent(), isFalse);
  });
}
