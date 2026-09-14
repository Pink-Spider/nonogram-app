import 'package:meta/meta.dart';

/// One reversible board change, recorded for undo.
@immutable
class Move {
  const Move({
    required this.index,
    required this.previousValue,
    required this.newValue,
    required this.previousNotes,
    required this.newNotes,
  });

  final int index;
  final int previousValue;
  final int newValue;
  final Set<int> previousNotes;
  final Set<int> newNotes;

  bool get isNoteOnly => previousValue == newValue;
}
