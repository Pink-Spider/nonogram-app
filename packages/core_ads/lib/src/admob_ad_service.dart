import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_banner.dart';
import 'ad_service.dart';
import 'ad_unit_ids.dart';

/// Production [AdService] backed by `google_mobile_ads`.
///
/// Full-screen ads are pre-loaded and re-loaded after every show (with a
/// capped retry backoff) so `show*` is almost always instant.
class AdMobAdService implements AdService {
  AdMobAdService({
    required this.ids,
    this.testDeviceIds = const [],
    this.log = _defaultLog,
  });

  final AdUnitIds ids;

  /// Devices that must always receive test ads, even from real ad units.
  ///
  /// This is the guard that makes shipping real unit ids in a build you
  /// install yourself safe: without it, tapping your own live ad is
  /// invalid traffic, which is grounds for suspending an AdMob account.
  final List<String> testDeviceIds;
  final void Function(String message) log;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _interstitialRetries = 0;
  int _rewardedRetries = 0;
  bool _disposed = false;

  static void _defaultLog(String m) => debugPrint('[ads] $m');

  @override
  Future<void> initialize() async {
    if (testDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testDeviceIds),
      );
      log('test devices registered: ${testDeviceIds.length}');
    }
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  @override
  bool get isInterstitialReady => _interstitial != null;

  @override
  bool get isRewardedReady => _rewarded != null;

  // --------------------------------------------------------- interstitial

  void _loadInterstitial() {
    if (_disposed) return;
    InterstitialAd.load(
      adUnitId: ids.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitialRetries = 0;
        },
        onAdFailedToLoad: (error) {
          log('interstitial load failed: ${error.code} ${error.message}');
          _interstitial = null;
          _retry(_interstitialRetries++, _loadInterstitial);
        },
      ),
    );
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        log('interstitial show failed: ${error.message}');
        ad.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(false);
      },
    );
    await ad.show();
    return done.future;
  }

  // ------------------------------------------------------------- rewarded

  void _loadRewarded() {
    if (_disposed) return;
    RewardedAd.load(
      adUnitId: ids.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardedRetries = 0;
        },
        onAdFailedToLoad: (error) {
          log('rewarded load failed: ${error.code} ${error.message}');
          _rewarded = null;
          _retry(_rewardedRetries++, _loadRewarded);
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        log('rewarded show failed: ${error.message}');
        ad.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    await ad.show(
      onUserEarnedReward: (_, reward) {
        earned = true;
      },
    );
    return done.future;
  }

  // --------------------------------------------------------------- banner

  @override
  Widget? banner({Key? key}) => AdBanner(key: key, adUnitId: ids.banner);

  // -------------------------------------------------------------- helpers

  /// Exponential backoff: 2s, 4s, 8s ... capped at 64s.
  void _retry(int attempt, void Function() load) {
    final seconds = 1 << (attempt.clamp(0, 5) + 1);
    Future<void>.delayed(Duration(seconds: seconds), load);
  }

  @override
  void dispose() {
    _disposed = true;
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = null;
    _rewarded = null;
  }
}
