/// Event and parameter names shared across apps so dashboards line up.
/// Keep names ≤ 40 chars, snake_case (Firebase constraints).
class AnalyticsEvents {
  const AnalyticsEvents._();

  static const puzzleStart = 'puzzle_start';
  static const puzzleComplete = 'puzzle_complete';
  static const puzzleFail = 'puzzle_fail';
  static const puzzleAbandon = 'puzzle_abandon';
  static const hintUsed = 'hint_used';
  static const mistake = 'mistake';
  static const continueUsed = 'continue_used';

  static const adInterstitialShown = 'ad_interstitial_shown';
  static const adRewardedOffered = 'ad_rewarded_offered';
  static const adRewardedEarned = 'ad_rewarded_earned';
  static const adRewardedSkipped = 'ad_rewarded_skipped';
  static const adRewardedUnavailable = 'ad_rewarded_unavailable';
}

class AnalyticsParams {
  const AnalyticsParams._();

  static const rule = 'rule';
  static const difficulty = 'difficulty';
  static const seed = 'seed';
  static const isDaily = 'is_daily';
  static const elapsedSec = 'elapsed_sec';
  static const mistakes = 'mistakes';
  static const hints = 'hints';
  static const placement = 'placement';
  static const reward = 'reward';
}

/// Rewarded-ad placements (the `reward` param). One place to see every
/// reason a player might watch an ad.
class RewardPlacement {
  const RewardPlacement._();

  static const hint = 'hint';
  static const continueGame = 'continue';
  static const extraDaily = 'extra_daily';
  static const adFreeHour = 'ad_free_hour';
}
