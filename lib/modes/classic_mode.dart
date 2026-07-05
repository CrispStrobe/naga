import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Nokia 3310 style snake - monochrome green, grid movement, walls kill.
class ClassicMode extends GameMode {
  // Nokia 3310 LCD green palette
  static const Color _lcdBackground = Color(0xFF9BBC0F);
  static const Color _lcdDark = Color(0xFF0F380F);
  static const Color _lcdLight = Color(0xFF8BAC0F);

  @override
  String get name => 'Classic';

  @override
  String get description => 'Nokia legacy mode';

  @override
  Color get backgroundColor => _lcdBackground;

  @override
  Color get snakeColor => _lcdDark;

  @override
  Color get foodColor => _lcdDark;

  @override
  Color get gridColor => _lcdLight;

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  double tickInterval(int score) {
    // Start slow, speed up as score increases — just like Nokia
    const baseInterval = 0.22;
    const minInterval = 0.08;
    final speedUp = (score ~/ 50) * 0.02;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;
}
