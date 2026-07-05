import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'maze.dart';

enum GhostDirection { up, down, left, right }

/// A ghost enemy that patrols the maze corridors.
class Ghost extends Component {
  final Color normalColor;
  final Color vulnerableColor;
  final Maze maze;
  final Point<int> _startPosition;
  final double Function() getCellSize;
  final Vector2 Function() getBoardOffset;

  Point<int> gridPosition;
  GhostDirection _direction;
  bool isVulnerable = false;
  bool isEaten = false;

  double _respawnTimer = 0;
  static const double _respawnDuration = 3.0;

  final Random _random = Random();
  double _animTimer = 0;

  Ghost({
    required this.normalColor,
    required this.maze,
    required Point<int> startPosition,
    required this.getCellSize,
    required this.getBoardOffset,
  })  : gridPosition = startPosition,
        _startPosition = startPosition,
        vulnerableColor = const Color(0xFF2121DE),
        _direction = GhostDirection.values[Random().nextInt(4)];

  @override
  void update(double dt) {
    super.update(dt);
    _animTimer += dt;

    if (isEaten) {
      _respawnTimer += dt;
      if (_respawnTimer >= _respawnDuration) {
        isEaten = false;
        isVulnerable = false;
        _respawnTimer = 0;
        gridPosition = _startPosition;
      }
    }
  }

  void move() {
    if (isEaten) return;

    final neighbors = maze.getPassableNeighbors(gridPosition);
    if (neighbors.isEmpty) return;

    // Try to continue forward, avoid reversing
    final preferred = _applyDirection(gridPosition, _direction);
    final opposite = _oppositeDir(_direction);

    // Filter out going backwards unless it's the only option
    final forwardOptions = neighbors
        .where((n) => _directionTo(gridPosition, n) != opposite)
        .toList();

    final options = forwardOptions.isNotEmpty ? forwardOptions : neighbors;

    Point<int> chosen;
    if (maze.isPassable(preferred.x, preferred.y) && options.contains(preferred)) {
      // Continue straight if possible
      chosen = preferred;
    } else {
      // Pick random from available
      chosen = options[_random.nextInt(options.length)];
    }

    final newDir = _directionTo(gridPosition, chosen);
    if (newDir != null) _direction = newDir;
    gridPosition = chosen;
  }

  Point<int> _applyDirection(Point<int> pos, GhostDirection dir) {
    switch (dir) {
      case GhostDirection.up:
        return Point(pos.x, pos.y - 1);
      case GhostDirection.down:
        return Point(pos.x, pos.y + 1);
      case GhostDirection.left:
        return Point(pos.x - 1, pos.y);
      case GhostDirection.right:
        return Point(pos.x + 1, pos.y);
    }
  }

  GhostDirection _oppositeDir(GhostDirection dir) {
    switch (dir) {
      case GhostDirection.up:
        return GhostDirection.down;
      case GhostDirection.down:
        return GhostDirection.up;
      case GhostDirection.left:
        return GhostDirection.right;
      case GhostDirection.right:
        return GhostDirection.left;
    }
  }

  GhostDirection? _directionTo(Point<int> from, Point<int> to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    if (dx > 0) return GhostDirection.right;
    if (dx < 0) return GhostDirection.left;
    if (dy > 0) return GhostDirection.down;
    if (dy < 0) return GhostDirection.up;
    return null;
  }

  void setVulnerable(bool vulnerable) {
    isVulnerable = vulnerable;
  }

  void eat() {
    isEaten = true;
    _respawnTimer = 0;
  }

  @override
  void render(Canvas canvas) {
    if (isEaten) return;

    final cs = getCellSize();
    final offset = getBoardOffset();
    final sx = offset.x + gridPosition.x * cs;
    final sy = offset.y + gridPosition.y * cs;

    final color = isVulnerable
        ? ((_animTimer * 4).floor() % 2 == 0
            ? vulnerableColor
            : Colors.white)
        : normalColor;

    final paint = Paint()..color = color;

    final cx = sx + cs / 2;
    final cy = sy + cs / 2;
    final bodyWidth = cs * 0.8;
    final bodyHeight = cs * 0.8;

    // Main body with rounded top
    final bodyRect = Rect.fromLTWH(
      cx - bodyWidth / 2,
      cy - bodyHeight / 2,
      bodyWidth,
      bodyHeight,
    );

    final topPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        bodyRect,
        topLeft: Radius.circular(bodyWidth / 2),
        topRight: Radius.circular(bodyWidth / 2),
      ));
    canvas.drawPath(topPath, paint);

    // Wavy bottom
    final bumpWidth = bodyWidth / 3;
    final bottomY = cy + bodyHeight / 2;
    final leftX = cx - bodyWidth / 2;
    final wavePath = Path()..moveTo(leftX, bottomY - cs * 0.1);
    for (int i = 0; i < 3; i++) {
      final bx = leftX + i * bumpWidth;
      wavePath.quadraticBezierTo(
        bx + bumpWidth / 2,
        bottomY + cs * 0.1,
        bx + bumpWidth,
        bottomY - cs * 0.1,
      );
    }
    wavePath.lineTo(leftX + bodyWidth, cy);
    wavePath.lineTo(leftX, cy);
    wavePath.close();
    canvas.drawPath(wavePath, paint);

    // Eyes
    if (!isVulnerable) {
      final eyePaint = Paint()..color = Colors.white;
      final pupilPaint = Paint()..color = const Color(0xFF0000AA);
      final eyeR = cs * 0.1;
      final pupilR = cs * 0.05;

      canvas.drawCircle(
          Offset(cx - cs * 0.13, cy - cs * 0.08), eyeR, eyePaint);
      canvas.drawCircle(
          Offset(cx + cs * 0.13, cy - cs * 0.08), eyeR, eyePaint);
      canvas.drawCircle(
          Offset(cx - cs * 0.13, cy - cs * 0.06), pupilR, pupilPaint);
      canvas.drawCircle(
          Offset(cx + cs * 0.13, cy - cs * 0.06), pupilR, pupilPaint);
    } else {
      // Scared face
      final eyePaint = Paint()..color = Colors.white;
      final eyeR = cs * 0.06;
      canvas.drawCircle(
          Offset(cx - cs * 0.1, cy - cs * 0.08), eyeR, eyePaint);
      canvas.drawCircle(
          Offset(cx + cs * 0.1, cy - cs * 0.08), eyeR, eyePaint);

      final mouthPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final mouthPath = Path()
        ..moveTo(cx - cs * 0.15, cy + cs * 0.1);
      for (int i = 0; i < 3; i++) {
        final mx = cx - cs * 0.15 + i * cs * 0.1;
        mouthPath.quadraticBezierTo(
          mx + cs * 0.05,
          cy + cs * (i % 2 == 0 ? 0.05 : 0.15),
          mx + cs * 0.1,
          cy + cs * 0.1,
        );
      }
      canvas.drawPath(mouthPath, mouthPaint);
    }
  }
}
