import 'package:core_ads/core_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nonogram/app/app_config.dart';
import 'package:nonogram/app/providers.dart';

/// Provider overrides for tests: no real ads, in-memory prefs.
Future<List<Override>> testOverrides({bool rewardedResult = true}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    appConfigProvider.overrideWithValue(AppConfig.dev()),
    adServiceProvider.overrideWithValue(NoopAdService(rewardedResult: rewardedResult)),
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];
}
