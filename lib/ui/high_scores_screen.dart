import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import '../services/high_score_service.dart';

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
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: Text(s.highScores),
        backgroundColor: const Color(0xFF0A0A1A),
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
                    border: Border.all(
                      color: isTop
                          ? Colors.amber.withOpacity(0.5)
                          : Colors.green.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${index + 1}',
                        style: TextStyle(
                          color: isTop
                              ? Colors.amber
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
                            color: Colors.green.shade300,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: isTop
                              ? Colors.amber
                              : Colors.green.shade400,
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
