import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Top-down animal race — dodge obstacles, collect boosts, outrun rivals.
class StampedeMode extends GameMode {
  @override
  String get name => 'Stampede';

  @override
  String get description => 'Animal race';

  @override
  Color get backgroundColor => const Color(0xFF1A3A0A);

  @override
  Color get snakeColor => const Color(0xFF00E676); // Naga green

  @override
  Color get foodColor => const Color(0xFFFFD740); // Gold boost

  @override
  Color get gridColor => const Color(0xFF2A4A1A);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.06;
    const minInterval = 0.03;
    final speedUp = (score ~/ 100) * 0.005;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;

  // Track colors
  Color get trackColor => const Color(0xFF3A3A3A);
  Color get trackLineColor => const Color(0xFFFFFF00);
  Color get grassColor => const Color(0xFF2E7D32);
  Color get rockColor => const Color(0xFF795548);
  Color get logColor => const Color(0xFF5D4037);
}
