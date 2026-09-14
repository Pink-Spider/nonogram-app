/// Difficulty tiers shared by every rule package.
///
/// Rule packages decide what each tier *means* (clue count, solving
/// techniques required, ...); the app only cares about the ordering.
enum Difficulty {
  easy,
  medium,
  hard,
  expert;

  /// Stable identifier for storage / analytics (never rename).
  String get id => name;

  static Difficulty fromId(String id) =>
      Difficulty.values.firstWhere((d) => d.id == id, orElse: () => easy);
}
