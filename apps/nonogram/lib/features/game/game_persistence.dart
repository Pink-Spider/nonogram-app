import 'dart:convert';

import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin key/value persistence. Enough for v1; swap for Drift when stats
/// grow beyond a handful of counters.
class GamePersistence {
  GamePersistence(this._prefs);

  final SharedPreferences _prefs;

  static const _kSession = 'session.current';
  static const _kSessionDaily = 'session.current.isDaily';
  static const _kDailyDone = 'daily.done.'; // + yyyy-MM-dd
  static const _kSolvedCount = 'stats.solved.'; // + difficulty
  static const _kAdFreeUntil = 'ads.adFreeUntilMs';

  // ---------------------------------------------------------- session

  Future<void> saveSession(GameSession session, {required bool isDaily}) async {
    await _prefs.setString(_kSession, jsonEncode(session.toJson()));
    await _prefs.setBool(_kSessionDaily, isDaily);
  }

  /// Returns `(session, isDaily)` or `null` when nothing is saved.
  ///
  /// [ruleFor] is handed the saved board size, because a nonogram's rule
  /// instance is sized per puzzle (5/10/15/20) and the size is only known
  /// once the JSON is open.
  (GameSession, bool)? loadSession(PuzzleRule Function(int size) ruleFor) {
    final raw = _prefs.getString(_kSession);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      final size =
          (json['puzzle'] as Map<String, Object?>?)?['size'] as int? ?? 0;
      if (size <= 0) return null;
      final rule = ruleFor(size);
      final session = GameSession.fromJson(json, rule);
      if (session.puzzle.ruleId != rule.id) return null;
      return (session, _prefs.getBool(_kSessionDaily) ?? false);
    } on Object {
      // Corrupt or from an incompatible version — start fresh.
      return null;
    }
  }

  bool get hasSession => _prefs.containsKey(_kSession);

  Future<void> clearSession() async {
    await _prefs.remove(_kSession);
    await _prefs.remove(_kSessionDaily);
  }

  // ------------------------------------------------------------ daily

  bool isDailyDone(DateTime date) =>
      _prefs.getBool(_kDailyDone + DailySeed.dateKey(date)) ?? false;

  Future<void> markDailyDone(DateTime date) =>
      _prefs.setBool(_kDailyDone + DailySeed.dateKey(date), true);

  // ------------------------------------------------------------ stats

  int solvedCount(Difficulty d) => _prefs.getInt(_kSolvedCount + d.id) ?? 0;

  Future<void> incrementSolved(Difficulty d) =>
      _prefs.setInt(_kSolvedCount + d.id, solvedCount(d) + 1);

  // -------------------------------------------------------------- ads

  DateTime? get adFreeUntil {
    final ms = _prefs.getInt(_kAdFreeUntil);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setAdFreeUntil(DateTime? until) => until == null
      ? _prefs.remove(_kAdFreeUntil)
      : _prefs.setInt(_kAdFreeUntil, until.millisecondsSinceEpoch);
}
