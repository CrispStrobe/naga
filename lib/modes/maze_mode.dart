import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Pac-Man inspired mode — navigate a maze, eat dots, avoid ghosts.
class MazeMode extends GameMode {
  @override
  String get name => 'Maze Hunter';

  @override
  String get description => 'Pac-Man meets Snake';

  @override
  Color get backgroundColor => NagaPalette.lagoonTeal; // sunlit lagoon floor

  @override
  Color get snakeColor => const Color(0xFFFFFF00); // Pac-Man yellow

  @override
  Color get foodColor => const Color(0xFFFFFFFF); // White dots

  @override
  Color get gridColor => NagaPalette.deepLagoon;

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.18;
    const minInterval = 0.07;
    final speedUp = (score ~/ 100) * 0.02;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;

  // Maze wall color for rendering — dense jungle hedge walls
  Color get wallColor => NagaPalette.canopyGreen;

  // Ghost colors
  static const List<Color> ghostColors = [
    Color(0xFFFF0000), // Blinky (red)
    Color(0xFFFFB8FF), // Pinky (pink)
    Color(0xFF00FFFF), // Inky (cyan)
    Color(0xFFFFB852), // Clyde (orange)
  ];

  // Power pellet color
  Color get powerPelletColor => const Color(0xFFFFB8FF);
}
