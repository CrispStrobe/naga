import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import '../services/high_score_service.dart';
import '../theme/naga_palette.dart';

class HighScoresScreen extends StatelessWidget {
  final HighScoreService highScoreService;

  const HighScoresScreen({super.key, required this.highScoreService});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final scores = highScoreService.getAllHighScores();
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: NagaPalette.menuBackground,
      appBar: AppBar(
        title: Text(s.highScores),
        backgroundColor: NagaPalette.menuBackground,
        foregroundColor: NagaPalette.menuDeepGreen,
        elevation: 0,
      ),
      body: sortedEntries.isEmpty
          ? Center(
              child: Text(
                s.noHighScores,
                style: TextStyle(color: Colors.green.shade700, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedEntries.length,
              itemBuilder: (context, index) {
                final entry = sortedEntries[index];
                final modeName = entry.key.replaceAll('_', ' ');
                final isTop = index == 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isTop ? 0.9 : 0.6),
                    border: Border.all(
                      color: isTop
                          ? const Color(0xFFFFB300)
                          : Colors.green.withOpacity(0.35),
                      width: isTop ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isTop ? '🏆' : '#${index + 1}',
                        style: TextStyle(
                          color: isTop
                              ? const Color(0xFFB26A00)
                              : Colors.green.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          modeName.toUpperCase(),
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: isTop
                              ? const Color(0xFFB26A00)
                              : NagaPalette.menuDeepGreen,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
