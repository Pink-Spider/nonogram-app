import 'package:flutter/widgets.dart';

/// What the app can ask of the ad layer. Keep this small: the app should
/// never import `google_mobile_ads` directly.
abstract class AdService {
  /// Initialise the SDK and start pre-loading full-screen ads.
  /// Safe to call once at startup after consent has been gathered.
  Future<void> initialize();

  bool get isInterstitialReady;
  bool get isRewardedReady;

  /// Show an interstitial if one is loaded. Resolves when it is dismissed.
  /// Returns `false` if nothing was shown. Pre-loads the next one.
  Future<bool> showInterstitial();

  /// Show a rewarded ad. Resolves `true` only if the user earned the
  /// reward (watched to completion). Pre-loads the next one.
  Future<bool> showRewarded();

  /// A banner for the given [ValueKey]-scoped placement, or `null` when
  /// banners are disabled (no-op service, ad-free window, tests).
  /// The returned widget manages its own load/dispose lifecycle.
  Widget? banner({Key? key});

  void dispose();
}
