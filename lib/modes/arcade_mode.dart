import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Modern arcade mode - neon colors, wrap-around walls, faster pace.
class ArcadeMode extends GameMode {
  @override
  String get name => 'Arcade';

  @override
  String get description => 'Neon speed run';

  @override
  Color get backgroundColor => const Color(0xFF0A0A2E);

  @override
  Color get snakeColor => const Color(0xFF00FF88);

  @override
  Color get foodColor => const Color(0xFFFF0066);

  @override
  Color get gridColor => const Color(0xFF1A1A4E);

  @override
  bool get wallsKill => false;

  @override
  bool get showGrid => true;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.15;
    const minInterval = 0.05;
    final speedUp = (score ~/ 30) * 0.015;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) {
    // Combo scoring: faster = more points
    if (score > 200) return 30;
    if (score > 100) return 20;
    return 10;
  }
}
