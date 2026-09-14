import 'package:core_ads/core_ads.dart';
import 'package:core_analytics/core_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:rules_nonogram/rules_nonogram.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/game/game_persistence.dart';
import 'app_config.dart';

/// Overridden in `bootstrap.dart` with the real instances. Throwing
/// defaults make a missing override an immediate, obvious failure.
final appConfigProvider = Provider<AppConfig>((_) => throw UnimplementedError());
final adServiceProvider = Provider<AdService>((_) => throw UnimplementedError());

/// Same instance the startup flow used, so the settings entry point can
/// reopen the UMP privacy form. GDPR requires consent to be withdrawable,
/// so this is not optional once a consent message is published.
final consentManagerProvider =
    Provider<ConsentManager>((_) => throw UnimplementedError());
final sharedPreferencesProvider =
    Provider<SharedPreferences>((_) => throw UnimplementedError());

final analyticsProvider =
    Provider<AnalyticsService>((_) => const DebugAnalyticsService());

final remoteConfigProvider =
    Provider<RemoteConfigService>((_) => LocalRemoteConfigService());

final interstitialGateProvider = Provider<InterstitialGate>((ref) {
  final rc = ref.watch(remoteConfigProvider);
  return InterstitialGate(
    config: InterstitialGateConfig(
      enabled: rc.getBool(RemoteConfigKeys.interstitialEnabled),
      everyNthEvent: rc.getInt(RemoteConfigKeys.interstitialEveryNth),
      minInterval:
          Duration(seconds: rc.getInt(RemoteConfigKeys.interstitialMinIntervalSec)),
      sessionGrace:
          Duration(seconds: rc.getInt(RemoteConfigKeys.interstitialSessionGraceSec)),
    ),
  )..startSession();
});

/// The rule this app is built around.
///
/// Nonogram board size is a function of difficulty (5/10/15/20), while
/// [PuzzleRule.size] is fixed per instance. Nothing in the engine reads
/// `rule.size` — it works off `puzzle.size` — so this instance only needs
/// to carry the rule's behaviour, and the generator sizes each puzzle from
/// the difficulty it is given.
final puzzleRuleProvider = Provider<PuzzleRule>(
  (_) => NonogramRule.forDifficulty(Difficulty.medium),
);

final gamePersistenceProvider = Provider<GamePersistence>(
  (ref) => GamePersistence(ref.watch(sharedPreferencesProvider)),
);
