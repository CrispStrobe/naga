import 'package:flutter/material.dart';
import 'game_mode.dart';

/// Roguelike dungeon crawler — explore rooms, fight monsters, collect loot.
class DungeonMode extends GameMode {
  @override
  String get name => 'Dungeon';

  @override
  String get description => 'Roguelike crawler';

  @override
  Color get backgroundColor => const Color(0xFF1A1510);

  @override
  Color get snakeColor => const Color(0xFF00FF66);

  @override
  Color get foodColor => const Color(0xFFFFD700);

  @override
  Color get gridColor => const Color(0xFF2A2520);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    // Medium speed, slight acceleration with score
    const baseInterval = 0.16;
    const minInterval = 0.08;
    final speedUp = (score ~/ 200) * 0.01;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;

  // Dungeon-specific colors
  Color get wallColor => const Color(0xFF4A3728); // Brown stone walls
  Color get floorColor => const Color(0xFF2A2A2A); // Dark corridor
  Color get coinColor => const Color(0xFFFFD700); // Gold
  Color get potionColor => const Color(0xFFFF4444); // Red health potion
  Color get weaponColor => const Color(0xFF00BFFF); // Blue weapon pickup
  Color get trapColor => const Color(0xFFFF6600); // Orange spike trap
  Color get exitColor => const Color(0xFF00FF66); // Green exit door
  Color get monsterColor => const Color(0xFFCC0000); // Dark red monsters
  Color get monsterEyeColor => const Color(0xFFFF0000); // Glowing red eyes
}
