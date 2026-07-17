import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Roguelike dungeon crawler — explore rooms, fight monsters, collect loot.
class DungeonMode extends GameMode {
  @override
  String get name => 'Dungeon';

  @override
  String get description => 'Roguelike crawler';

  @override
  Color get backgroundColor => NagaPalette.templeBrown; // sunlit temple stone

  @override
  Color get snakeColor => const Color(0xFF00E676);

  @override
  Color get foodColor => const Color(0xFFFFD700);

  @override
  Color get gridColor => const Color(0xFFA1887F);

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
  Color get wallColor => const Color(0xFF4E342E); // Dark stone walls, pop on light ruin floor
  Color get floorColor => const Color(0xFFA1887F); // Sunlit corridor
  Color get coinColor => const Color(0xFFFFD700); // Gold
  Color get potionColor => const Color(0xFFFF4444); // Red health potion
  Color get weaponColor => const Color(0xFF00BFFF); // Blue sword pickup
  Color get bowColor => const Color(0xFFB388FF); // Purple bow / arrows
  Color get hammerColor => const Color(0xFFB0BEC5); // Steel grey hammer
  Color get shieldColor => const Color(0xFFE0E0E0); // Silver shield
  Color get trapColor => const Color(0xFFFF6600); // Orange spike trap
  Color get exitColor => const Color(0xFF00FF66); // Green exit door
  Color get monsterColor => const Color(0xFFCC0000); // Dark red grunts
  Color get runnerColor => const Color(0xFFFF9100); // Orange runners (fast)
  Color get bruteColor => const Color(0xFF9C27B0); // Purple brutes (2 HP)
  Color get monsterEyeColor => const Color(0xFFFF0000); // Glowing red eyes
}
