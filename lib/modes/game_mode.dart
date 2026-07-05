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

  double tickInterval(int score);
  int pointsPerFood(int score);
}
