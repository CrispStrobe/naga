import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';

class Food extends Component with HasGameReference<SnakeGame> {
  final Point<int> gridPosition;
  final SnakeGame _game;
  double _pulseTimer = 0;

  Food({required this.gridPosition, required SnakeGame game}) : _game = game;

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;
  }

  @override
  void render(Canvas canvas) {
    final cs = _game.cellSize;
    final screenPos = _game.gridToScreen(gridPosition);

    if (_game.mode.name == 'Classic') {
      // Nokia style: simple filled square
      final paint = Paint()..color = _game.mode.foodColor;
      final inset = cs * 0.15;
      canvas.drawRect(
        Rect.fromLTWH(
          screenPos.x + inset,
          screenPos.y + inset,
          cs - inset * 2,
          cs - inset * 2,
        ),
        paint,
      );
    } else {
      // Modern: pulsing circle
      final pulse = 0.8 + 0.2 * sin(_pulseTimer * 4);
      final radius = (cs / 2) * 0.6 * pulse;
      final paint = Paint()..color = _game.mode.foodColor;
      canvas.drawCircle(
        Offset(screenPos.x + cs / 2, screenPos.y + cs / 2),
        radius,
        paint,
      );
    }
  }
}
