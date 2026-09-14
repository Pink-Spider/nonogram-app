import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google UMP (User Messaging Platform) consent flow.
///
/// Required for EEA/UK users under GDPR and, since 2024, for AdMob to
/// serve at all in those regions. Call [gatherConsent] before
/// [AdService.initialize]; it is a no-op outside consent regions.
///
/// Configure the actual message in AdMob → Privacy & messaging. For iOS
/// also enable the IDFA explainer there so the ATT prompt is shown.
class ConsentManager {
  ConsentManager({this.forceEea = false, this.testDeviceIds = const []});

  /// Force EEA behaviour on a test device (dev flavor only) so the consent
  /// form can be exercised from anywhere.
  final bool forceEea;
  final List<String> testDeviceIds;

  /// Resolves `true` when ads may be requested.
  Future<bool> gatherConsent() async {
    final done = Completer<bool>();
    final params = ConsentRequestParameters(
      consentDebugSettings: !forceEea
          ? null
          : ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              testIdentifiers: testDeviceIds,
            ),
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        unawaited(ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint('[consent] form error: ${formError.message}');
          }
          done.complete(await ConsentInformation.instance.canRequestAds());
        }));
      },
      (error) async {
        debugPrint('[consent] update error: ${error.message}');
        // Outside consent regions canRequestAds() is still true.
        done.complete(await ConsentInformation.instance.canRequestAds());
      },
    );
    return done.future;
  }

  /// Show the privacy options form (settings screen link) if the user is
  /// in a region where it is required.
  Future<void> showPrivacyOptions() async {
    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    if (status == PrivacyOptionsRequirementStatus.required) {
      unawaited(ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          debugPrint('[consent] privacy options error: ${formError.message}');
        }
      }));
    }
  }

  /// Ask for App Tracking Transparency permission on iOS.
  ///
  /// The ads SDK does **not** do this: UMP covers GDPR consent, while ATT is
  /// Apple's separate gate on the IDFA. Without it iOS serves only
  /// non-personalised ads, which is a large eCPM cut, and the
  /// NSUserTrackingUsageDescription in Info.plist is dead weight.
  ///
  /// Call it *after* [gatherConsent] (Google requires that order) and only
  /// once the app is actually on screen — iOS silently denies the request
  /// when the app is not yet active, which is why this is not run before
  /// `runApp`. No-op on Android and on repeat calls.
  Future<TrackingStatus> requestTracking() async {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return status;
    return AppTrackingTransparency.requestTrackingAuthorization();
  }

  /// Dev only: forget consent so the form shows again.
  Future<void> reset() => ConsentInformation.instance.reset();
}
