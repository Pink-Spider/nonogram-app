import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import 'streak.dart';

/// Streaks and per-difficulty records. Reads SharedPreferences directly on
/// build — the numbers only change while this screen is not on top.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final persistence = ref.watch(gamePersistenceProvider);
    final done = persistence.dailyDoneDates();
    final current = currentStreak(done, DateTime.now());
    final longest = longestStreak(done);

    return Scaffold(
      appBar: AppBar(title: Text(l.statsTitle), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row(context, l.dailyStreak, '🔥 ${l.streakDays(current)}'),
                    const SizedBox(height: 8),
                    _row(context, l.longestStreak, l.streakDays(longest)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        const SizedBox.shrink(),
                        _header(context, l.statSolved),
                        _header(context, l.statBestTime),
                      ],
                    ),
                    for (final d in Difficulty.values)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(_label(l, d)),
                          ),
                          _value(context, '${persistence.solvedCount(d)}'),
                          _value(
                            context,
                            switch (persistence.bestTime(d)) {
                              null => '—',
                              final t => formatDuration(t),
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      );

  Widget _header(BuildContext context, String text) => Text(
        text,
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.labelMedium,
      );

  Widget _value(BuildContext context, String text) => Text(
        text,
        textAlign: TextAlign.end,
      );

  static String _label(AppLocalizations l, Difficulty d) => switch (d) {
        Difficulty.easy => l.difficultyEasy,
        Difficulty.medium => l.difficultyMedium,
        Difficulty.hard => l.difficultyHard,
        Difficulty.expert => l.difficultyExpert,
      };
}
