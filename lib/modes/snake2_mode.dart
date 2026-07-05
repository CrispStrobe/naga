import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Snake II — maze levels with wrap-around walls, bonus items, multiple food.
class Snake2Mode extends GameMode {
  // Same green LCD palette as Classic
  static const Color _lcdBackground = Color(0xFF9BBC0F);
  static const Color _lcdDark = Color(0xFF0F380F);
  static const Color _lcdLight = Color(0xFF8BAC0F);

  @override
  String get name => 'Snake II';

  @override
  String get description => 'Maze levels & wrap-around';

  @override
  Color get backgroundColor => _lcdBackground;

  @override
  Color get snakeColor => _lcdDark;

  @override
  Color get foodColor => _lcdDark;

  @override
  Color get gridColor => _lcdLight;

  @override
  bool get wallsKill => false; // Wrap-around

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    // Faster base speed than Classic
    const baseInterval = 0.16;
    const minInterval = 0.06;
    final speedUp = (score ~/ 50) * 0.015;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;

  /// Points awarded for collecting a bonus item.
  int get pointsPerBonus => 50;

  /// Number of food items on screen at once.
  int get foodCount => 3;

  /// How long a bonus item stays on screen (seconds).
  double get bonusDuration => 5.0;

  /// Wall color for maze obstacles.
  Color get wallColor => _lcdDark;
}
