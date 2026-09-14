import 'dart:async';

import 'package:core_analytics/core_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:rules_nonogram/rules_nonogram.dart';

import '../../app/providers.dart';

/// Immutable snapshot of the session for the widget tree.
@immutable
class GameViewState {
  const GameViewState({
    required this.puzzle,
    required this.board,
    required this.notes,
    required this.status,
    required this.mistakes,
    required this.maxMistakes,
    required this.elapsed,
    required this.notesMode,
    required this.crossMode,
    required this.canUndo,
    required this.freeHintsLeft,
    required this.isDaily,
    this.selected,
    this.lastHint,
    this.hintHighlight = const {},
    this.mistakeCells = const {},
  });

  final GridPuzzle puzzle;
  final List<int> board;
  final List<Set<int>> notes;
  final GameStatus status;
  final int mistakes;
  final int maxMistakes;
  final Duration elapsed;
  final bool notesMode;

  /// True when taps leave a cross instead of a fill.
  final bool crossMode;
  final bool canUndo;
  final int freeHintsLeft;
  final bool isDaily;
  final int? selected;
  final Hint? lastHint;
  final Set<int> hintHighlight;

  /// Filled cells that contradict the picture. Only fills are flagged —
  /// a cross on a cell that should be filled is a mistake too, but marking
  /// it would give away that the cell is filled.
  final Set<int> mistakeCells;

  int get size => puzzle.size;
}

enum HintOutcome { applied, adNotReady, adSkipped, notPlaying }

/// Adds progress persistence, the timer and ad-gated actions on top of
/// the pure [GameSession].
class GameController extends Notifier<GameViewState?> {
  GameSession? _session;
  bool _isDaily = false;
  int _freeHintsLeft = 0;
  Timer? _timer;
  Set<int> _hintHighlight = const {};
  Hint? _lastHint;

  @override
  GameViewState? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  // ------------------------------------------------------------ lifecycle

  /// Restore a saved game if there is one. Returns whether it did.
  bool resume() {
    final saved = ref
        .read(gamePersistenceProvider)
        .loadSession((size) => NonogramRule(size: size));
    if (saved == null) return false;
    _attach(saved.$1, isDaily: saved.$2);
    return true;
  }

  /// Generate and start a new puzzle. Generation runs off the UI isolate.
  Future<void> startNew(Difficulty difficulty, {int? seed, bool isDaily = false}) async {
    // The rule has to match the board this difficulty produces — a size-10
    // rule against a 5x5 board walks off the end of it in conflicts().
    final rule = NonogramRule.forDifficulty(difficulty);
    final actualSeed = seed ?? DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    final puzzle = await compute(_generate, (rule, difficulty, actualSeed));
    final maxMistakes =
        ref.read(remoteConfigProvider).getInt(RemoteConfigKeys.maxMistakes);
    _attach(
      GameSession(puzzle: puzzle, rule: rule, maxMistakes: maxMistakes),
      isDaily: isDaily,
      fresh: true,
    );
    unawaited(ref.read(analyticsProvider).logEvent(AnalyticsEvents.puzzleStart, {
      AnalyticsParams.rule: puzzle.ruleId,
      AnalyticsParams.difficulty: difficulty.id,
      AnalyticsParams.seed: puzzle.seed,
      AnalyticsParams.isDaily: isDaily,
    }));
  }

  Future<void> startDaily(Difficulty difficulty) {
    final seed = DailySeed.forDate(DateTime.now(), salt: 1);
    return startNew(difficulty, seed: seed, isDaily: true);
  }

  void _attach(GameSession session, {required bool isDaily, bool fresh = false}) {
    _timer?.cancel();
    // conflicts() is called per tap and the engine does not hand the rule a
    // puzzle, so the clues have to be bound here.
    NonogramRule.bind(session.puzzle);
    _session = session;
    _isDaily = isDaily;
    _hintHighlight = const {};
    _lastHint = null;
    if (fresh) {
      _freeHintsLeft =
          ref.read(remoteConfigProvider).getInt(RemoteConfigKeys.freeHintsPerPuzzle);
    }
    // On resume the free-hint counter is intentionally not restored —
    // persisting it would make "restart the app" a free hint exploit.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _publish(save: fresh);
  }

  void _tick() {
    final s = _session;
    if (s == null || s.status != GameStatus.playing) return;
    s.elapsed += const Duration(seconds: 1);
    // Persist every 10 s so a kill loses at most that much time.
    _publish(save: s.elapsed.inSeconds % 10 == 0);
  }

  /// Called by the screen when it goes to background.
  void pause() {
    _timer?.cancel();
    _timer = null;
    _persist();
  }

  void resumeTimer() {
    if (_session == null || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> abandon() async {
    final s = _session;
    if (s != null && s.status == GameStatus.playing) {
      unawaited(ref.read(analyticsProvider).logEvent(AnalyticsEvents.puzzleAbandon, _params(s)));
    }
    _timer?.cancel();
    _timer = null;
    _session = null;
    await ref.read(gamePersistenceProvider).clearSession();
    state = null;
  }

  // ---------------------------------------------------------------- input

  void select(int index) {
    final s = _session;
    if (s == null) return;
    s.selectedIndex = index;
    _hintHighlight = const {};
    _publish();
  }

  void input(int value) {
    final s = _session;
    final i = s?.selectedIndex;
    if (s == null || i == null) return;
    final result = s.place(i, value);
    _hintHighlight = const {};
    if (result == PlaceResult.mistake) {
      unawaited(ref.read(analyticsProvider).logEvent(AnalyticsEvents.mistake, _params(s)));
    }
    _afterMutation(s);
  }

  void erase() {
    final s = _session;
    final i = s?.selectedIndex;
    if (s == null || i == null) return;
    s.erase(i);
    _afterMutation(s);
  }

  void undo() {
    final s = _session;
    if (s == null) return;
    s.undo();
    _afterMutation(s);
  }

  /// Fill vs cross. A nonogram has no digits to pick, so the toolbar
  /// toggles which mark a tap leaves. Mapped onto the engine's notes flag
  /// purely for persistence — [GameSession.place] is always called with a
  /// real value, never as a note.
  void toggleCrossMode() {
    final s = _session;
    if (s == null) return;
    _crossMode = !_crossMode;
    _publish();
  }

  bool _crossMode = false;

  /// Tap a cell: apply the current mark, or clear it if it is already there.
  void tapCell(int index) {
    final s = _session;
    if (s == null || s.status != GameStatus.playing) return;
    s.selectedIndex = index;
    final wanted = _crossMode ? Cell.crossed : Cell.filled;
    if (s.valueAt(index) == wanted) {
      s.erase(index);
      _hintHighlight = const {};
      _afterMutation(s);
      return;
    }
    _placeAt(s, index, wanted);
  }

  /// Drag across cells to paint them.
  ///
  /// Painting only ever *sets* the current mark — never clears — so a drag
  /// that crosses an already-marked cell does not flicker it off. Erasing
  /// stays a deliberate tap.
  void dragCell(int index) {
    final s = _session;
    if (s == null || s.status != GameStatus.playing) return;
    final wanted = _crossMode ? Cell.crossed : Cell.filled;
    if (s.valueAt(index) == wanted) return;
    s.selectedIndex = index;
    _placeAt(s, index, wanted);
  }

  void _placeAt(GameSession s, int index, int value) {
    final result = s.place(index, value);
    _hintHighlight = const {};
    if (result == PlaceResult.mistake) {
      unawaited(ref.read(analyticsProvider).logEvent(AnalyticsEvents.mistake, _params(s)));
    }
    _afterMutation(s);
  }

  // ----------------------------------------------------------------- hints

  Future<HintOutcome> requestHint() async {
    final s = _session;
    if (s == null || s.status != GameStatus.playing) return HintOutcome.notPlaying;

    if (_freeHintsLeft > 0) {
      _freeHintsLeft--;
      _applyHint(s, paid: false);
      return HintOutcome.applied;
    }

    final ads = ref.read(adServiceProvider);
    final analytics = ref.read(analyticsProvider);
    unawaited(analytics.logEvent(AnalyticsEvents.adRewardedOffered, {
      AnalyticsParams.placement: RewardPlacement.hint,
    }));
    if (!ads.isRewardedReady) {
      unawaited(analytics.logEvent(AnalyticsEvents.adRewardedUnavailable, {
        AnalyticsParams.placement: RewardPlacement.hint,
      }));
      return HintOutcome.adNotReady;
    }
    pause();
    final earned = await ads.showRewarded();
    resumeTimer();
    if (!earned) {
      unawaited(analytics.logEvent(AnalyticsEvents.adRewardedSkipped, {
        AnalyticsParams.placement: RewardPlacement.hint,
      }));
      return HintOutcome.adSkipped;
    }
    unawaited(analytics.logEvent(AnalyticsEvents.adRewardedEarned, {
      AnalyticsParams.placement: RewardPlacement.hint,
    }));
    _applyHint(s, paid: true);
    return HintOutcome.applied;
  }

  void _applyHint(GameSession s, {required bool paid}) {
    final hint = s.useHint();
    s.selectedIndex = hint.index;
    _lastHint = hint;
    _hintHighlight = {...hint.highlight, hint.index};
    unawaited(ref.read(analyticsProvider).logEvent(AnalyticsEvents.hintUsed, {
      ..._params(s),
      'technique': hint.techniqueId,
      'paid': paid,
    }));
    _afterMutation(s);
  }

  // -------------------------------------------------------------- continue

  /// Rewarded "second chance" after running out of mistakes.
  Future<bool> continueWithAd() async {
    final s = _session;
    if (s == null || !s.isFailed) return false;
    final ads = ref.read(adServiceProvider);
    final analytics = ref.read(analyticsProvider);
    unawaited(analytics.logEvent(AnalyticsEvents.adRewardedOffered, {
      AnalyticsParams.placement: RewardPlacement.continueGame,
    }));
    if (!ads.isRewardedReady) return false;
    final earned = await ads.showRewarded();
    if (!earned) {
      unawaited(analytics.logEvent(AnalyticsEvents.adRewardedSkipped, {
        AnalyticsParams.placement: RewardPlacement.continueGame,
      }));
      return false;
    }
    s.continueAfterFail();
    unawaited(analytics.logEvent(AnalyticsEvents.continueUsed, _params(s)));
    resumeTimer();
    _publish(save: true);
    return true;
  }

  /// Natural-break interstitial. Call when the player leaves a finished
  /// puzzle (after the result dialog), never mid-game.
  Future<void> maybeShowInterstitial() async {
    final gate = ref.read(interstitialGateProvider);
    if (!gate.shouldShowOnEvent()) return;
    final shown = await ref.read(adServiceProvider).showInterstitial();
    if (shown) {
      gate.markShown();
      unawaited(ref.read(analyticsProvider).logEvent(AnalyticsEvents.adInterstitialShown));
    }
  }

  // -------------------------------------------------------------- helpers

  void _afterMutation(GameSession s) {
    final status = s.status;
    if (status != GameStatus.playing) {
      _timer?.cancel();
      _timer = null;
      final analytics = ref.read(analyticsProvider);
      final persistence = ref.read(gamePersistenceProvider);
      if (status == GameStatus.solved) {
        unawaited(analytics.logEvent(AnalyticsEvents.puzzleComplete, _params(s)));
        unawaited(persistence.incrementSolved(s.puzzle.difficulty));
        if (_isDaily) unawaited(persistence.markDailyDone(DateTime.now()));
        unawaited(persistence.clearSession());
      } else {
        unawaited(analytics.logEvent(AnalyticsEvents.puzzleFail, _params(s)));
      }
    }
    _publish(save: status == GameStatus.playing || status == GameStatus.failed);
  }

  void _publish({bool save = false}) {
    final s = _session;
    if (s == null) {
      state = null;
      return;
    }
    state = GameViewState(
      puzzle: s.puzzle,
      board: s.board,
      notes: [for (var i = 0; i < s.puzzle.cellCount; i++) s.notesAt(i)],
      status: s.status,
      mistakes: s.mistakes,
      maxMistakes: s.maxMistakes,
      elapsed: s.elapsed,
      notesMode: s.notesMode,
      crossMode: _crossMode,
      canUndo: s.canUndo,
      freeHintsLeft: _freeHintsLeft,
      isDaily: _isDaily,
      selected: s.selectedIndex,
      lastHint: _lastHint,
      hintHighlight: _hintHighlight,
      mistakeCells: {
        for (var i = 0; i < s.puzzle.cellCount; i++)
          if (s.valueAt(i) == Cell.filled &&
              s.puzzle.solution[i] != Cell.filled)
            i,
      },
    );
    if (save) _persist();
  }

  void _persist() {
    final s = _session;
    if (s == null || s.status == GameStatus.solved) return;
    unawaited(ref.read(gamePersistenceProvider).saveSession(s, isDaily: _isDaily));
  }

  Map<String, Object> _params(GameSession s) => {
        AnalyticsParams.rule: s.puzzle.ruleId,
        AnalyticsParams.difficulty: s.puzzle.difficulty.id,
        AnalyticsParams.isDaily: _isDaily,
        AnalyticsParams.elapsedSec: s.elapsed.inSeconds,
        AnalyticsParams.mistakes: s.mistakes,
        AnalyticsParams.hints: s.hintsUsed,
      };
}

/// Top-level so it can run in a background isolate via [compute].
GridPuzzle _generate((PuzzleRule, Difficulty, int) args) =>
    args.$1.generate(difficulty: args.$2, seed: args.$3);

final gameControllerProvider =
    NotifierProvider<GameController, GameViewState?>(GameController.new);

/// True while a puzzle is being generated.
final generatingProvider = StateProvider<bool>((_) => false);

/// Ad-free window end (persisted). Banner and gate read this.
final adFreeUntilProvider = StateProvider<DateTime?>(
  (ref) => ref.read(gamePersistenceProvider).adFreeUntil,
);
