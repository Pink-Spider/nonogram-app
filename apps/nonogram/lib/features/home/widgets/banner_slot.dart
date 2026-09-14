import 'package:core_analytics/core_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../game/game_controller.dart';

/// Bottom banner placement. Hidden when banners are disabled remotely or
/// during an ad-free window.
class BannerSlot extends ConsumerWidget {
  const BannerSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(remoteConfigProvider).getBool(RemoteConfigKeys.bannerEnabled);
    final adFreeUntil = ref.watch(adFreeUntilProvider);
    final adFree = adFreeUntil != null && DateTime.now().isBefore(adFreeUntil);
    if (!enabled || adFree) return const SizedBox.shrink();
    final banner = ref.watch(adServiceProvider).banner(key: const ValueKey('bottom_banner'));
    return banner ?? const SizedBox.shrink();
  }
}
