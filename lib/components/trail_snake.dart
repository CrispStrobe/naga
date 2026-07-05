import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/trail_game.dart';

/// A snake that leaves a permanent light trail behind it.
/// Used for both the player and AI in Trail mode.
class TrailSnake extends Component {
  final TrailGame game;
  final Color color;
  final Color trailColor;

  List<Point<int>> segments;
  Direction direction;
  Direction _nextDirection;

  /// Every cell this snake has ever occupied (the permanent trail).
  final Set<int> trail = {};

  bool alive = true;

  TrailSnake({
    required this.game,
    required List<Point<int>> initialSegments,
    required this.color,
    Color? trailColor,
    required this.direction,
  })  : segments = List.from(initialSegments),
        _nextDirection = direction,
        trailColor = trailColor ?? color.withAlpha(100) {
    // Mark initial segments as part of the trail
    for (final seg in initialSegments) {
      trail.add(_key(seg));
    }
  }

  static int _key(Point<int> p) => p.y * 10000 + p.x;

  bool occupiesTrail(Point<int> pos) => trail.contains(_key(pos));

  bool occupiesHead(Point<int> pos) =>
      segments.isNotEmpty && segments.first.x == pos.x && segments.first.y == pos.y;

  void changeDirection(Direction dir) {
    // Prevent 180-degree turns
    if (dir == Direction.up && direction == Direction.down) return;
    if (dir == Direction.down && direction == Direction.up) return;
    if (dir == Direction.left && direction == Direction.right) return;
    if (dir == Direction.right && direction == Direction.left) return;
    _nextDirection = dir;
  }

  /// Compute where the head would go next, applying the queued direction.
  /// Call this BEFORE advance() to check collisions.
  Point<int> peekNextHead() {
    final dir = _nextDirection;
    final head = segments.first;
    switch (dir) {
      case Direction.up:
        return Point(head.x, head.y - 1);
      case Direction.down:
        return Point(head.x, head.y + 1);
      case Direction.left:
        return Point(head.x - 1, head.y);
      case Direction.right:
        return Point(head.x + 1, head.y);
    }
  }

  /// Actually move the snake to [newHead]. Call after collision checks pass.
  void advance(Point<int> newHead) {
    direction = _nextDirection;

    // The snake body stays constant length (3).
    segments.insert(0, newHead);
    if (segments.length > 3) {
      segments.removeLast();
    }

    // Mark position in permanent trail
    trail.add(_key(newHead));
  }

  @override
  void render(Canvas canvas) {
    final cs = game.cellSize;
    final inset = cs * 0.05;

    // Draw permanent trail with glow
    final trailPaint = Paint()..color = trailColor;
    final glowPaint = Paint()
      ..color = color.withAlpha(30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);

    for (final key in trail) {
      final x = key % 10000;
      final y = key ~/ 10000;
      final screenPos = game.gridToScreen(Point(x, y));

      // Skip cells that are currently part of the snake body
      // (they'll be drawn brighter below)
      final isBody = segments.any((s) => s.x == x && s.y == y);
      if (isBody) continue;

      final rect = Rect.fromLTWH(
        screenPos.x + inset,
        screenPos.y + inset,
        cs - inset * 2,
        cs - inset * 2,
      );
      canvas.drawRect(rect, trailPaint);
      canvas.drawRect(rect, glowPaint);
    }

    if (!alive) return;

    // Draw snake body (brighter than trail)
    final bodyPaint = Paint()..color = color;
    final bodyGlowPaint = Paint()
      ..color = color.withAlpha(60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);

    for (int i = 0; i < segments.length; i++) {
      final screenPos = game.gridToScreen(segments[i]);
      final rect = Rect.fromLTWH(
        screenPos.x + inset,
        screenPos.y + inset,
        cs - inset * 2,
        cs - inset * 2,
      );
      canvas.drawRect(rect, bodyPaint);
      canvas.drawRect(rect, bodyGlowPaint);
    }

    // Draw a bright head
    if (segments.isNotEmpty) {
      final headPos = game.gridToScreen(segments.first);
      final headRect = Rect.fromLTWH(
        headPos.x,
        headPos.y,
        cs,
        cs,
      );
      final headGlow = Paint()
        ..color = color.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);
      canvas.drawRect(headRect, headGlow);
    }
  }
}
