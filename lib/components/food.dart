import 'dart:math' show Point, sin;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';

class Food extends Component with HasGameReference<SnakeGame> {
  Point<int> gridPosition;
  final SnakeGame _game;
  double _pulseTimer = 0;

  // Cached paint objects
  late final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  late final Paint _mainPaint = Paint();
  late final Paint _highlightPaint = Paint();
  late final Paint _stemPaint = Paint()
    ..strokeCap = StrokeCap.round;
  late final Paint _classicPaint = Paint();

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
    final x = screenPos.x;
    final y = screenPos.y;

    if (_game.mode.name == 'Classic') {
      _classicPaint.color = _game.mode.foodColor;
      final inset = cs * 0.15;
      canvas.drawRect(
        Rect.fromLTWH(x + inset, y + inset, cs - inset * 2, cs - inset * 2),
        _classicPaint,
      );
    } else {
      final pulse = 0.85 + 0.15 * sin(_pulseTimer * 3);
      final radius = (cs / 2) * 0.55 * pulse;
      final cx = x + cs / 2;
      final cy = y + cs / 2;

      // Glow (cached paint, just update color)
      _glowPaint.color = _game.mode.foodColor.withOpacity(0.15);
      canvas.drawCircle(Offset(cx, cy), radius * 1.8, _glowPaint);

      // Main body
      _mainPaint.color = _game.mode.foodColor;
      canvas.drawCircle(Offset(cx, cy), radius, _mainPaint);

      // Highlight
      _highlightPaint.color = Colors.white.withOpacity(0.4);
      canvas.drawCircle(
        Offset(cx - radius * 0.25, cy - radius * 0.25),
        radius * 0.3,
        _highlightPaint,
      );

      // Small stem
      _stemPaint.color = Colors.green.shade700;
      _stemPaint.strokeWidth = cs * 0.04;
      canvas.drawLine(
        Offset(cx, cy - radius),
        Offset(cx + cs * 0.06, cy - radius - cs * 0.1),
        _stemPaint,
      );
    }
  }
}
