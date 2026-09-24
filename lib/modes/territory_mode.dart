import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Territory: leave your land to draw a trail, come home to claim what it
/// encloses. Cross a rival's trail to cut them down; own half the board to
/// win.
class TerritoryMode extends GameMode {
  @override
  String get name => 'Territory';

  @override
  String get description => 'Claim the jungle';

  @override
  Color get backgroundColor => const Color(0xFF1E2A1E); // unclaimed jungle

  @override
  Color get snakeColor => NagaPalette.nagaGreen;

  @override
  Color get foodColor => NagaPalette.sunGold;

  @override
  Color get gridColor => const Color(0xFF243324);

  /// AI rivals, in spawn order.
  List<Color> get rivalColors => const [
    NagaPalette.emberOrange,
    NagaPalette.berryMagenta,
    NagaPalette.parrotCyan,
  ];

  /// Share of the board the player must own to win.
  double get winShare => 0.5;

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  bool get hasPowerUps => false;

  @override
  double tickInterval(int score) => 0.14;

  @override
  int pointsPerFood(int score) => 0;
}
