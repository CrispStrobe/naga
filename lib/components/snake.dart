import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';
import 'power_up.dart';

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
    if (segments.isEmpty) return;
    final cs = _game.cellSize;
    final isClassic = _game.mode.name == 'Classic';

    if (isClassic) {
      _renderClassic(canvas, cs);
    } else {
      _renderSmooth(canvas, cs);
    }
  }

  /// Retro-style chain-link rendering (authentic retro phone look)
  void _renderClassic(Canvas canvas, double cs) {
    final color = _game.mode.snakeColor;
    final fillPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cs * 0.12;
    final inset = cs * 0.12;
    final gap = cs * 0.06;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sp = _game.gridToScreen(seg);

      if (i == 0) {
        // Head — solid filled block, slightly larger
        canvas.drawRect(
          Rect.fromLTWH(sp.x + gap, sp.y + gap, cs - gap * 2, cs - gap * 2),
          fillPaint,
        );
      } else {
        // Body/tail — outlined square (chain-link look)
        canvas.drawRect(
          Rect.fromLTWH(sp.x + inset, sp.y + inset, cs - inset * 2, cs - inset * 2),
          borderPaint,
        );
        // Small center dot for chain-link detail
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(sp.x + cs / 2, sp.y + cs / 2),
            width: cs * 0.2,
            height: cs * 0.2,
          ),
          fillPaint,
        );
      }
    }
  }

  /// Smooth modern rendering with rounded body, corners, tapered tail, head with face
  void _renderSmooth(Canvas canvas, double cs) {
    final color = _game.mode.snakeColor;
    final paint = Paint()..color = color;
    final darkerPaint = Paint()..color = Color.lerp(color, Colors.black, 0.2)!;

    // Determine buff glow color
    Color? glowColor;
    if (_game.shieldFlashTimer > 0) {
      // Shield flash: bright white flash
      glowColor = Colors.white;
    } else if (_game.activeBuffs.containsKey(PowerUpType.shield)) {
      glowColor = Colors.blue;
    } else if (_game.activeBuffs.containsKey(PowerUpType.speed)) {
      glowColor = Colors.yellow;
    } else if (_game.activeBuffs.containsKey(PowerUpType.magnet)) {
      glowColor = Colors.purple;
    } else if (_game.activeBuffs.containsKey(PowerUpType.slow)) {
      glowColor = Colors.orange;
    }

    // Draw buff glow behind the snake
    if (glowColor != null) {
      final glowOpacity = _game.shieldFlashTimer > 0
          ? (_game.shieldFlashTimer / 0.5).clamp(0.0, 1.0) * 0.5
          : 0.2;
      final glowPaint = Paint()
        ..color = glowColor.withOpacity(glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      for (final seg in segments) {
        final sp = _game.gridToScreen(seg);
        canvas.drawCircle(
          Offset(sp.x + cs / 2, sp.y + cs / 2),
          cs * 0.55,
          glowPaint,
        );
      }
    }

    for (int i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i];
      final sp = _game.gridToScreen(seg);
      final cx = sp.x + cs / 2;
      final cy = sp.y + cs / 2;

      if (i == 0) {
        // Head — rounded with face
        _drawHead(canvas, cx, cy, cs, paint, darkerPaint);
      } else if (i == segments.length - 1) {
        // Tail — tapered
        _drawTail(canvas, i, cx, cy, cs, paint);
      } else {
        // Body — check if it's a straight or corner piece
        _drawBody(canvas, i, cx, cy, cs, paint, darkerPaint);
      }
    }
  }

  void _drawHead(Canvas canvas, double cx, double cy, double cs, Paint paint, Paint darkerPaint) {
    final radius = cs * 0.45;

    // Head body — circle
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    // Extend body backward to connect with next segment
    if (segments.length > 1) {
      final next = segments[1];
      final head = segments[0];
      final dx = head.x - next.x;
      final dy = head.y - next.y;
      final extendX = cx - dx * cs * 0.3;
      final extendY = cy - dy * cs * 0.3;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset((cx + extendX) / 2, (cy + extendY) / 2),
          width: dx != 0 ? cs * 0.6 : cs * 0.9,
          height: dy != 0 ? cs * 0.6 : cs * 0.9,
        ),
        paint,
      );
    }

    // Eyes
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;
    final eyeR = cs * 0.13;
    final pupilR = cs * 0.07;

    double e1x, e1y, e2x, e2y;
    double px1, py1, px2, py2; // pupil offsets
    switch (_game.currentDirection) {
      case Direction.right:
        e1x = cx + cs * 0.12; e1y = cy - cs * 0.14;
        e2x = cx + cs * 0.12; e2y = cy + cs * 0.14;
        px1 = e1x + cs * 0.04; py1 = e1y;
        px2 = e2x + cs * 0.04; py2 = e2y;
      case Direction.left:
        e1x = cx - cs * 0.12; e1y = cy - cs * 0.14;
        e2x = cx - cs * 0.12; e2y = cy + cs * 0.14;
        px1 = e1x - cs * 0.04; py1 = e1y;
        px2 = e2x - cs * 0.04; py2 = e2y;
      case Direction.up:
        e1x = cx - cs * 0.14; e1y = cy - cs * 0.12;
        e2x = cx + cs * 0.14; e2y = cy - cs * 0.12;
        px1 = e1x; py1 = e1y - cs * 0.04;
        px2 = e2x; py2 = e2y - cs * 0.04;
      case Direction.down:
        e1x = cx - cs * 0.14; e1y = cy + cs * 0.12;
        e2x = cx + cs * 0.14; e2y = cy + cs * 0.12;
        px1 = e1x; py1 = e1y + cs * 0.04;
        px2 = e2x; py2 = e2y + cs * 0.04;
    }

    canvas.drawCircle(Offset(e1x, e1y), eyeR, eyePaint);
    canvas.drawCircle(Offset(e2x, e2y), eyeR, eyePaint);
    canvas.drawCircle(Offset(px1, py1), pupilR, pupilPaint);
    canvas.drawCircle(Offset(px2, py2), pupilR, pupilPaint);

    // Tongue (small red flick in movement direction)
    final tongPaint = Paint()
      ..color = Colors.red.shade400
      ..strokeWidth = cs * 0.04
      ..strokeCap = StrokeCap.round;
    double tx, ty, tx2a, ty2a, tx2b, ty2b;
    switch (_game.currentDirection) {
      case Direction.right:
        tx = cx + cs * 0.45; ty = cy;
        tx2a = tx + cs * 0.12; ty2a = ty - cs * 0.06;
        tx2b = tx + cs * 0.12; ty2b = ty + cs * 0.06;
      case Direction.left:
        tx = cx - cs * 0.45; ty = cy;
        tx2a = tx - cs * 0.12; ty2a = ty - cs * 0.06;
        tx2b = tx - cs * 0.12; ty2b = ty + cs * 0.06;
      case Direction.up:
        tx = cx; ty = cy - cs * 0.45;
        tx2a = tx - cs * 0.06; ty2a = ty - cs * 0.12;
        tx2b = tx + cs * 0.06; ty2b = ty - cs * 0.12;
      case Direction.down:
        tx = cx; ty = cy + cs * 0.45;
        tx2a = tx - cs * 0.06; ty2a = ty + cs * 0.12;
        tx2b = tx + cs * 0.06; ty2b = ty + cs * 0.12;
    }
    canvas.drawLine(Offset(tx, ty), Offset(tx2a, ty2a), tongPaint);
    canvas.drawLine(Offset(tx, ty), Offset(tx2b, ty2b), tongPaint);
  }

  void _drawBody(Canvas canvas, int i, double cx, double cy, double cs, Paint paint, Paint darkerPaint) {
    final prev = segments[i - 1];
    final curr = segments[i];
    final next = segments[i + 1];

    final dxPrev = curr.x - prev.x;
    final dyPrev = curr.y - prev.y;
    final dxNext = next.x - curr.x;
    final dyNext = next.y - curr.y;

    final isStraight = (dxPrev == dxNext && dyPrev == dyNext);
    final bodyWidth = cs * 0.88;

    if (isStraight) {
      // Straight piece
      final isHorizontal = dyPrev == 0;
      if (isHorizontal) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: cs, height: bodyWidth),
            Radius.circular(cs * 0.08),
          ),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: bodyWidth, height: cs),
            Radius.circular(cs * 0.08),
          ),
          paint,
        );
      }
    } else {
      // Corner piece — draw as overlapping rectangles + round the outer corner
      final halfBody = bodyWidth / 2;

      // Two rectangles forming an L-shape
      // Direction from prev to curr
      if (dxPrev != 0) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: cs, height: bodyWidth),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: bodyWidth, height: cs),
          paint,
        );
      }
      if (dxNext != 0) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: cs, height: bodyWidth),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: bodyWidth, height: cs),
          paint,
        );
      }

      // Fill the center with a circle for smooth corner
      canvas.drawCircle(Offset(cx, cy), halfBody, paint);
    }

    // Subtle belly stripe
    canvas.drawCircle(Offset(cx, cy), cs * 0.12, darkerPaint);
  }

  void _drawTail(Canvas canvas, int i, double cx, double cy, double cs, Paint paint) {
    final prev = segments[i - 1];
    final curr = segments[i];
    final dx = prev.x - curr.x;
    final dy = prev.y - curr.y;

    // Tapered triangle pointing away from the previous segment
    final path = Path();
    final tipX = cx - dx * cs * 0.4;
    final tipY = cy - dy * cs * 0.4;

    if (dx != 0) {
      // Horizontal tail
      path.moveTo(cx + dx * cs * 0.3, cy - cs * 0.4);
      path.lineTo(cx + dx * cs * 0.3, cy + cs * 0.4);
      path.lineTo(tipX, tipY);
      path.close();
    } else {
      // Vertical tail
      path.moveTo(cx - cs * 0.4, cy + dy * cs * 0.3);
      path.lineTo(cx + cs * 0.4, cy + dy * cs * 0.3);
      path.lineTo(tipX, tipY);
      path.close();
    }
    canvas.drawPath(path, paint);

    // Connect to body
    final bodyWidth = cs * 0.88;
    if (dx != 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + dx * cs * 0.15, cy),
            width: cs * 0.5,
            height: bodyWidth,
          ),
          Radius.circular(cs * 0.08),
        ),
        paint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy + dy * cs * 0.15),
            width: bodyWidth,
            height: cs * 0.5,
          ),
          Radius.circular(cs * 0.08),
        ),
        paint,
      );
    }
  }
}
