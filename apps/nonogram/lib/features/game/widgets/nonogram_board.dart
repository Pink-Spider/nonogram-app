import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:rules_nonogram/rules_nonogram.dart';

/// The board: clue strips along the top and left, the grid below and right.
///
/// One [CustomPainter] draws the lot. A widget per cell would mean 400 of
/// them on an expert board, all rebuilding on every tap.
///
/// The clue strips are sized to the longest clue on each axis, so a 5x5
/// spends almost nothing on them while a 20x20 gives them the room they
/// need. Everything scales off the cell size that the remaining space
/// allows, which is what keeps a 20x20 usable on a phone without a
/// separate zoom mode.
class NonogramBoard extends StatelessWidget {
  const NonogramBoard({
    super.key,
    required this.size,
    required this.board,
    required this.rowClues,
    required this.colClues,
    required this.onCellTap,
    required this.onCellDrag,
    this.selected,
    this.highlight = const {},
    this.mistakes = const {},
    this.solved = false,
  });

  final int size;

  /// Row-major, [Cell.unknown] / [Cell.filled] / [Cell.crossed].
  final List<int> board;

  final List<List<int>> rowClues;
  final List<List<int>> colClues;

  /// Tap toggles; the app decides between fill and cross via its mode.
  final void Function(int index) onCellTap;

  /// Dragging across cells paints them — the single most important input
  /// affordance on a big board, where tapping 400 cells is unthinkable.
  final void Function(int index) onCellDrag;

  final int? selected;

  /// Cells a hint is pointing at (the row or column that forces a move).
  final Set<int> highlight;

  /// Cells that contradict the clues.
  final Set<int> mistakes;

  /// Drop the grid lines and dim nothing once the picture is complete, so
  /// the reveal reads as a picture rather than a puzzle.
  final bool solved;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PuzzleColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _BoardMetrics.fit(
          available: constraints.biggest,
          size: size,
          rowClues: rowClues,
          colClues: colClues,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final index = metrics.indexAt(d.localPosition);
            if (index != null) onCellTap(index);
          },
          onPanUpdate: (d) {
            final index = metrics.indexAt(d.localPosition);
            if (index != null) onCellDrag(index);
          },
          child: CustomPaint(
            size: metrics.totalSize,
            painter: _NonogramPainter(
              metrics: metrics,
              board: board,
              rowClues: rowClues,
              colClues: colClues,
              colors: colors,
              clueStyle: textTheme.labelSmall!,
              selected: selected,
              highlight: highlight,
              mistakes: mistakes,
              solved: solved,
            ),
          ),
        );
      },
    );
  }
}

/// Where everything sits. Computed once per layout, then reused by both the
/// painter and hit testing so the two can never disagree.
class _BoardMetrics {
  const _BoardMetrics({
    required this.cell,
    required this.gridOrigin,
    required this.size,
    required this.totalSize,
  });

  /// Edge length of one cell.
  final double cell;

  /// Top-left of the grid itself, below and right of the clue strips.
  final Offset gridOrigin;

  final int size;
  final Size totalSize;

  static _BoardMetrics fit({
    required Size available,
    required int size,
    required List<List<int>> rowClues,
    required List<List<int>> colClues,
  }) {
    // Clue strips take as much as the longest clue needs, and no more.
    final maxRowClue =
        rowClues.fold<int>(1, (m, c) => c.length > m ? c.length : m);
    final maxColClue =
        colClues.fold<int>(1, (m, c) => c.length > m ? c.length : m);

    // Solve for a cell size where grid + strips fit both axes. The strips
    // are expressed in cell units so this stays a single division.
    final unitsWide = size + maxRowClue * _clueUnit;
    final unitsHigh = size + maxColClue * _clueUnit;
    final byWidth = available.width / unitsWide;
    final byHeight = available.height / unitsHigh;
    final cell = (byWidth < byHeight ? byWidth : byHeight).clamp(8.0, 48.0);

    final origin = Offset(maxRowClue * _clueUnit * cell, maxColClue * _clueUnit * cell);
    return _BoardMetrics(
      cell: cell,
      gridOrigin: origin,
      size: size,
      totalSize: Size(origin.dx + size * cell, origin.dy + size * cell),
    );
  }

  /// A clue number needs less room than a cell — they are read as a column
  /// of small digits, not as squares.
  static const double _clueUnit = 0.62;

  Rect cellRect(int index) {
    final row = index ~/ size;
    final col = index % size;
    return Rect.fromLTWH(
      gridOrigin.dx + col * cell,
      gridOrigin.dy + row * cell,
      cell,
      cell,
    );
  }

  /// Which cell is under [point], or null when it is on a clue strip.
  int? indexAt(Offset point) {
    final x = point.dx - gridOrigin.dx;
    final y = point.dy - gridOrigin.dy;
    if (x < 0 || y < 0) return null;
    final col = (x / cell).floor();
    final row = (y / cell).floor();
    if (col < 0 || col >= size || row < 0 || row >= size) return null;
    return row * size + col;
  }
}

class _NonogramPainter extends CustomPainter {
  _NonogramPainter({
    required this.metrics,
    required this.board,
    required this.rowClues,
    required this.colClues,
    required this.colors,
    required this.clueStyle,
    required this.selected,
    required this.highlight,
    required this.mistakes,
    required this.solved,
  });

  final _BoardMetrics metrics;
  final List<int> board;
  final List<List<int>> rowClues;
  final List<List<int>> colClues;
  final PuzzleColors colors;
  final TextStyle clueStyle;
  final int? selected;
  final Set<int> highlight;
  final Set<int> mistakes;
  final bool solved;

  @override
  void paint(Canvas canvas, Size size) {
    _paintHighlights(canvas);
    _paintCells(canvas);
    if (!solved) _paintGrid(canvas);
    _paintClues(canvas);
  }

  void _paintHighlights(Canvas canvas) {
    if (solved) return;
    final paint = Paint()..color = colors.peerHighlight;
    for (final index in highlight) {
      canvas.drawRect(metrics.cellRect(index), paint);
    }
    if (selected != null) {
      canvas.drawRect(
        metrics.cellRect(selected!),
        Paint()..color = colors.selected,
      );
    }
  }

  void _paintCells(Canvas canvas) {
    final fill = Paint()..color = colors.entry;
    final wrong = Paint()..color = colors.entryWrong;
    final crossPaint = Paint()
      ..color = colors.note
      ..strokeWidth = (metrics.cell * 0.09).clamp(1.0, 3.0)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < board.length; i++) {
      final rect = metrics.cellRect(i);
      switch (board[i]) {
        case Cell.filled:
          // Inset so neighbouring filled cells still read as one block but
          // the grid stays legible.
          final inset = solved ? 0.0 : metrics.cell * 0.04;
          canvas.drawRect(
            rect.deflate(inset),
            mistakes.contains(i) ? wrong : fill,
          );
        case Cell.crossed:
          if (solved) break;
          final pad = metrics.cell * 0.3;
          canvas.drawLine(
            rect.topLeft + Offset(pad, pad),
            rect.bottomRight - Offset(pad, pad),
            crossPaint,
          );
          canvas.drawLine(
            rect.topRight + Offset(-pad, pad),
            rect.bottomLeft + Offset(pad, -pad),
            crossPaint,
          );
      }
    }
  }

  void _paintGrid(Canvas canvas) {
    final thin = Paint()
      ..color = colors.gridLine
      ..strokeWidth = 1;
    // Every fifth line is heavier — without it, counting cells on a 20x20
    // is miserable. It is the same crutch the printed puzzles use.
    final thick = Paint()
      ..color = colors.gridLineBold
      ..strokeWidth = 2;

    final n = metrics.size;
    final o = metrics.gridOrigin;
    final extent = n * metrics.cell;

    for (var i = 0; i <= n; i++) {
      final paint = (i % 5 == 0 || i == n) ? thick : thin;
      final offset = i * metrics.cell;
      canvas.drawLine(
        Offset(o.dx + offset, o.dy),
        Offset(o.dx + offset, o.dy + extent),
        paint,
      );
      canvas.drawLine(
        Offset(o.dx, o.dy + offset),
        Offset(o.dx + extent, o.dy + offset),
        paint,
      );
    }
  }

  void _paintClues(Canvas canvas) {
    final style = clueStyle.copyWith(
      fontSize: (metrics.cell * 0.46).clamp(7.0, 16.0),
      color: colors.given,
      height: 1.0,
    );

    for (var r = 0; r < rowClues.length; r++) {
      final clue = _display(rowClues[r]);
      final y = metrics.gridOrigin.dy + (r + 0.5) * metrics.cell;
      // Right-aligned against the grid edge, so the last number is the one
      // nearest the row it describes.
      var x = metrics.gridOrigin.dx - metrics.cell * 0.18;
      for (final n in clue.reversed) {
        final tp = _text('$n', style);
        tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
        x -= tp.width + metrics.cell * 0.2;
      }
    }

    for (var c = 0; c < colClues.length; c++) {
      final clue = _display(colClues[c]);
      final x = metrics.gridOrigin.dx + (c + 0.5) * metrics.cell;
      var y = metrics.gridOrigin.dy - metrics.cell * 0.12;
      for (final n in clue.reversed) {
        final tp = _text('$n', style);
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height));
        y -= tp.height + metrics.cell * 0.08;
      }
    }
  }

  /// `[0]` means an empty line; show it as a single 0 rather than nothing,
  /// so the strip does not look like a rendering bug.
  List<int> _display(List<int> clue) =>
      clue.isEmpty ? const [0] : clue;

  TextPainter _text(String value, TextStyle style) => TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  bool shouldRepaint(_NonogramPainter old) =>
      !identical(old.board, board) ||
      old.selected != selected ||
      old.solved != solved ||
      !setEquals(old.highlight, highlight) ||
      !setEquals(old.mistakes, mistakes);

  static bool setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}
