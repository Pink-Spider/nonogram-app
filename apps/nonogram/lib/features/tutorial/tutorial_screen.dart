import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_nonogram/rules_nonogram.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../game/widgets/nonogram_board.dart';

/// First-run interactive tutorial: solves the 5x5 heart by hand.
///
/// Nonogram rules are not common knowledge the way Sudoku's are, so the
/// first launch walks the player through one real solve — two guided row
/// fills, a guided X, then a free finish. Wrong taps are simply refused
/// with a nudge: the tutorial is a guaranteed win, the real game is where
/// mistakes cost something.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  // The heart is the library's first shape and the friendliest teacher:
  // its two full rows demonstrate "5 = the whole line" instantly.
  static final List<int> _solution = ShapeLibrary.byId('heart')!.toGrid();

  static const _row1 = {5, 6, 7, 8, 9};
  static const _row2 = {10, 11, 12, 13, 14};

  /// Bottom row's clue is 1 (just the centre), so its corners teach the X.
  static const _crossTargets = {20, 21, 23, 24};

  late final _clues =
      NonogramSolver.cluesFor(_solution, width: 5, height: 5);

  final List<int> _board = List<int>.filled(25, Cell.unknown);
  int _step = 0;
  bool _userCross = false;
  bool _showWrong = false;
  Timer? _wrongTimer;

  bool get _done => _step >= 4;

  bool get _crossModeNow => switch (_step) {
        0 || 1 => false,
        2 => true,
        _ => _userCross,
      };

  Set<int> get _highlight => switch (_step) {
        0 => _row1,
        1 => _row2,
        2 => _crossTargets,
        _ => const {},
      };

  @override
  void dispose() {
    _wrongTimer?.cancel();
    super.dispose();
  }

  void _mark(int index, {required bool drag}) {
    if (_done) return;
    final wanted = _crossModeNow ? Cell.crossed : Cell.filled;
    if (_board[index] == wanted) {
      // Free step keeps the real game's tap-again-to-clear; guided steps
      // would just re-open a hole the player already closed.
      if (!drag && _step == 3) setState(() => _board[index] = Cell.unknown);
      return;
    }

    final correct = wanted == Cell.filled
        ? _solution[index] == Cell.filled
        : _solution[index] != Cell.filled;
    final inTargets = switch (_step) {
      0 => _row1.contains(index),
      1 => _row2.contains(index),
      2 => _crossTargets.contains(index),
      _ => true,
    };
    if (!correct || !inTargets) {
      _flashWrong();
      return;
    }

    setState(() {
      _board[index] = wanted;
      _maybeAdvance();
    });
  }

  void _maybeAdvance() {
    bool allMarked(Set<int> targets, int value) =>
        targets.every((i) => _board[i] == value);

    if (_step == 0 && allMarked(_row1, Cell.filled)) _step = 1;
    if (_step == 1 && allMarked(_row2, Cell.filled)) _step = 2;
    if (_step == 2 && allMarked(_crossTargets, Cell.crossed)) _step = 3;
    if (_step == 3) {
      final solved = [
        for (var i = 0; i < _solution.length; i++)
          if (_solution[i] == Cell.filled) i,
      ].every((i) => _board[i] == Cell.filled);
      if (solved) _step = 4;
    }
  }

  void _flashWrong() {
    _wrongTimer?.cancel();
    setState(() => _showWrong = true);
    _wrongTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showWrong = false);
    });
  }

  Future<void> _finish() async {
    await ref.read(gamePersistenceProvider).markTutorialDone();
    if (mounted) Navigator.of(context).pop();
  }

  String _instruction(AppLocalizations l) => switch (_step) {
        0 => l.tutorialFillRow,
        1 => l.tutorialFillRow2,
        2 => l.tutorialCross,
        3 => l.tutorialFinish,
        _ => l.tutorialDoneMsg,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.howToPlay),
        centerTitle: true,
        actions: [
          if (!_done)
            TextButton(onPressed: _finish, child: Text(l.tutorialSkip)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 96,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _instruction(l),
                              key: ValueKey(_step),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: NonogramBoard(
                          size: 5,
                          board: _board,
                          rowClues: _clues.rows,
                          colClues: _clues.cols,
                          highlight: _highlight,
                          solved: _done,
                          onCellTap: (i) => _mark(i, drag: false),
                          onCellDrag: (i) => _mark(i, drag: true),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 28,
                      child: Center(
                        child: _showWrong
                            ? Text(
                                l.tutorialWrong,
                                style: theme.textTheme.bodySmall!.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _done
                  ? FilledButton(
                      onPressed: _finish,
                      child: Text(l.tutorialStart),
                    )
                  : SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.square_rounded),
                          label: Text(l.tutorialFill),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.close),
                          label: Text(l.notes),
                        ),
                      ],
                      selected: {_crossModeNow},
                      // The mode is scripted until the free step so the
                      // guided taps cannot be sabotaged by a stray toggle.
                      onSelectionChanged: _step == 3
                          ? (s) => setState(() => _userCross = s.first)
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
