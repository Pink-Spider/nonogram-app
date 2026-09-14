import 'dart:io' show Platform;

/// Ad unit ids for one app on the current platform.
class AdUnitIds {
  const AdUnitIds({
    required this.banner,
    required this.interstitial,
    required this.rewarded,
  });

  final String banner;
  final String interstitial;
  final String rewarded;

  /// Google's official sample ids — always fill on any device, never pay.
  /// Use these in the `dev` flavor; real ids go in the `prod` flavor.
  factory AdUnitIds.test() => Platform.isIOS
      ? const AdUnitIds(
          banner: 'ca-app-pub-3940256099942544/2934735716',
          interstitial: 'ca-app-pub-3940256099942544/4411468910',
          rewarded: 'ca-app-pub-3940256099942544/1712485313',
        )
      : const AdUnitIds(
          banner: 'ca-app-pub-3940256099942544/6300978111',
          interstitial: 'ca-app-pub-3940256099942544/1033173712',
          rewarded: 'ca-app-pub-3940256099942544/5224354917',
        );

  /// Pick per platform. Both maps must contain the same keys.
  factory AdUnitIds.platform({
    required AdUnitIds android,
    required AdUnitIds ios,
  }) =>
      Platform.isIOS ? ios : android;
}

/// Sample *app* ids (go in AndroidManifest.xml / Info.plist, not here).
/// Kept for reference by `scripts/bootstrap.sh`.
class AdMobAppIds {
  const AdMobAppIds._();
  static const testAndroid = 'ca-app-pub-3940256099942544~3347511713';
  static const testIos = 'ca-app-pub-3940256099942544~1458002511';
}
