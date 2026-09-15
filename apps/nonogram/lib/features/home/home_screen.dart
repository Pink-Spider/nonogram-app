import 'package:core_analytics/core_analytics.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../game/game_controller.dart';
import '../game/game_screen.dart';
import '../stats/stats_screen.dart';
import '../tutorial/tutorial_screen.dart';
import 'widgets/banner_slot.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // First launch: teach the rules before showing the menu. Finishing or
    // skipping sets the flag, so this fires exactly once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(gamePersistenceProvider).isTutorialDone) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TutorialScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final persistence = ref.watch(gamePersistenceProvider);
    final generating = ref.watch(generatingProvider);
    final adFreeUntil = ref.watch(adFreeUntilProvider);
    // Rebuild when a game ends / is abandoned so "Continue" stays accurate.
    ref.watch(gameControllerProvider);
    final hasSession = persistence.hasSession;
    final dailyDone = persistence.isDailyDone(DateTime.now());

    Future<void> open(Future<void> Function() start) async {
      ref.read(generatingProvider.notifier).state = true;
      try {
        await start();
      } finally {
        ref.read(generatingProvider.notifier).state = false;
      }
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const GameScreen()),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l.howToPlay,
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TutorialScreen()),
            ),
          ),
          IconButton(
            tooltip: l.statsTitle,
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            tooltip: l.privacySettings,
            icon: const Icon(Icons.privacy_tip_outlined),
            // No-op outside regions where a privacy form is required,
            // which is what showPrivacyOptions() already checks.
            onPressed: () =>
                ref.read(consentManagerProvider).showPrivacyOptions(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: generating
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(l.generating),
                        ],
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (hasSession) ...[
                                FilledButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(l.continueGame),
                                  onPressed: () => open(() async {
                                    ref.read(gameControllerProvider.notifier).resume();
                                  }),
                                ),
                                const SizedBox(height: 12),
                              ],
                              FilledButton.tonalIcon(
                                icon: Icon(dailyDone ? Icons.check_circle : Icons.calendar_today),
                                label: Text(dailyDone ? l.dailyDone : l.dailyChallenge),
                                onPressed: dailyDone
                                    ? null
                                    : () => open(() => ref
                                        .read(gameControllerProvider.notifier)
                                        .startDaily(Difficulty.medium)),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                l.chooseDifficulty,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              for (final d in Difficulty.values)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: OutlinedButton(
                                    onPressed: () => open(
                                      () => ref.read(gameControllerProvider.notifier).startNew(d),
                                    ),
                                    child: Text(_label(l, d)),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              _AdFreeButton(adFreeUntil: adFreeUntil),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            const BannerSlot(),
          ],
        ),
      ),
    );
  }

  static String _label(AppLocalizations l, Difficulty d) => switch (d) {
        Difficulty.easy => l.difficultyEasy,
        Difficulty.medium => l.difficultyMedium,
        Difficulty.hard => l.difficultyHard,
        Difficulty.expert => l.difficultyExpert,
      };
}

/// "Watch an ad → 1 hour without ads". The single best-performing rewarded
/// placement in IAP-less apps: users who hate ads pay with one ad.
class _AdFreeButton extends ConsumerWidget {
  const _AdFreeButton({required this.adFreeUntil});

  final DateTime? adFreeUntil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final until = adFreeUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      final t = TimeOfDay.fromDateTime(until).format(context);
      return Text(l.adFreeActive(t), textAlign: TextAlign.center);
    }
    final ads = ref.watch(adServiceProvider);
    return RewardButton(
      label: l.adFreeHour,
      ready: ads.isRewardedReady,
      onPressed: () async {
        final analytics = ref.read(analyticsProvider);
        await analytics.logEvent(AnalyticsEvents.adRewardedOffered, {
          AnalyticsParams.placement: RewardPlacement.adFreeHour,
        });
        final earned = await ads.showRewarded();
        if (!earned) return;
        final minutes = ref
            .read(remoteConfigProvider)
            .getInt(RemoteConfigKeys.adFreeRewardMinutes);
        final newUntil = DateTime.now().add(Duration(minutes: minutes));
        ref.read(interstitialGateProvider).grantAdFree(Duration(minutes: minutes));
        await ref.read(gamePersistenceProvider).setAdFreeUntil(newUntil);
        ref.read(adFreeUntilProvider.notifier).state = newUntil;
        await analytics.logEvent(AnalyticsEvents.adRewardedEarned, {
          AnalyticsParams.placement: RewardPlacement.adFreeHour,
        });
      },
    );
  }
}
