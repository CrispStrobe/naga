import 'package:shared_preferences/shared_preferences.dart';

/// Today's best Daily Serpent score and the consecutive-days streak.
///
/// Only the most recent day is stored: a new day's first run replaces the
/// previous best, and extends the streak when that day was yesterday.
class DailyService {
  static const _keyDay = 'daily_day';
  static const _keyBest = 'daily_best';
  static const _keyStreak = 'daily_streak';

  static Future<DailyService>? _pendingInit;
  final SharedPreferences _prefs;

  DailyService._(this._prefs);

  static Future<DailyService> instance() {
    _pendingInit ??= SharedPreferences.getInstance().then(DailyService._);
    return _pendingInit!;
  }

  static int _dayNumber(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  int? get _lastDay => _prefs.getInt(_keyDay);

  /// Best score recorded for [day], or 0 if it has not been played.
  int bestFor(DateTime day) =>
      _lastDay == _dayNumber(day) ? _prefs.getInt(_keyBest) ?? 0 : 0;

  /// Consecutive days played, counting [today] or, if not yet played today,
  /// ending yesterday. A missed day resets it to 0.
  int streakOn(DateTime today) {
    final last = _lastDay;
    if (last == null || _dayNumber(today) - last > 1) return 0;
    return _prefs.getInt(_keyStreak) ?? 0;
  }

  /// Records a finished run. Returns true if it is the day's new best.
  Future<bool> recordRun(DateTime day, int score) async {
    final today = _dayNumber(day);
    final last = _lastDay;
    if (last == today) {
      if (score <= (_prefs.getInt(_keyBest) ?? 0)) return false;
      await _prefs.setInt(_keyBest, score);
      return true;
    }
    // A run on an earlier day than the stored one (clock change) is ignored.
    if (last != null && today < last) return false;
    final streak = last == today - 1 ? (_prefs.getInt(_keyStreak) ?? 0) + 1 : 1;
    await _prefs.setInt(_keyDay, today);
    await _prefs.setInt(_keyBest, score);
    await _prefs.setInt(_keyStreak, streak);
    return true;
  }
}
