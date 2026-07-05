import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Bomberman inspired — drop venom bombs, chain explosions, clear obstacles.
class VenomMode extends GameMode {
  @override
  String get name => 'Venom';

  @override
  String get description => 'Bomb and blast';

  @override
  Color get backgroundColor => const Color(0xFF1A2A0A);

  @override
  Color get snakeColor => const Color(0xFF76FF03); // Toxic green

  @override
  Color get foodColor => const Color(0xFFFF9100); // Orange pickup

  @override
  Color get gridColor => const Color(0xFF2A3A1A);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.18;
    const minInterval = 0.08;
    final speedUp = (score ~/ 60) * 0.015;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;

  Color get bombColor => const Color(0xFFFF1744);
  Color get explosionColor => const Color(0xFFFFAB00);
  Color get destructibleWallColor => const Color(0xFF795548);
}
