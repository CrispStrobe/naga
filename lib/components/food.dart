import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';

class Food extends Component with HasGameReference<SnakeGame> {
  Point<int> gridPosition;
  final SnakeGame _game;
  double _pulseTimer = 0;
  double _hopTimer = 0;
  double _hopOffsetX = 0;
  double _hopOffsetY = 0;
  final Random _random = Random();

  Food({required this.gridPosition, required SnakeGame game}) : _game = game;

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;

    if (_game.mode.name == 'Classic') return;

    // Hop away every ~3 seconds in non-classic modes
    _hopTimer += dt;
    if (_hopTimer >= 3.0) {
      _hopTimer = 0;
      _tryHop();
    }

    // Smooth hop animation decay
    _hopOffsetX *= 0.9;
    _hopOffsetY *= 0.9;
  }

  void _tryHop() {
    // Only hop if snake is within 5 cells
    if (_game.snake.segments.isEmpty) return;
    final head = _game.snake.segments.first;
    final dist = (head.x - gridPosition.x).abs() + (head.y - gridPosition.y).abs();
    if (dist > 5) return;

    // Try to hop 1-2 cells away from the snake head
    final dx = gridPosition.x - head.x;
    final dy = gridPosition.y - head.y;

    // Prefer moving away from snake
    final candidates = <Point<int>>[];
    for (int ox = -2; ox <= 2; ox++) {
      for (int oy = -2; oy <= 2; oy++) {
        if (ox == 0 && oy == 0) continue;
        final nx = gridPosition.x + ox;
        final ny = gridPosition.y + oy;
        if (nx < 0 || nx >= _game.gridWidth || ny < 0 || ny >= _game.gridHeight) continue;
        if (_game.snake.occupies(Point(nx, ny))) continue;
        // Prefer directions away from snake
        if (ox * dx >= 0 && oy * dy >= 0) {
          candidates.add(Point(nx, ny));
        }
      }
    }

    if (candidates.isEmpty) return;

    final newPos = candidates[_random.nextInt(candidates.length)];
    final oldPos = gridPosition;
    gridPosition = newPos;

    // Set hop animation offset (visual bounce)
    final cs = _game.cellSize;
    _hopOffsetX = (oldPos.x - newPos.x) * cs * 0.5;
    _hopOffsetY = (oldPos.y - newPos.y) * cs * 0.5;
  }

  @override
  void render(Canvas canvas) {
    final cs = _game.cellSize;
    final screenPos = _game.gridToScreen(gridPosition);
    final x = screenPos.x + _hopOffsetX;
    final y = screenPos.y + _hopOffsetY;

    if (_game.mode.name == 'Classic') {
      // Retro style: simple filled square
      final paint = Paint()..color = _game.mode.foodColor;
      final inset = cs * 0.15;
      canvas.drawRect(
        Rect.fromLTWH(x + inset, y + inset, cs - inset * 2, cs - inset * 2),
        paint,
      );
    } else {
      // Modern: pulsing apple/fruit with glow
      final pulse = 0.85 + 0.15 * sin(_pulseTimer * 3);
      final radius = (cs / 2) * 0.55 * pulse;
      final cx = x + cs / 2;
      final cy = y + cs / 2;

      // Glow
      final glowPaint = Paint()
        ..color = _game.mode.foodColor.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(cx, cy), radius * 1.8, glowPaint);

      // Main body
      final paint = Paint()..color = _game.mode.foodColor;
      canvas.drawCircle(Offset(cx, cy), radius, paint);

      // Highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.4);
      canvas.drawCircle(
        Offset(cx - radius * 0.25, cy - radius * 0.25),
        radius * 0.3,
        highlightPaint,
      );

      // Small stem
      final stemPaint = Paint()
        ..color = Colors.green.shade700
        ..strokeWidth = cs * 0.04
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx, cy - radius),
        Offset(cx + cs * 0.06, cy - radius - cs * 0.1),
        stemPaint,
      );
    }
  }
}
