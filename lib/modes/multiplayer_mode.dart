import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Local 2-player duel mode — two snakes on the same board.
class MultiplayerMode extends GameMode {
  @override
  String get name => 'Duel';

  @override
  String get description => 'Local 2-player';

  @override
  Color get backgroundColor => const Color(0xFF1A2A1A);

  @override
  Color get snakeColor => const Color(0xFF00E676); // Player 1 emerald

  /// Player 2 snake color — bright cyan.
  Color get player2Color => const Color(0xFF00FFFF);

  @override
  Color get foodColor => const Color(0xFFFF4444);

  @override
  Color get gridColor => const Color(0xFF2A3A2A);

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
