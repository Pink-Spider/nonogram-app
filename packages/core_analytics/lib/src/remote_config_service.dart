/// Typed access to remotely tunable values with local defaults.
///
/// The app reads through this interface; the Firebase Remote Config
/// implementation (added per app) overrides the defaults after fetch.
abstract class RemoteConfigService {
  Future<void> initialize();
  bool getBool(String key);
  int getInt(String key);
  double getDouble(String key);
  String getString(String key);
}

/// Keys and defaults shared by every puzzle app. Remote values must use the
/// same keys.
class RemoteConfigKeys {
  const RemoteConfigKeys._();

  static const interstitialEnabled = 'interstitial_enabled';
  static const interstitialEveryNth = 'interstitial_every_nth';
  static const interstitialMinIntervalSec = 'interstitial_min_interval_sec';
  static const interstitialSessionGraceSec = 'interstitial_session_grace_sec';
  static const bannerEnabled = 'banner_enabled';
  static const freeHintsPerPuzzle = 'free_hints_per_puzzle';
  static const maxMistakes = 'max_mistakes';
  static const adFreeRewardMinutes = 'ad_free_reward_minutes';

  static const Map<String, Object> defaults = {
    interstitialEnabled: true,
    interstitialEveryNth: 2,
    interstitialMinIntervalSec: 120,
    interstitialSessionGraceSec: 60,
    bannerEnabled: true,
    freeHintsPerPuzzle: 1,
    maxMistakes: 3,
    adFreeRewardMinutes: 60,
  };
}

/// In-memory implementation using [RemoteConfigKeys.defaults], optionally
/// overridden (tests, dev flavor).
class LocalRemoteConfigService implements RemoteConfigService {
  LocalRemoteConfigService({Map<String, Object> overrides = const {}})
      : _values = {...RemoteConfigKeys.defaults, ...overrides};

  final Map<String, Object> _values;

  @override
  Future<void> initialize() async {}

  @override
  bool getBool(String key) => _values[key] as bool? ?? false;

  @override
  int getInt(String key) => (_values[key] as num?)?.toInt() ?? 0;

  @override
  double getDouble(String key) => (_values[key] as num?)?.toDouble() ?? 0;

  @override
  String getString(String key) => _values[key]?.toString() ?? '';
}
