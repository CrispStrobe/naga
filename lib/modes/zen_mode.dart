import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Zen mode - no death, no walls, slow and peaceful.
class ZenMode extends GameMode {
  @override
  String get name => 'Zen';

  @override
  String get description => 'No death, just vibes';

  @override
  Color get backgroundColor => const Color(0xFF1A1A2E);

  @override
  Color get snakeColor => const Color(0xFF7B68EE);

  @override
  Color get foodColor => const Color(0xFFFFD700);

  @override
  Color get gridColor => const Color(0xFF16213E);

  @override
  bool get wallsKill => false;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) => 0.25; // Constant slow pace

  @override
  int pointsPerFood(int score) => 5;
}
