import 'package:core_ads/core_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nonogram/app/app_config.dart';
import 'package:nonogram/app/providers.dart';

/// Provider overrides for tests: no real ads, in-memory prefs.
///
/// The tutorial flag defaults to done, so screens under test are not
/// covered by the first-run tutorial; pass `tutorialDone: false` to test
/// the first-run flow itself.
Future<List<Override>> testOverrides({
  bool rewardedResult = true,
  bool tutorialDone = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (tutorialDone) 'tutorial.done': true,
  });
  final prefs = await SharedPreferences.getInstance();
  return [
    appConfigProvider.overrideWithValue(AppConfig.dev()),
    adServiceProvider.overrideWithValue(NoopAdService(rewardedResult: rewardedResult)),
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];
}
