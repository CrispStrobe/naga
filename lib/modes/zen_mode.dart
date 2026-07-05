import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Zen mode - no death, no walls, slow and peaceful.
class ZenMode extends GameMode {
  @override
  String get name => 'Zen';

  @override
  String get description => 'No death, just vibes';

  @override
  Color get backgroundColor => const Color(0xFF3E1A3A);

  @override
  Color get snakeColor => const Color(0xFFFFD740);

  @override
  Color get foodColor => const Color(0xFFFF80AB);

  @override
  Color get gridColor => const Color(0xFF4E2A4A);

  @override
  bool get wallsKill => false;

  @override
  bool get showGrid => false;

  @override
  bool get showBorder => false;

  @override
  double tickInterval(int score) => 0.25; // Constant slow pace

  @override
  int pointsPerFood(int score) => 5;
}
