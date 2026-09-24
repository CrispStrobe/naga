import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Daily Serpent: one seeded board per calendar day, the same for everyone.
///
/// Fixed rules and no power-ups keep runs comparable; the seed decides the
/// rock layout and the order food appears in.
class DailyMode extends GameMode {
  /// The local calendar day this board belongs to (time of day dropped).
  final DateTime day;

  DailyMode(DateTime date) : day = DateTime(date.year, date.month, date.day);

  /// yyyymmdd, e.g. 20260924.
  int get seed => day.year * 10000 + day.month * 100 + day.day;

  @override
  String get name => 'Daily';

  @override
  String get description => 'Same board for everyone today';

  @override
  Color get backgroundColor => const Color(0xFF3E2723); // temple dusk

  @override
  Color get snakeColor => NagaPalette.sunGold;

  @override
  Color get foodColor => NagaPalette.flowerPink;

  @override
  Color get gridColor => const Color(0xFF4E342E);

  /// Rock obstacles placed by the daily seed.
  Color get rockColor => NagaPalette.templeBrown;

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  bool get fixedRules => true;

  @override
  bool get hasPowerUps => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.18;
    const minInterval = 0.08;
    final speedUp = (score ~/ 50) * 0.015;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;
}
