import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Nightfall: Classic snake in the dark. Only a lantern around the head
/// lights the board, food glimmers faintly, and the lantern slowly dims.
class NightfallMode extends GameMode {
  @override
  String get name => 'Nightfall';

  @override
  String get description => 'Snake by lantern light';

  @override
  Color get backgroundColor => const Color(0xFF1B2A1F); // moonlit jungle floor

  @override
  Color get snakeColor => NagaPalette.leafGreen;

  @override
  Color get foodColor => NagaPalette.sunGold; // a firefly

  @override
  Color get gridColor => const Color(0xFF223326);

  /// The dark itself; nearly opaque so the lantern matters.
  Color get nightColor => const Color(0xF2060A08);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  bool get hasPowerUps => false;

  /// Lantern radius in cells: starts wide and shrinks as the score climbs.
  double lanternCells(int score) => (4.5 - (score ~/ 50) * 0.25).clamp(2.5, 4.5);

  @override
  double tickInterval(int score) {
    const baseInterval = 0.2;
    const minInterval = 0.1;
    final speedUp = (score ~/ 60) * 0.01;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;
}
