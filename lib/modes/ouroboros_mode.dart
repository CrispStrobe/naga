import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Ouroboros: fireflies can't be eaten, only caught by closing a loop of
/// your own body around them. Catching several in one loop scores more.
class OuroborosMode extends GameMode {
  @override
  String get name => 'Ouroboros';

  @override
  String get description => 'Catch fireflies in a loop';

  @override
  Color get backgroundColor => const Color(0xFF0D2B2A); // deep lagoon night

  @override
  Color get snakeColor => NagaPalette.sunGold;

  @override
  Color get foodColor => NagaPalette.appleRed;

  @override
  Color get gridColor => const Color(0xFF123634);

  Color get moteColor => NagaPalette.parrotCyan;

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  bool get hasPowerUps => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.16;
    const minInterval = 0.08;
    final speedUp = (score ~/ 100) * 0.01;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;
}
