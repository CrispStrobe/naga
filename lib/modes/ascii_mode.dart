import 'package:flutter/material.dart';
import 'game_mode.dart';

/// ASCII terminal mode — green text on black, DOS/terminal look.
class AsciiMode extends GameMode {
  static const Color _green = Color(0xFF00FF00);
  static const Color _black = Color(0xFF000000);
  static const Color _darkGreen = Color(0xFF003300);

  @override
  String get name => 'ASCII';

  @override
  String get description => 'Terminal text mode';

  @override
  Color get backgroundColor => _black;

  @override
  Color get snakeColor => _green;

  @override
  Color get foodColor => _green;

  @override
  Color get gridColor => _darkGreen;

  @override
  bool get wallsKill => false; // Wrap-around

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.20;
    const minInterval = 0.08;
    final speedUp = (score ~/ 50) * 0.018;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;
}
