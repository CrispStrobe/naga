import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Centipede inspired — enemies march down in formation, eat them before they reach you.
class SwarmMode extends GameMode {
  @override
  String get name => 'Swarm';

  @override
  String get description => 'Eat the invaders';

  @override
  Color get backgroundColor => const Color(0xFF000A14);

  @override
  Color get snakeColor => const Color(0xFF00FF41); // Terminal green

  @override
  Color get foodColor => const Color(0xFFFF6D00); // Orange power-up

  @override
  Color get gridColor => const Color(0xFF001428);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.14;
    const minInterval = 0.05;
    final speedUp = (score ~/ 70) * 0.012;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) {
    // Higher rows = more points (like Space Invaders)
    if (score > 300) return 40;
    if (score > 150) return 25;
    return 10;
  }

  Color get enemyColor => const Color(0xFFFF1744);
  Color get enemyBulletColor => const Color(0xFFFFFF00);
}
