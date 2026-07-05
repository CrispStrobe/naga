import 'package:shared_preferences/shared_preferences.dart';

class HighScoreService {
  static const _prefix = 'high_score_';

  static HighScoreService? _instance;
  static Future<HighScoreService>? _pendingInit;
  SharedPreferences? _prefs;

  HighScoreService._();

  static Future<HighScoreService> instance() {
    _pendingInit ??= _createInstance();
    return _pendingInit!;
  }

  static Future<HighScoreService> _createInstance() async {
    final service = HighScoreService._();
    service._prefs = await SharedPreferences.getInstance();
    _instance = service;
    return service;
  }

  String _key(String modeName) => '$_prefix${modeName.toLowerCase().replaceAll(' ', '_')}';

  int getHighScore(String modeName) {
    return _prefs?.getInt(_key(modeName)) ?? 0;
  }

  /// Returns true if this is a new high score.
  Future<bool> submitScore(String modeName, int score) async {
    final current = getHighScore(modeName);
    if (score > current) {
      await _prefs!.setInt(_key(modeName), score);
      return true;
    }
    return false;
  }

  Map<String, int> getAllHighScores() {
    final scores = <String, int>{};
    final prefs = _prefs;
    if (prefs == null) return scores;
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final modeName = key.substring(_prefix.length);
        scores[modeName] = prefs.getInt(key) ?? 0;
      }
    }
    return scores;
  }
}
