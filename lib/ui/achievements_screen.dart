import 'package:flutter/material.dart';
import '../services/achievements_service.dart';

class AchievementsScreen extends StatelessWidget {
  final AchievementsService achievementsService;

  const AchievementsScreen({super.key, required this.achievementsService});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievementsService.unlockedAchievements;
    final locked = achievementsService.lockedAchievements;
    final total = AchievementsService.allAchievements.length;
    final count = achievementsService.unlockedCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: Text('Achievements ($count/$total)'),
        backgroundColor: const Color(0xFF0A0A1A),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? count / total : 0,
              backgroundColor: Colors.green.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(Colors.green.shade400),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          // Unlocked
          if (unlocked.isNotEmpty) ...[
            _SectionLabel(label: 'UNLOCKED', color: Colors.green.shade400),
            ...unlocked.map((a) => _AchievementTile(
                  achievement: a,
                  unlocked: true,
                )),
            const SizedBox(height: 16),
          ],
          // Locked
          if (locked.isNotEmpty) ...[
            _SectionLabel(label: 'LOCKED', color: Colors.green.shade900),
            ...locked.map((a) => _AchievementTile(
                  achievement: a,
                  unlocked: false,
                )),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
          color: color,
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;

  const _AchievementTile({required this.achievement, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: unlocked
              ? Colors.amber.withOpacity(0.4)
              : Colors.green.withOpacity(0.1),
        ),
        borderRadius: BorderRadius.circular(10),
        color: unlocked ? Colors.amber.withOpacity(0.05) : null,
      ),
      child: Row(
        children: [
          Text(
            unlocked ? achievement.icon : '🔒',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? achievement.titleEn : achievement.titleDe,
                  style: TextStyle(
                    color: unlocked
                        ? Colors.amber.shade300
                        : Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  isEn ? achievement.descEn : achievement.descDe,
                  style: TextStyle(
                    color: unlocked
                        ? Colors.amber.withOpacity(0.5)
                        : Colors.green.withOpacity(0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            Icon(Icons.check_circle, color: Colors.amber.shade400, size: 20),
        ],
      ),
    );
  }
}
