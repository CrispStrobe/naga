import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Breakout/Arkanoid inspired — snake is the paddle, bounce food into blocks.
class FangsMode extends GameMode {
  @override
  String get name => 'Fangs';

  @override
  String get description => 'Breakout with a bite';

  @override
  Color get backgroundColor => const Color(0xFF1A0A2E);

  @override
  Color get snakeColor => const Color(0xFFE040FB); // Purple neon

  @override
  Color get foodColor => const Color(0xFFFFEB3B); // Yellow ball

  @override
  Color get gridColor => const Color(0xFF2A1A3E);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.16;
    const minInterval = 0.06;
    final speedUp = (score ~/ 80) * 0.015;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 5;

  Color get blockColor => const Color(0xFF00BCD4);
  Color get ballColor => const Color(0xFFFFEB3B);
}
