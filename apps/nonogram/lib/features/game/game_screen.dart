import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:rules_nonogram/rules_nonogram.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../home/widgets/banner_slot.dart';
import 'game_controller.dart';
import 'shape_names.dart';
import 'widgets/game_toolbar.dart';
import 'widgets/nonogram_board.dart';
import 'widgets/solved_card.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> with WidgetsBindingObserver {
  GameStatus? _shownDialogFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = ref.read(gameControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        c.resumeTimer();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        c.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    // The failure dialog, once per status transition. Solving shows no
    // dialog — the board becomes the picture and SolvedCard slides up.
    ref.listen<GameViewState?>(gameControllerProvider, (prev, next) {
      if (next == null) return;
      if (next.status == GameStatus.failed && _shownDialogFor != next.status) {
        _shownDialogFor = next.status;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_showFailed(next));
        });
      }
      if (next.status == GameStatus.playing) _shownDialogFor = null;
    });

    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.pause();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_difficultyLabel(l, state.puzzle.difficulty)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Expanded rather than a trailing Spacer: on a tall phone the
              // board is width-bound, and a Spacer dumped all the slack into
              // one gap under it. Centring splits the slack above and below,
              // and the status row rides with the board because it describes
              // the board, not the screen.
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${l.mistakes}: '
                                '${l.mistakesCount(state.mistakes, state.maxMistakes)}'),
                            if (state.isDaily)
                              const Icon(Icons.calendar_today, size: 18),
                            Text('${l.time}: ${formatDuration(state.elapsed)}'),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: NonogramBoard(
                            size: state.puzzle.size,
                            board: state.board,
                            rowClues:
                                NonogramGenerator.rowCluesOf(state.puzzle),
                            colClues:
                                NonogramGenerator.colCluesOf(state.puzzle),
                            selected: state.selected,
                            highlight: state.hintHighlight,
                            mistakes: state.mistakeCells,
                            solved: state.status == GameStatus.solved,
                            onCellTap: controller.tapCell,
                            onCellDrag: controller.dragCell,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.status == GameStatus.solved)
                SolvedCard(
                  title: _solvedTitle(l, state),
                  subtitle: l.solvedBody(
                    _difficultyLabel(l, state.puzzle.difficulty),
                    formatDuration(state.elapsed),
                    state.mistakes,
                  ),
                  note: state.isDaily ? l.dailySolvedNote : null,
                  homeLabel: l.backHome,
                  playAgainLabel: l.playAgain,
                  onHome: () => unawaited(_goHome()),
                  onPlayAgain: () =>
                      unawaited(_playAgain(state.puzzle.difficulty)),
                )
              else ...[
                // Fixed height so showing a hint does not shove the board and
                // the number pad around mid-game.
                SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: state.lastHint != null && state.hintHighlight.isNotEmpty
                          ? Text(
                              _techniqueText(l, state.lastHint!.techniqueId),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                GameToolbar(
                  canUndo: state.canUndo,
                  crossMode: state.crossMode,
                  freeHintsLeft: state.freeHintsLeft,
                  onUndo: controller.undo,
                  onErase: controller.erase,
                  onToggleCross: controller.toggleCrossMode,
                  onHint: () => _onHint(controller),
                ),
              ],
              const BannerSlot(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onHint(GameController controller) async {
    final l = AppLocalizations.of(context);
    final outcome = await controller.requestHint();
    if (!mounted) return;
    if (outcome == HintOutcome.adNotReady) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.adNotReady)));
    }
  }

  /// "You drew: Cat!" — falls back to the plain solved title if the puzzle
  /// somehow carries no shape (it always should).
  static String _solvedTitle(AppLocalizations l, GameViewState s) {
    final shape = NonogramGenerator.shapeOf(s.puzzle);
    return shape == null
        ? l.solvedTitle
        : l.youDrew(shapeDisplayName(l, shape.id));
  }

  Future<void> _goHome() async {
    final controller = ref.read(gameControllerProvider.notifier);
    await controller.maybeShowInterstitial();
    await controller.abandon();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _playAgain(Difficulty difficulty) async {
    final controller = ref.read(gameControllerProvider.notifier);
    await controller.maybeShowInterstitial();
    if (!mounted) return;
    await controller.startNew(difficulty);
  }

  Future<void> _showFailed(GameViewState s) async {
    final l = AppLocalizations.of(context);
    final controller = ref.read(gameControllerProvider.notifier);
    final ads = ref.read(adServiceProvider);
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l.failedTitle),
        content: Text(l.failedBody(s.maxMistakes)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'giveup'), child: Text(l.giveUp)),
          RewardButton(
            label: l.watchAdToContinue,
            ready: ads.isRewardedReady,
            onPressed: () => Navigator.pop(context, 'continue'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'continue') {
      final ok = await controller.continueWithAd();
      if (!ok && mounted) {
        // Ad skipped or unavailable: let them try again.
        _shownDialogFor = null;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.adNotReady)));
        unawaited(_showFailed(s));
      }
      return;
    }
    await controller.maybeShowInterstitial();
    await controller.abandon();
    if (mounted) Navigator.of(context).pop();
  }

  static String _difficultyLabel(AppLocalizations l, Difficulty d) => switch (d) {
        Difficulty.easy => l.difficultyEasy,
        Difficulty.medium => l.difficultyMedium,
        Difficulty.hard => l.difficultyHard,
        Difficulty.expert => l.difficultyExpert,
      };

  /// Ids come from [NonogramRule.nextHint]; the fallback covers the
  /// engine's reveal when no line can prove anything.
  static String _techniqueText(AppLocalizations l, String techniqueId) => switch (techniqueId) {
        'row_forces' => l.techniqueRowForces,
        'row_blanks' => l.techniqueRowBlanks,
        'col_forces' => l.techniqueColForces,
        'col_blanks' => l.techniqueColBlanks,
        _ => l.techniqueReveal,
      };
}
