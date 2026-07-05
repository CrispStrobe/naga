import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Flappy Bird-style underwater swim — tap to rise, dodge coral columns.
class NagaDiveMode extends GameMode {
  @override
  String get name => 'Naga Dive';

  @override
  String get description => 'Underwater swim';

  @override
  Color get backgroundColor => const Color(0xFF0A1628);

  @override
  Color get snakeColor => const Color(0xFF00E5FF); // Bioluminescent cyan

  @override
  Color get foodColor => const Color(0xFFFFAB40); // Fish orange

  @override
  Color get gridColor => const Color(0xFF0D1F3C);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    // Not used — NagaDive uses its own frame-based update
    return 0.016;
  }

  @override
  int pointsPerFood(int score) => 1;

  // Water theme colors
  Color get coralColor => const Color(0xFFFF6D00);
  Color get seaweedColor => const Color(0xFF00C853);
  Color get bubbleColor => const Color(0xFF80D8FF);
  Color get deepWaterColor => const Color(0xFF0D47A1);
  Color get fishColor => const Color(0xFFFFD740);
}
