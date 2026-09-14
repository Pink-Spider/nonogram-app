import 'package:meta/meta.dart';

/// A single explained solving step, shown after the player watches a
/// rewarded ad (or spends a free hint).
@immutable
class Hint {
  const Hint({
    required this.index,
    required this.value,
    required this.techniqueId,
    this.highlight = const [],
  });

  /// Cell to fill.
  final int index;

  /// Value to place.
  final int value;

  /// Technique identifier (`naked_single`, `hidden_single`, `reveal`, ...).
  /// The app maps this to a localized explanation string.
  final String techniqueId;

  /// Cells the explanation refers to (row / column / box that forces the
  /// value). UI highlights them.
  final List<int> highlight;

  @override
  String toString() => 'Hint($techniqueId: cell $index = $value)';
}
