/// Decides whether an interstitial may be shown right now.
///
/// All frequency rules live here so they can be tuned from remote config
/// without touching game code. Pure Dart → unit-testable.
class InterstitialGate {
  InterstitialGate({
    required this.config,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  InterstitialGateConfig config;
  final DateTime Function() _now;

  DateTime? _lastShown;
  DateTime? _adFreeUntil;
  int _eventsSinceLastAd = 0;
  DateTime? _sessionStart;

  /// Call once when the app becomes active.
  void startSession() => _sessionStart ??= _now();

  /// Grant an ad-free window (e.g. reward for watching a rewarded ad).
  void grantAdFree(Duration duration) {
    final until = _now().add(duration);
    if (_adFreeUntil == null || until.isAfter(_adFreeUntil!)) {
      _adFreeUntil = until;
    }
  }

  bool get isAdFree {
    final u = _adFreeUntil;
    return u != null && _now().isBefore(u);
  }

  /// Register a "natural break" (puzzle completed, level abandoned) and
  /// report whether an interstitial should be shown at it.
  bool shouldShowOnEvent() {
    _eventsSinceLastAd++;
    if (!config.enabled || isAdFree) return false;

    final now = _now();
    final start = _sessionStart ?? now;
    if (now.difference(start) < config.sessionGrace) return false;

    if (_eventsSinceLastAd < config.everyNthEvent) return false;

    final last = _lastShown;
    if (last != null && now.difference(last) < config.minInterval) return false;

    return true;
  }

  /// Call after an interstitial was actually shown.
  void markShown() {
    _lastShown = _now();
    _eventsSinceLastAd = 0;
  }
}

class InterstitialGateConfig {
  const InterstitialGateConfig({
    this.enabled = true,
    this.everyNthEvent = 2,
    this.minInterval = const Duration(seconds: 120),
    this.sessionGrace = const Duration(seconds: 60),
  });

  /// Master switch (remote config kill-switch).
  final bool enabled;

  /// Show at most on every Nth natural break.
  final int everyNthEvent;

  /// Minimum wall-clock time between interstitials.
  final Duration minInterval;

  /// No interstitials during the first seconds of a session — first
  /// impressions matter more than one impression.
  final Duration sessionGrace;

  InterstitialGateConfig copyWith({
    bool? enabled,
    int? everyNthEvent,
    Duration? minInterval,
    Duration? sessionGrace,
  }) =>
      InterstitialGateConfig(
        enabled: enabled ?? this.enabled,
        everyNthEvent: everyNthEvent ?? this.everyNthEvent,
        minInterval: minInterval ?? this.minInterval,
        sessionGrace: sessionGrace ?? this.sessionGrace,
      );
}
