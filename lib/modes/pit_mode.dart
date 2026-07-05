import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Battle Royale — shrinking arena, multiple AI snakes, last one alive wins.
class PitMode extends GameMode {
  @override
  String get name => 'Pit';

  @override
  String get description => 'Last snake standing';

  @override
  Color get backgroundColor => const Color(0xFF0D0D0D);

  @override
  Color get snakeColor => const Color(0xFF00E676); // Player green

  @override
  Color get foodColor => const Color(0xFFFFD740); // Gold food

  @override
  Color get gridColor => const Color(0xFF1A1A1A);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.15;
    const minInterval = 0.06;
    final speedUp = (score ~/ 50) * 0.012;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;

  Color get dangerZoneColor => const Color(0x44FF1744);
  Color get enemySnakeColor => const Color(0xFFFF5252);

  static const List<Color> enemyColors = [
    Color(0xFFFF5252),
    Color(0xFFFF4081),
    Color(0xFFE040FB),
    Color(0xFF7C4DFF),
    Color(0xFF448AFF),
  ];
}
