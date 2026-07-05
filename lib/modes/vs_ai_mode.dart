import 'package:flutter/material.dart';
import 'game_mode.dart';

/// VS AI mode — player versus 1-3 computer-controlled snakes.
class VsAiMode extends GameMode {
  @override
  String get name => 'VS AI';

  @override
  String get description => 'Challenge the bots';

  @override
  Color get backgroundColor => const Color(0xFF201018);

  @override
  Color get snakeColor => const Color(0xFF00FF66); // Player green

  @override
  Color get foodColor => const Color(0xFFFF4444);

  @override
  Color get gridColor => const Color(0xFF302028);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.14;
    const minInterval = 0.06;
    final speedUp = (score ~/ 50) * 0.01;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;

  /// Colors for AI opponent snakes (1-3).
  static const List<Color> aiColors = [
    Color(0xFFFF5252), // red
    Color(0xFF448AFF), // blue
    Color(0xFFFF9100), // orange
  ];
}
