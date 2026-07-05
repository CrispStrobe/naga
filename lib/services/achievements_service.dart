import 'package:shared_preferences/shared_preferences.dart';

class Achievement {
  final String id;
  final String titleEn;
  final String titleDe;
  final String descEn;
  final String descDe;
  final String icon;
  final int target;

  const Achievement({
    required this.id,
    required this.titleEn,
    required this.titleDe,
    required this.descEn,
    required this.descDe,
    required this.icon,
    required this.target,
  });
}

class AchievementsService {
  static const _prefix = 'achievement_';
  static const _statsPrefix = 'stat_';

  static AchievementsService? _instance;
  static Future<AchievementsService>? _pendingInit;
  SharedPreferences? _prefs;

  static const List<Achievement> allAchievements = [
    Achievement(
      id: 'first_food', titleEn: 'First Bite', titleDe: 'Erster Biss',
      descEn: 'Eat your first food', descDe: 'Iss dein erstes Futter',
      icon: '🍎', target: 1,
    ),
    Achievement(
      id: 'food_50', titleEn: 'Hungry Snake', titleDe: 'Hungrige Schlange',
      descEn: 'Eat 50 food total', descDe: 'Iss 50 Futter insgesamt',
      icon: '🐍', target: 50,
    ),
    Achievement(
      id: 'food_500', titleEn: 'Glutton', titleDe: 'Vielfraß',
      descEn: 'Eat 500 food total', descDe: 'Iss 500 Futter insgesamt',
      icon: '🏆', target: 500,
    ),
    Achievement(
      id: 'score_1000', titleEn: 'High Scorer', titleDe: 'Punktejäger',
      descEn: 'Score 1000 in a single game', descDe: '1000 Punkte in einem Spiel',
      icon: '⭐', target: 1000,
    ),
    Achievement(
      id: 'modes_5', titleEn: 'Explorer', titleDe: 'Entdecker',
      descEn: 'Play 5 different modes', descDe: 'Spiele 5 verschiedene Modi',
      icon: '🗺️', target: 5,
    ),
    Achievement(
      id: 'modes_all', titleEn: 'Completionist', titleDe: 'Komplettist',
      descEn: 'Play every game mode', descDe: 'Spiele jeden Spielmodus',
      icon: '💎', target: 17,
    ),
    Achievement(
      id: 'dungeon_5', titleEn: 'Dungeon Crawler', titleDe: 'Kerkerforscher',
      descEn: 'Clear 5 dungeon rooms', descDe: 'Schaffe 5 Kerkerräume',
      icon: '🏰', target: 5,
    ),
    Achievement(
      id: 'survive_60', titleEn: 'Survivor', titleDe: 'Überlebender',
      descEn: 'Survive 60 seconds in Rush', descDe: '60 Sekunden in Rausch überleben',
      icon: '⏱️', target: 60,
    ),
    Achievement(
      id: 'win_duel', titleEn: 'Champion', titleDe: 'Champion',
      descEn: 'Win a Duel match', descDe: 'Gewinne ein Duell',
      icon: '🥇', target: 1,
    ),
    Achievement(
      id: 'beat_expert', titleEn: 'AI Slayer', titleDe: 'KI-Bezwinger',
      descEn: 'Beat Expert AI in VS AI', descDe: 'Besiege Experten-KI im KI-Modus',
      icon: '🤖', target: 1,
    ),
  ];

  AchievementsService._();

  static Future<AchievementsService> instance() {
    _pendingInit ??= _createInstance();
    return _pendingInit!;
  }

  static Future<AchievementsService> _createInstance() async {
    final service = AchievementsService._();
    service._prefs = await SharedPreferences.getInstance();
    _instance = service;
    return service;
  }

  bool isUnlocked(String achievementId) {
    return _prefs?.getBool('$_prefix$achievementId') ?? false;
  }

  Future<void> unlock(String achievementId) async {
    await _prefs?.setBool('$_prefix$achievementId', true);
  }

  int getStat(String statId) {
    return _prefs?.getInt('$_statsPrefix$statId') ?? 0;
  }

  Future<void> incrementStat(String statId, [int amount = 1]) async {
    final current = getStat(statId);
    await _prefs?.setInt('$_statsPrefix$statId', current + amount);
  }

  Future<void> setStat(String statId, int value) async {
    await _prefs?.setInt('$_statsPrefix$statId', value);
  }

  /// Check and unlock achievements based on current stats.
  /// Returns list of newly unlocked achievement IDs.
  Future<List<String>> checkAndUnlock() async {
    final newlyUnlocked = <String>[];
    final totalFood = getStat('total_food');
    final modesPlayed = getStat('modes_played');
    final maxScore = getStat('max_single_score');
    final dungeonRooms = getStat('dungeon_rooms');
    final rushSurvival = getStat('rush_survival');
    final duelsWon = getStat('duels_won');
    final expertWins = getStat('expert_ai_wins');

    for (final a in allAchievements) {
      if (isUnlocked(a.id)) continue;
      bool earned = false;
      switch (a.id) {
        case 'first_food':
          earned = totalFood >= 1;
        case 'food_50':
          earned = totalFood >= 50;
        case 'food_500':
          earned = totalFood >= 500;
        case 'score_1000':
          earned = maxScore >= 1000;
        case 'modes_5':
          earned = modesPlayed >= 5;
        case 'modes_all':
          earned = modesPlayed >= 17;
        case 'dungeon_5':
          earned = dungeonRooms >= 5;
        case 'survive_60':
          earned = rushSurvival >= 60;
        case 'win_duel':
          earned = duelsWon >= 1;
        case 'beat_expert':
          earned = expertWins >= 1;
      }
      if (earned) {
        await unlock(a.id);
        newlyUnlocked.add(a.id);
      }
    }
    return newlyUnlocked;
  }

  List<Achievement> get unlockedAchievements =>
      allAchievements.where((a) => isUnlocked(a.id)).toList();

  List<Achievement> get lockedAchievements =>
      allAchievements.where((a) => !isUnlocked(a.id)).toList();

  int get unlockedCount =>
      allAchievements.where((a) => isUnlocked(a.id)).length;
}
