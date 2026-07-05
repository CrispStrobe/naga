import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Local 2-player duel mode — two snakes on the same board.
class MultiplayerMode extends GameMode {
  @override
  String get name => 'Duel';

  @override
  String get description => 'Local 2-player';

  @override
  Color get backgroundColor => NagaPalette.lagoonTeal; // twin lagoon

  @override
  Color get snakeColor => NagaPalette.parrotLime; // Player 1 lime

  /// Player 2 snake color — sun gold, high contrast on the teal lagoon.
  Color get player2Color => NagaPalette.sunGold;

  @override
  Color get foodColor => const Color(0xFFFF4444);

  @override
  Color get gridColor => const Color(0xFF26A69A);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.14;
    const minInterval = 0.06;
    final speedUp = (score ~/ 50) * 0.01;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;
}
