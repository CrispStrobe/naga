import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Breakout/Arkanoid inspired — snake is the paddle, bounce food into blocks.
class FangsMode extends GameMode {
  @override
  String get name => 'Fangs';

  @override
  String get description => 'Breakout with a bite';

  @override
  Color get backgroundColor => NagaPalette.orchidPurple; // orchid grove

  @override
  Color get snakeColor => NagaPalette.parrotCyan;

  @override
  Color get foodColor => const Color(0xFFFFD740); // Golden ball

  @override
  Color get gridColor => const Color(0xFF9C27B0);

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
