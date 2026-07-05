import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';

class Snake extends Component with HasGameReference<SnakeGame> {
  List<Point<int>> segments;
  final SnakeGame _game;

  Snake({required List<Point<int>> initialSegments, required SnakeGame game})
      : segments = List.from(initialSegments),
        _game = game;

  bool occupies(Point<int> pos) {
    return segments.any((s) => s.x == pos.x && s.y == pos.y);
  }

  void move(Point<int> newHead, {bool grow = false}) {
    segments.insert(0, newHead);
    if (!grow) {
      segments.removeLast();
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = _game.mode.snakeColor;
    final cs = _game.cellSize;
    final inset = cs * 0.05; // Tiny gap between segments for that pixel look

    for (int i = 0; i < segments.length; i++) {
      final screenPos = _game.gridToScreen(segments[i]);
      final rect = Rect.fromLTWH(
        screenPos.x + inset,
        screenPos.y + inset,
        cs - inset * 2,
        cs - inset * 2,
      );
      canvas.drawRect(rect, paint);
    }

    // Draw eyes on the head in non-classic modes
    if (_game.mode.name != 'Classic' && segments.isNotEmpty) {
      _drawEyes(canvas);
    }
  }

  void _drawEyes(Canvas canvas) {
    final head = segments.first;
    final screenPos = _game.gridToScreen(head);
    final cs = _game.cellSize;
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;
    final eyeRadius = cs * 0.12;
    final pupilRadius = cs * 0.06;

    final cx = screenPos.x + cs / 2;
    final cy = screenPos.y + cs / 2;

    // Position eyes based on direction
    double e1x, e1y, e2x, e2y;
    switch (_game.currentDirection) {
      case Direction.right:
        e1x = cx + cs * 0.15;
        e1y = cy - cs * 0.15;
        e2x = cx + cs * 0.15;
        e2y = cy + cs * 0.15;
      case Direction.left:
        e1x = cx - cs * 0.15;
        e1y = cy - cs * 0.15;
        e2x = cx - cs * 0.15;
        e2y = cy + cs * 0.15;
      case Direction.up:
        e1x = cx - cs * 0.15;
        e1y = cy - cs * 0.15;
        e2x = cx + cs * 0.15;
        e2y = cy - cs * 0.15;
      case Direction.down:
        e1x = cx - cs * 0.15;
        e1y = cy + cs * 0.15;
        e2x = cx + cs * 0.15;
        e2y = cy + cs * 0.15;
    }

    canvas.drawCircle(Offset(e1x, e1y), eyeRadius, eyePaint);
    canvas.drawCircle(Offset(e2x, e2y), eyeRadius, eyePaint);
    canvas.drawCircle(Offset(e1x, e1y), pupilRadius, pupilPaint);
    canvas.drawCircle(Offset(e2x, e2y), pupilRadius, pupilPaint);
  }
}
