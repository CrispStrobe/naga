import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Endless runner style — auto-scrolling level, dodge obstacles, eat food.
class RushMode extends GameMode {
  @override
  String get name => 'Rush';

  @override
  String get description => 'Endless auto-scroll';

  @override
  Color get backgroundColor => const Color(0xFF1A1208);

  @override
  Color get snakeColor => const Color(0xFFFF6F00); // Orange fire

  @override
  Color get foodColor => const Color(0xFF00E5FF); // Cyan pickup

  @override
  Color get gridColor => const Color(0xFF2A2218);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    // Starts fast, gets relentless
    const baseInterval = 0.12;
    const minInterval = 0.04;
    final speedUp = (score ~/ 25) * 0.01;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 5; // Frequent small rewards

  Color get obstacleColor => const Color(0xFFB71C1C);
  Color get warningColor => const Color(0xFFFFAB00);
}
