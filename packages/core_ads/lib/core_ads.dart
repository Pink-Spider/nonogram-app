/// AdMob integration shared by every app in the workspace.
///
/// Apps depend on [AdService] only. [AdMobAdService] is the production
/// implementation; [NoopAdService] is for tests, screenshots and the
/// "ad-free hour" reward. [InterstitialGate] decides *whether* to show an
/// interstitial so frequency rules live in one place and are tunable via
/// remote config.
library;

export 'src/ad_banner.dart';
export 'src/ad_service.dart';
export 'src/ad_unit_ids.dart';
export 'src/admob_ad_service.dart';
export 'src/consent_manager.dart';
export 'src/interstitial_gate.dart';
export 'src/noop_ad_service.dart';
