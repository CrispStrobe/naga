import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Nibbles mode — QBasic NIBBLES.BAS style, bright colors on black.
class NibblesMode extends GameMode {
  static const Color _black = Color(0xFF000000);
  static const Color _brightGreen = Color(0xFF00FF00);
  static const Color _brightYellow = Color(0xFFFFFF00);
  static const Color _brightBlue = Color(0xFF0000FF);

  @override
  String get name => 'Nibbles';

  @override
  String get description => '1991 DOS classic';

  @override
  Color get backgroundColor => _black;

  @override
  Color get snakeColor => _brightGreen;

  @override
  Color get foodColor => _brightYellow;

  @override
  Color get gridColor => _black;

  @override
  bool get wallsKill => false; // Wrap around

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    // Faster than Classic
    const baseInterval = 0.16;
    const minInterval = 0.06;
    final speedUp = (score ~/ 50) * 0.015;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;

  /// Wall/border color.
  Color get borderColor => _brightBlue;

  // The playfield uses DOS dark blue, not the bright menu accent above.
  Color get statusBarColor => const Color(0xFF0000AA);
  Color get playfieldBorderColor => statusBarColor;
  Color get statusTextColor => const Color(0xFFFFFFFF);
}
