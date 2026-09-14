import 'grid_puzzle.dart';
import 'hint.dart';
import 'move.dart';
import 'puzzle_rule.dart';

enum GameStatus { playing, solved, failed }

/// Outcome of [GameSession.place].
enum PlaceResult {
  /// Value placed and it matches the solution.
  correct,

  /// Value placed but wrong; a mistake was counted.
  mistake,

  /// Nothing changed (given cell, game over, or same value already there).
  ignored,
}

/// Mutable state of one play-through of a [GridPuzzle].
///
/// Pure Dart, no Flutter dependency, so all game logic is unit-testable and
/// trivially serialisable for "continue game". The UI layer (Riverpod
/// notifier) wraps this and calls [snapshot] after every mutation.
class GameSession {
  GameSession({
    required this.puzzle,
    required this.rule,
    this.maxMistakes = 3,
  })  : _board = List<int>.of(puzzle.givens),
        _notes = List<Set<int>>.generate(puzzle.cellCount, (_) => <int>{});

  final GridPuzzle puzzle;
  final PuzzleRule rule;

  /// Mistakes allowed before [GameStatus.failed]. `0` disables the limit.
  final int maxMistakes;

  final List<int> _board;
  final List<Set<int>> _notes;
  final List<Move> _history = [];

  int _mistakes = 0;
  int _hintsUsed = 0;
  int _continues = 0;
  Duration elapsed = Duration.zero;
  bool notesMode = false;
  int? selectedIndex;

  // ---------------------------------------------------------------- reads

  List<int> get board => List.unmodifiable(_board);

  int valueAt(int index) => _board[index];

  Set<int> notesAt(int index) => Set.unmodifiable(_notes[index]);

  int get mistakes => _mistakes;
  int get hintsUsed => _hintsUsed;
  int get continuesUsed => _continues;
  bool get canUndo => _history.isNotEmpty;

  bool isGiven(int index) => puzzle.isGiven(index);

  bool isCorrect(int index) =>
      _board[index] != 0 && _board[index] == puzzle.solution[index];

  bool isWrong(int index) =>
      _board[index] != 0 && _board[index] != puzzle.solution[index];

  int get emptyCount => _board.where((v) => v == 0).length;

  bool get isSolved {
    for (var i = 0; i < _board.length; i++) {
      if (_board[i] != puzzle.solution[i]) return false;
    }
    return true;
  }

  bool get isFailed => maxMistakes > 0 && _mistakes >= maxMistakes;

  GameStatus get status {
    if (isSolved) return GameStatus.solved;
    if (isFailed) return GameStatus.failed;
    return GameStatus.playing;
  }

  /// How many times [value] currently appears on the board (for greying out
  /// completed digits on the number pad).
  int countOf(int value) => _board.where((v) => v == value).length;

  List<int> conflictsAt(int index) {
    final v = _board[index];
    if (v == 0) return const [];
    return rule.conflicts(_board, index, v);
  }

  // ------------------------------------------------------------- mutations

  /// Place [value] into [index]. Respects [notesMode]: in notes mode the
  /// value is toggled as a pencil mark instead.
  PlaceResult place(int index, int value) {
    if (status != GameStatus.playing) return PlaceResult.ignored;
    if (isGiven(index)) return PlaceResult.ignored;
    if (value < 1 || value > rule.maxValue) return PlaceResult.ignored;

    if (notesMode) {
      toggleNote(index, value);
      return PlaceResult.ignored;
    }
    if (_board[index] == value) return PlaceResult.ignored;

    final prevNotes = Set<int>.of(_notes[index]);
    _history.add(Move(
      index: index,
      previousValue: _board[index],
      newValue: value,
      previousNotes: prevNotes,
      newNotes: const <int>{},
    ));
    _board[index] = value;
    _notes[index].clear();

    if (rule.isCorrect(index, value, puzzle.solution)) {
      _clearPeerNotes(index, value);
      return PlaceResult.correct;
    }
    _mistakes++;
    return PlaceResult.mistake;
  }

  void toggleNote(int index, int value) {
    if (status != GameStatus.playing) return;
    if (isGiven(index) || _board[index] != 0) return;
    final prev = Set<int>.of(_notes[index]);
    if (!_notes[index].remove(value)) _notes[index].add(value);
    _history.add(Move(
      index: index,
      previousValue: 0,
      newValue: 0,
      previousNotes: prev,
      newNotes: Set<int>.of(_notes[index]),
    ));
  }

  void erase(int index) {
    if (status != GameStatus.playing) return;
    if (isGiven(index)) return;
    if (_board[index] == 0 && _notes[index].isEmpty) return;
    _history.add(Move(
      index: index,
      previousValue: _board[index],
      newValue: 0,
      previousNotes: Set<int>.of(_notes[index]),
      newNotes: const <int>{},
    ));
    _board[index] = 0;
    _notes[index].clear();
  }

  /// Revert the last move. Mistake count is intentionally *not* reverted.
  bool undo() {
    if (_history.isEmpty || isFailed) return false;
    final m = _history.removeLast();
    _board[m.index] = m.previousValue;
    _notes[m.index]
      ..clear()
      ..addAll(m.previousNotes);
    return true;
  }

  /// Ask the rule for an explained step; fall back to revealing the
  /// selected (or first empty / wrong) cell. Applies the hint to the board.
  Hint useHint() {
    var hint = rule.nextHint(_board, puzzle);
    if (hint == null) {
      var target = selectedIndex;
      if (target == null || isGiven(target) || isCorrect(target)) {
        target = _firstFixableCell();
      }
      hint = Hint(
        index: target,
        value: puzzle.solution[target],
        techniqueId: 'reveal',
      );
    }
    _hintsUsed++;
    _history.add(Move(
      index: hint.index,
      previousValue: _board[hint.index],
      newValue: hint.value,
      previousNotes: Set<int>.of(_notes[hint.index]),
      newNotes: const <int>{},
    ));
    _board[hint.index] = hint.value;
    _notes[hint.index].clear();
    _clearPeerNotes(hint.index, hint.value);
    return hint;
  }

  /// Rewarded-ad "second chance": leaves one mistake of headroom.
  void continueAfterFail() {
    if (!isFailed) return;
    _mistakes = maxMistakes - 1;
    _continues++;
  }

  // -------------------------------------------------------------- helpers

  void _clearPeerNotes(int index, int value) {
    for (final p in rule.peers(index)) {
      _notes[p].remove(value);
    }
  }

  int _firstFixableCell() {
    for (var i = 0; i < _board.length; i++) {
      if (!isGiven(i) && _board[i] != puzzle.solution[i]) return i;
    }
    return 0;
  }

  // -------------------------------------------------------- persistence

  Map<String, Object?> toJson() => {
        'puzzle': puzzle.toJson(),
        'board': _board,
        'notes': _notes.map((s) => s.toList()..sort()).toList(),
        'mistakes': _mistakes,
        'hintsUsed': _hintsUsed,
        'continues': _continues,
        'elapsedMs': elapsed.inMilliseconds,
        'maxMistakes': maxMistakes,
      };

  /// Restore a saved session. Undo history is not persisted.
  static GameSession fromJson(Map<String, Object?> json, PuzzleRule rule) {
    final puzzle =
        GridPuzzle.fromJson(json['puzzle']! as Map<String, Object?>);
    final s = GameSession(
      puzzle: puzzle,
      rule: rule,
      maxMistakes: (json['maxMistakes'] as int?) ?? 3,
    );
    final board = (json['board'] as List<Object?>).cast<int>();
    for (var i = 0; i < board.length; i++) {
      s._board[i] = board[i];
    }
    final notes = (json['notes'] as List<Object?>? ?? const []);
    for (var i = 0; i < notes.length && i < s._notes.length; i++) {
      s._notes[i].addAll((notes[i] as List<Object?>).cast<int>());
    }
    s._mistakes = (json['mistakes'] as int?) ?? 0;
    s._hintsUsed = (json['hintsUsed'] as int?) ?? 0;
    s._continues = (json['continues'] as int?) ?? 0;
    s.elapsed = Duration(milliseconds: (json['elapsedMs'] as int?) ?? 0);
    return s;
  }
}
