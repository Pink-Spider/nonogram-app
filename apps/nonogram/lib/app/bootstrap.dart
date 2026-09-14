import 'dart:async';

import 'package:core_ads/core_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_config.dart';
import 'providers.dart';

/// Shared entry point for every flavor.
///
/// The first frame is not blocked on the ad stack: the UI starts, and the
/// consent -> ATT -> SDK init chain runs behind it. That ordering is not
/// cosmetic — see [_startAds].
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final AdService ads =
      kIsWeb
          ? NoopAdService()
          : AdMobAdService(
              ids: config.adUnitIds,
              testDeviceIds: config.umpTestDeviceIds,
            );
  final consent = ConsentManager(
    forceEea: config.forceEeaConsent,
    testDeviceIds: config.umpTestDeviceIds,
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        adServiceProvider.overrideWithValue(ads),
        consentManagerProvider.overrideWithValue(consent),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NonogramApp(),
    ),
  );

  if (ads is AdMobAdService) unawaited(_startAds(ads, consent, config));
}

/// Consent, then tracking permission, then the SDK — in that order.
///
/// * UMP first because Google requires consent to be resolved before ATT.
/// * ATT only once a frame has been rendered: iOS silently denies a request
///   made while the app is not yet active, and a denial is permanent.
/// * The SDK last, so its first ad request already knows both answers.
///
/// Banners tolerate arriving before this finishes; [AdBanner] retries.
Future<void> _startAds(
  AdMobAdService ads,
  ConsentManager consent,
  AppConfig config,
) async {
  await WidgetsBinding.instance.endOfFrame;

  if (config.resetConsentOnLaunch) {
    await consent.reset();
    if (config.forceEeaConsent && config.umpTestDeviceIds.isEmpty) {
      // Silent-failure guard: a debug geography without a registered test
      // device is ignored, so the form simply never appears and it looks
      // like the message was never published.
      debugPrint('[consent] forcing EEA but no UMP test device id given. '
          'Find the hash in the native log line containing '
          '"addTestDeviceHashedId" and re-run with '
          '--dart-define=UMP_TEST_DEVICE_IDS=<hash>');
    }
  }

  final canRequestAds = await consent.gatherConsent();
  await consent.requestTracking();

  if (canRequestAds) {
    await ads.initialize();
  } else {
    debugPrint('[ads] consent withheld, ads disabled for this session');
  }
}
