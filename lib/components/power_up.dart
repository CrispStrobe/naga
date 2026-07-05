import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';

enum PowerUpType {
  speed,
  shield,
  magnet,
  slow,
  shrink,
}

class PowerUp extends Component with HasGameReference<SnakeGame> {
  Point<int> gridPosition;
  final SnakeGame _game;
  final PowerUpType type;
  double _lifetime = 0;
  double _pulseTimer = 0;
  static const double despawnTime = 8.0;

  // Cached paint objects
  final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  final Paint _fillPaint = Paint();
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke;
  final Paint _highlightPaint = Paint();

  PowerUp({
    required this.gridPosition,
    required this.type,
    required SnakeGame game,
  }) : _game = game;

  Color get color {
    switch (type) {
      case PowerUpType.speed:
        return Colors.yellow;
      case PowerUpType.shield:
        return Colors.blue;
      case PowerUpType.magnet:
        return Colors.purple;
      case PowerUpType.slow:
        return Colors.orange;
      case PowerUpType.shrink:
        return Colors.red;
    }
  }

  String get label {
    switch (type) {
      case PowerUpType.speed:
        return 'S';
      case PowerUpType.shield:
        return '⛨';
      case PowerUpType.magnet:
        return 'M';
      case PowerUpType.slow:
        return '▼';
      case PowerUpType.shrink:
        return '✂';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    _pulseTimer += dt;

    if (_lifetime >= despawnTime) {
      _game.removePowerUp(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final cs = _game.cellSize;
    final screenPos = _game.gridToScreen(gridPosition);
    final cx = screenPos.x + cs / 2;
    final cy = screenPos.y + cs / 2;

    final pulse = 0.8 + 0.2 * sin(_pulseTimer * 4);
    final fadeOut = _lifetime > despawnTime - 2.0
        ? ((despawnTime - _lifetime) / 2.0).clamp(0.0, 1.0)
        : 1.0;

    // Glow (reuse cached paint)
    _glowPaint.color = color.withOpacity(0.25 * fadeOut);
    canvas.drawCircle(Offset(cx, cy), cs * 0.6 * pulse, _glowPaint);

    // Diamond shape
    final size = cs * 0.38 * pulse;
    final path = Path()
      ..moveTo(cx, cy - size)
      ..lineTo(cx + size, cy)
      ..lineTo(cx, cy + size)
      ..lineTo(cx - size, cy)
      ..close();

    _fillPaint.color = color.withOpacity(0.9 * fadeOut);
    canvas.drawPath(path, _fillPaint);

    // Border
    _borderPaint.color = Colors.white.withOpacity(0.6 * fadeOut);
    _borderPaint.strokeWidth = cs * 0.05;
    canvas.drawPath(path, _borderPaint);

    // Inner highlight
    _highlightPaint.color = Colors.white.withOpacity(0.35 * fadeOut);
    canvas.drawCircle(
      Offset(cx - size * 0.15, cy - size * 0.15),
      size * 0.25,
      _highlightPaint,
    );
  }
}
