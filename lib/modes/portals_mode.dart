import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Portals: one linked pair of portals that jumps to new cells after every
/// meal. Step into one and your head comes out of the other.
class PortalsMode extends GameMode {
  @override
  String get name => 'Portals';

  @override
  String get description => 'Step in here, come out there';

  @override
  Color get backgroundColor => const Color(0xFF1A1733); // twilight violet

  @override
  Color get snakeColor => NagaPalette.parrotLime;

  @override
  Color get foodColor => NagaPalette.flowerPink;

  @override
  Color get gridColor => const Color(0xFF221E40);

  Color get portalA => NagaPalette.parrotCyan;
  Color get portalB => NagaPalette.emberOrange;

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  bool get hasPowerUps => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.17;
    const minInterval = 0.07;
    final speedUp = (score ~/ 50) * 0.012;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;
}
