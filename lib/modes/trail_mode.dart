import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Tron-inspired mode — light trails, AI opponents, shrinking arena.
class TrailMode extends GameMode {
  @override
  String get name => 'Trail';

  @override
  String get description => 'Tron light cycles';

  @override
  Color get backgroundColor => const Color(0xFF00695C);

  @override
  Color get snakeColor => const Color(0xFF00E5FF); // Cyan neon

  @override
  Color get foodColor => const Color(0xFFFF6D00); // Orange energy

  @override
  Color get gridColor => const Color(0xFF003333);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  double tickInterval(int score) {
    // Fast and gets faster
    const baseInterval = 0.12;
    const minInterval = 0.05;
    final speedUp = (score ~/ 40) * 0.01;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 15;

  // AI opponent trail color
  Color get enemyColor => const Color(0xFFFF1744);

  // Arena border glow
  Color get borderGlowColor => const Color(0xFF00E5FF);
}
