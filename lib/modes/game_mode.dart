import 'package:flutter/material.dart';

abstract class GameMode {
  String get name;
  String get description;
  Color get backgroundColor;
  Color get snakeColor;
  Color get foodColor;
  Color get gridColor;
  bool get wallsKill;
  bool get showGrid;
  bool get showBorder => true;

  /// Ignores the player's grid, speed, wall and lives settings, so every run
  /// of this mode is played under the same rules and scores compare fairly.
  bool get fixedRules => false;

  /// Whether timed power-ups spawn during play.
  bool get hasPowerUps => true;

  double tickInterval(int score);
  int pointsPerFood(int score);
}
