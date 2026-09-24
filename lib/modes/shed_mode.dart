import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Tetris meets Snake: every 4th meal the snake sheds its skin, which stays
/// on the board as solid wall. Fill a row with shed skin to clear it.
class ShedMode extends GameMode {
  @override
  String get name => 'Shed';

  @override
  String get description => 'Tetris meets Snake';

  @override
  Color get backgroundColor => const Color(0xFF263238); // slate den

  @override
  Color get snakeColor => NagaPalette.nagaGreen;

  @override
  Color get foodColor => NagaPalette.flowerPink;

  @override
  Color get gridColor => const Color(0xFF2E3B42);

  /// Shed skin: pale, papery and clearly not alive.
  Color get skinColor => const Color(0xFFE8DCC0);

  /// Highlights a row that is close to clearing.
  Color get nearRowColor => NagaPalette.sunGold;

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.17;
    const minInterval = 0.08;
    final speedUp = (score ~/ 150) * 0.01;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;
}
