import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Modern arcade mode - neon colors, wrap-around walls, faster pace.
class ArcadeMode extends GameMode {
  @override
  String get name => 'Arcade';

  @override
  String get description => 'Neon speed run';

  @override
  Color get backgroundColor => NagaPalette.cyanReef; // bright reef teal

  @override
  Color get snakeColor => NagaPalette.parrotLime;

  @override
  Color get foodColor => NagaPalette.dangerRed;

  @override
  Color get gridColor => const Color(0xFF00ACC1);

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
