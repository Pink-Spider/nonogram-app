import 'package:flutter/widgets.dart';

import 'ad_service.dart';

/// Does nothing. Used in widget tests, screenshot runs, and as the
/// simplest "ads off" switch.
///
/// [rewardedResult] lets tests simulate the user completing (or skipping)
/// a rewarded ad.
class NoopAdService implements AdService {
  NoopAdService({this.rewardedResult = true});

  final bool rewardedResult;

  @override
  Future<void> initialize() async {}

  @override
  bool get isInterstitialReady => false;

  @override
  bool get isRewardedReady => true;

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> showRewarded() async => rewardedResult;

  @override
  Widget? banner({Key? key}) => null;

  @override
  void dispose() {}
}
