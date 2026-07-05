import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// VS AI mode — player versus 1-3 computer-controlled snakes on a shared
/// field, competing for the same food.
class VsAiMode extends GameMode {
  @override
  String get name => 'VS AI';

  @override
  String get description => 'Challenge the bots';

  @override
  Color get backgroundColor => NagaPalette.riverBlue;

  @override
  Color get snakeColor => NagaPalette.parrotLime;

  @override
  Color get foodColor => const Color(0xFFFF4444);

  @override
  Color get gridColor => const Color(0xFF29B6F6);

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

  /// Colors for AI opponent snakes (1-3) — picked to pop on the bright
  /// river-blue background.
  static const List<Color> aiColors = [
    Color(0xFFFF5252), // red
    Color(0xFFFFD740), // gold
    Color(0xFF7B1FA2), // deep purple
  ];
}

/// VS AI Split mode — the arena is divided by an impassable vertical wall.
/// The player duels the AI from the left half while the AI snakes race in
/// the right half, each side with its own food. First to die loses.
class VsAiSplitMode extends VsAiMode {
  @override
  String get name => 'VS AI Split';

  @override
  String get description => 'Separate lanes duel';
}
