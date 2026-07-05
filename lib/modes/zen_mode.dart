import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Zen mode - no death, no walls, slow and peaceful.
class ZenMode extends GameMode {
  @override
  String get name => 'Zen';

  @override
  String get description => 'No death, just vibes';

  @override
  Color get backgroundColor => NagaPalette.lotusPond; // pale zen water

  @override
  Color get snakeColor => const Color(0xFF00695C); // deep calm teal

  @override
  Color get foodColor => NagaPalette.flowerPink; // lotus blossom

  @override
  Color get gridColor => const Color(0xFFA5D0CC);

  @override
  bool get wallsKill => false;

  @override
  bool get showGrid => false;

  @override
  bool get showBorder => false;

  @override
  double tickInterval(int score) => 0.25; // Constant slow pace

  @override
  int pointsPerFood(int score) => 5;
}
