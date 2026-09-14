import 'package:core_ads/core_ads.dart';

enum Flavor { dev, prod }

/// Per-flavor configuration. Everything that differs between the store
/// build and the developer build lives here — nothing else in the app
/// checks the flavor directly.
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.adUnitIds,
    this.showDebugBanner = false,
    this.forceEeaConsent = false,
    this.umpTestDeviceIds = const [],
    this.resetConsentOnLaunch = false,
  });

  final Flavor flavor;
  final String appName;
  final AdUnitIds adUnitIds;
  final bool showDebugBanner;

  /// Dev only: pretend the device is in the EEA so the consent form shows.
  ///
  /// Has **no effect on its own**. Google only honours a debug geography on
  /// a device listed in [umpTestDeviceIds].
  final bool forceEeaConsent;

  /// UMP test device hashes. Run the app once and the native UMP SDK logs
  /// the hash for this device; pass it back in (see [dev]).
  final List<String> umpTestDeviceIds;

  /// Dev only: forget the stored consent at startup so the form appears on
  /// every launch. Without it the form shows once and never again.
  final bool resetConsentOnLaunch;

  bool get isDev => flavor == Flavor.dev;

  /// Device hashes come from the command line so no one has to edit (and
  /// then accidentally commit) a device id:
  ///
  /// ```
  /// flutter run -t lib/main_dev.dart \
  ///   --dart-define=UMP_TEST_DEVICE_IDS=<hash>[,<hash>]
  /// ```
  ///
  /// Run once without it, find the hash in the log line the UMP SDK prints
  /// ("Use ConsentDebugSettings... addTestDeviceHashedId(\"...\")"), then
  /// re-run with it.
  static const _umpTestDeviceIds =
      String.fromEnvironment('UMP_TEST_DEVICE_IDS');

  static List<String> get _adsTestDeviceIds => _umpTestDeviceIds.isEmpty
      ? const <String>[]
      : _umpTestDeviceIds.split(',').map((e) => e.trim()).toList();

  static AppConfig dev() {
    final ids = _adsTestDeviceIds;
    return AppConfig(
      flavor: Flavor.dev,
      appName: 'Nonogram (dev)',
      adUnitIds: AdUnitIds.test(),
      showDebugBanner: true,
      // Korea is not a consent region, so without this the form is skipped
      // and there is nothing to test.
      forceEeaConsent: true,
      umpTestDeviceIds: ids,
      resetConsentOnLaunch: true,
    );
  }

  /// Real ad unit ids, passed in at build time.
  ///
  /// These are deliberately not in the repo. Anyone holding a unit id can
  /// serve it from their own app, and the resulting invalid traffic gets
  /// *our* AdMob account suspended, not theirs. They live in
  /// `~/.pink-spider/secrets/sudoku/ad-units.env`; `tool/ad_units.sh`
  /// turns that file into the --dart-define flags. See
  /// docs/ad-units.md.
  ///
  /// Missing values fall back to Google's test units, so a fresh clone
  /// still builds and runs — it just cannot earn. The release scripts
  /// refuse to build without them so that never reaches a store.
  static const _androidBanner = String.fromEnvironment('AD_UNIT_ANDROID_BANNER');
  static const _androidInterstitial =
      String.fromEnvironment('AD_UNIT_ANDROID_INTERSTITIAL');
  static const _androidRewarded =
      String.fromEnvironment('AD_UNIT_ANDROID_REWARDED');
  static const _iosBanner = String.fromEnvironment('AD_UNIT_IOS_BANNER');
  static const _iosInterstitial =
      String.fromEnvironment('AD_UNIT_IOS_INTERSTITIAL');
  static const _iosRewarded = String.fromEnvironment('AD_UNIT_IOS_REWARDED');

  /// True when every real unit id was supplied. The release scripts check
  /// this indirectly by requiring the env file; this is the last guard.
  static bool get hasRealAdUnits =>
      _androidBanner.isNotEmpty &&
      _androidInterstitial.isNotEmpty &&
      _androidRewarded.isNotEmpty &&
      _iosBanner.isNotEmpty &&
      _iosInterstitial.isNotEmpty &&
      _iosRewarded.isNotEmpty;

  /// Shipping real units is only safe because [umpTestDeviceIds] doubles as
  /// the ads SDK's test-device list: a registered device gets test ads even
  /// from these units, so our own taps never become invalid traffic. Test
  /// on a registered device, or on the dev flavor.
  static AppConfig prod() => AppConfig(
        flavor: Flavor.prod,
        appName: 'Nonogram',
        adUnitIds: hasRealAdUnits
            ? AdUnitIds.platform(
                android: const AdUnitIds(
                  banner: _androidBanner,
                  interstitial: _androidInterstitial,
                  rewarded: _androidRewarded,
                ),
                ios: const AdUnitIds(
                  banner: _iosBanner,
                  interstitial: _iosInterstitial,
                  rewarded: _iosRewarded,
                ),
              )
            : AdUnitIds.test(),
        umpTestDeviceIds: _adsTestDeviceIds,
      );
}
