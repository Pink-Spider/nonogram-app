import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Adaptive anchored banner that sizes itself to the screen width and
/// reserves its height before the ad arrives (no layout jump).
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.adUnitId});

  final String adUnitId;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  /// The banner may be built before the ads SDK has finished initialising
  /// (consent and ATT resolve after the first frame), and a load can also
  /// fail on transient no-fill. Retry a few times with backoff rather than
  /// leaving a permanent hole in the layout.
  static const _maxAttempts = 5;

  BannerAd? _ad;
  AdSize? _size;
  bool _loaded = false;
  int _attempt = 0;
  Timer? _retry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) unawaited(_load());
  }

  Future<void> _load() async {
    unawaited(_ad?.dispose() ?? Future<void>.value());
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;
    _size = size;
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() => _ad = null);
          _scheduleRetry();
        },
      ),
    );
    _ad = ad;
    unawaited(ad.load());
    setState(() {});
  }

  void _scheduleRetry() {
    if (_attempt >= _maxAttempts) return;
    final delay = Duration(seconds: 2 << _attempt);
    _attempt++;
    _retry?.cancel();
    _retry = Timer(delay, () {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (size == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: size.width.toDouble(),
        height: size.height.toDouble(),
        child: _loaded && _ad != null ? AdWidget(ad: _ad!) : null,
      ),
    );
  }
}
