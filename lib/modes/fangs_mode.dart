import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Breakout/Arkanoid inspired — snake is the paddle, bounce food into blocks.
class FangsMode extends GameMode {
  @override
  String get name => 'Fangs';

  @override
  String get description => 'Breakout with a bite';

  @override
  Color get backgroundColor => const Color(0xFF5C1A3A);

  @override
  Color get snakeColor => const Color(0xFFE040FB); // Magenta neon

  @override
  Color get foodColor => const Color(0xFFFFD740); // Golden ball

  @override
  Color get gridColor => const Color(0xFF6A2A4A);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.08;
    const minInterval = 0.03;
    final speedUp = (score ~/ 80) * 0.008;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 5;

  Color get blockColor => const Color(0xFF00BCD4);
  Color get ballColor => const Color(0xFFFFEB3B);
}
