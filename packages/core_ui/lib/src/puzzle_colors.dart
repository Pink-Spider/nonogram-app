import 'package:flutter/material.dart';

/// Board colours as a ThemeExtension so every rule package's painter
/// reads the same palette and light/dark just works.
@immutable
class PuzzleColors extends ThemeExtension<PuzzleColors> {
  const PuzzleColors({
    required this.boardBackground,
    required this.gridLine,
    required this.gridLineBold,
    required this.given,
    required this.entry,
    required this.entryWrong,
    required this.note,
    required this.selected,
    required this.peerHighlight,
    required this.sameValueHighlight,
    required this.conflict,
    required this.hintHighlight,
  });

  final Color boardBackground;
  final Color gridLine;
  final Color gridLineBold;
  final Color given;
  final Color entry;
  final Color entryWrong;
  final Color note;
  final Color selected;
  final Color peerHighlight;
  final Color sameValueHighlight;
  final Color conflict;
  final Color hintHighlight;

  static const light = PuzzleColors(
    boardBackground: Colors.white,
    gridLine: Color(0xFFBDBDBD),
    gridLineBold: Color(0xFF212121),
    given: Color(0xFF212121),
    entry: Color(0xFF1565C0),
    entryWrong: Color(0xFFD32F2F),
    note: Color(0xFF757575),
    selected: Color(0xFFBBDEFB),
    peerHighlight: Color(0xFFE3F2FD),
    sameValueHighlight: Color(0xFFC5CAE9),
    conflict: Color(0xFFFFCDD2),
    hintHighlight: Color(0xFFFFF59D),
  );

  static const dark = PuzzleColors(
    boardBackground: Color(0xFF121212),
    gridLine: Color(0xFF424242),
    gridLineBold: Color(0xFFE0E0E0),
    given: Color(0xFFEEEEEE),
    entry: Color(0xFF64B5F6),
    entryWrong: Color(0xFFEF5350),
    note: Color(0xFF9E9E9E),
    selected: Color(0xFF1E3A5F),
    peerHighlight: Color(0xFF1C2833),
    sameValueHighlight: Color(0xFF2C3E6B),
    conflict: Color(0xFF5C1F1F),
    hintHighlight: Color(0xFF5C5320),
  );

  static PuzzleColors of(BuildContext context) =>
      Theme.of(context).extension<PuzzleColors>() ?? light;

  @override
  PuzzleColors copyWith() => this;

  @override
  PuzzleColors lerp(ThemeExtension<PuzzleColors>? other, double t) {
    if (other is! PuzzleColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PuzzleColors(
      boardBackground: l(boardBackground, other.boardBackground),
      gridLine: l(gridLine, other.gridLine),
      gridLineBold: l(gridLineBold, other.gridLineBold),
      given: l(given, other.given),
      entry: l(entry, other.entry),
      entryWrong: l(entryWrong, other.entryWrong),
      note: l(note, other.note),
      selected: l(selected, other.selected),
      peerHighlight: l(peerHighlight, other.peerHighlight),
      sameValueHighlight: l(sameValueHighlight, other.sameValueHighlight),
      conflict: l(conflict, other.conflict),
      hintHighlight: l(hintHighlight, other.hintHighlight),
    );
  }
}
