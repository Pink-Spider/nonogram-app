import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

/// 2x2 "latin square" rule: rows and columns must not repeat. Enough to
/// exercise the session without pulling in Sudoku.
class _TinyRule extends PuzzleRule {
  @override
  String get id => 'tiny';

  @override
  int get size => 2;

  @override
  GridPuzzle generate({required Difficulty difficulty, required int seed}) =>
      GridPuzzle(
        ruleId: id,
        size: 2,
        givens: const [1, 0, 0, 0],
        solution: const [1, 2, 2, 1],
        difficulty: difficulty,
        seed: seed,
      );

  @override
  List<int> peers(int index) {
    final r = index ~/ 2, c = index % 2;
    return [for (var i = 0; i < 4; i++) if (i != index && (i ~/ 2 == r || i % 2 == c)) i];
  }

  @override
  List<int> conflicts(List<int> board, int index, int value) =>
      peers(index).where((p) => board[p] == value).toList();
}

/// A rule with a nonogram-style annotation value: 9 marks "definitely
/// blank", never appears in a solution, and must not block the win.
class _MarkerRule extends _TinyRule {
  @override
  int get maxValue => 9;

  @override
  GridPuzzle generate({required Difficulty difficulty, required int seed}) =>
      GridPuzzle(
        ruleId: id,
        size: 2,
        givens: const [0, 0, 0, 0],
        // Bottom-right stays blank, like a nonogram's empty cells.
        solution: const [1, 2, 2, 0],
        difficulty: difficulty,
        seed: seed,
      );

  @override
  bool isCorrect(int index, int value, List<int> solution) =>
      value == 9 ? solution[index] == 0 : value == solution[index];
}

void main() {
  late GameSession s;

  setUp(() {
    final rule = _TinyRule();
    s = GameSession(
      puzzle: rule.generate(difficulty: Difficulty.easy, seed: 1),
      rule: rule,
      maxMistakes: 2,
    );
  });

  test('starts from givens and is not solved', () {
    expect(s.board, [1, 0, 0, 0]);
    expect(s.status, GameStatus.playing);
    expect(s.isGiven(0), isTrue);
  });

  test('given cells are immutable', () {
    expect(s.place(0, 2), PlaceResult.ignored);
    s.erase(0);
    expect(s.board[0], 1);
    expect(s.canUndo, isFalse);
  });

  test('correct placement, mistakes and failure', () {
    expect(s.place(1, 2), PlaceResult.correct);
    expect(s.place(2, 1), PlaceResult.mistake);
    expect(s.mistakes, 1);
    expect(s.isWrong(2), isTrue);
    expect(s.conflictsAt(2), [0]);
    expect(s.place(3, 2), PlaceResult.mistake);
    expect(s.status, GameStatus.failed);
    expect(s.place(2, 2), PlaceResult.ignored);
  });

  test('continueAfterFail leaves one mistake of headroom', () {
    s.place(2, 1);
    s.place(3, 2);
    expect(s.isFailed, isTrue);
    s.continueAfterFail();
    expect(s.status, GameStatus.playing);
    expect(s.mistakes, 1);
    expect(s.continuesUsed, 1);
  });

  test('undo restores value and notes but not mistakes', () {
    s.toggleNote(1, 1);
    s.toggleNote(1, 2);
    expect(s.notesAt(1), {1, 2});
    s.place(1, 1); // wrong
    expect(s.notesAt(1), isEmpty);
    expect(s.mistakes, 1);
    expect(s.undo(), isTrue);
    expect(s.board[1], 0);
    expect(s.notesAt(1), {1, 2});
    expect(s.mistakes, 1);
  });

  test('correct placement clears that value from peer notes', () {
    s.toggleNote(2, 2);
    s.toggleNote(3, 2);
    s.place(1, 2); // peers of 1 are 0 and 3
    expect(s.notesAt(3), isEmpty);
    expect(s.notesAt(2), {2});
  });

  test('notes mode routes place() to toggleNote', () {
    s.notesMode = true;
    expect(s.place(1, 2), PlaceResult.ignored);
    expect(s.notesAt(1), {2});
    expect(s.board[1], 0);
  });

  test('hint falls back to reveal and counts', () {
    final h = s.useHint();
    expect(h.techniqueId, 'reveal');
    expect(s.board[h.index], s.puzzle.solution[h.index]);
    expect(s.hintsUsed, 1);
  });

  test('solves', () {
    s.place(1, 2);
    s.place(2, 2);
    s.place(3, 1);
    expect(s.status, GameStatus.solved);
  });

  test('isSolved consults the rule — an annotation value on a blank cell '
      'must not block the win', () {
    final rule = _MarkerRule();
    final session = GameSession(
      puzzle: rule.generate(difficulty: Difficulty.easy, seed: 1),
      rule: rule,
      maxMistakes: 0,
    );
    expect(session.place(3, 9), PlaceResult.correct); // annotate the blank
    session.place(0, 1);
    session.place(1, 2);
    session.place(2, 2);
    // The board is [1,2,2,9] against solution [1,2,2,0]: not equal, but
    // the rule says every cell is in a correct final state.
    expect(session.status, GameStatus.solved);
  });

  test('round-trips through json', () {
    s.place(1, 2);
    s.toggleNote(2, 1);
    s.place(3, 2); // mistake
    s.elapsed = const Duration(seconds: 42);
    final restored = GameSession.fromJson(s.toJson(), _TinyRule());
    expect(restored.board, s.board);
    expect(restored.notesAt(2), {1});
    expect(restored.mistakes, 1);
    expect(restored.elapsed.inSeconds, 42);
    expect(restored.puzzle, s.puzzle);
  });
}
