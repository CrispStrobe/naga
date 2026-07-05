import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Centipede inspired — enemies march down in formation, eat them before they reach you.
class SwarmMode extends GameMode {
  @override
  String get name => 'Swarm';

  @override
  String get description => 'Eat the invaders';

  @override
  Color get backgroundColor => NagaPalette.leafGreen; // sunlit canopy

  @override
  Color get snakeColor => NagaPalette.sunGold; // gold pops on green

  @override
  Color get foodColor => NagaPalette.emberOrange; // Orange power-up

  @override
  Color get gridColor => const Color(0xFF4CAF50);

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

  Color get enemyColor => const Color(0xFFD50000); // beetles, deep red on green
  Color get enemyBulletColor => const Color(0xFFFFFFFF); // white so they never blend with the gold snake
}
