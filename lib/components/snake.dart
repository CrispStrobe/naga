import 'dart:collection';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';
import 'power_up.dart';
import '../game/shared/grid_snake_body.dart';

/// Re-evaluates the current public list, so retained views survive replacement.
class _SnakeOccupancy extends SetBase<int> {
  final Snake snake;
  _SnakeOccupancy(this.snake);

  @override
  Iterator<int> get iterator => toSet().iterator;
  @override
  int get length => toSet().length;
  @override
  bool contains(Object? value) =>
      snake.segments.any((cell) => Snake.encodePos(cell) == value);
  @override
  int? lookup(Object? value) => toSet().lookup(value);
  @override
  Set<int> toSet() => snake.segments.map(Snake.encodePos).toSet();
  @override
  bool add(int value) => throw UnsupportedError('Mutate Snake.segments');
  @override
  bool remove(Object? value) => throw UnsupportedError('Mutate Snake.segments');
}

class Snake extends Component with HasGameReference<SnakeGame> {
  // Keep the public mutable List API, including replacement/alias semantics.
  // Internally created bodies use the indexed ring; assigned Lists still work.
  List<Point<int>> segments;
  final SnakeGame _game;

  // Paints live with the component, not the frame. Only size/dynamic color
  // properties are updated while rendering; geometry still follows live state.
  final Paint _fillPaint = Paint();
  final Paint _borderPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _darkerPaint = Paint();
  final Paint _eyePaint = Paint()..color = Colors.white;
  final Paint _pupilPaint = Paint()..color = Colors.black;
  final Paint _tonguePaint = Paint()
    ..color = Colors.red.shade400
    ..strokeCap = StrokeCap.round;
  final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final Path _tailPath = Path();
  Color? _bodyColor;
  Color? _lastGlowColor;
  double? _lastGlowOpacity;

  void _syncBodyColor() {
    final color = _game.mode.snakeColor;
    if (_bodyColor == color) return;
    _bodyColor = color;
    _fillPaint.color = color;
    _borderPaint.color = color;
    _darkerPaint.color = Color.lerp(color, Colors.black, 0.2)!;
  }

  /// Stable, live view of legacy encoded occupancy, including aliased list edits.
  ///
  /// Unlike the historical mutable cache, this view is read-only: change
  /// [segments] to change occupancy. Independent set writes cannot safely
  /// describe a body with duplicate cells. Collision checks use exact Points
  /// via [occupies], not this legacy (potentially colliding) integer encoding.
  /// Reading the view scans the body; normal movement remains O(1) amortized.
  late final Set<int> occupiedCells = UnmodifiableSetView(
    _SnakeOccupancy(this),
  );

  Snake(this._game, {required List<Point<int>> initialSegments})
    : segments = GridSnakeBody(initialSegments);

  static int encodePos(Point<int> pos) => pos.y * 10000 + pos.x;

  bool occupies(Point<int> pos) => segments.contains(pos);

  void move(Point<int> newHead, {bool grow = false}) {
    segments.insert(0, newHead);
    if (!grow) segments.removeLast();
  }

  /// Remove tail segments (for shrink power-up), retaining at least the head.
  void removeTailSegments(int count) {
    final toRemove = count.clamp(0, max(0, segments.length - 1));
    for (int i = 0; i < toRemove; i++) {
      segments.removeLast();
    }
  }

  @override
  void render(Canvas canvas) {
    if (segments.isEmpty) return;
    _syncBodyColor();
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
    final fillPaint = _fillPaint;
    final borderPaint = _borderPaint..strokeWidth = cs * 0.12;
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
          Rect.fromLTWH(
            sp.x + inset,
            sp.y + inset,
            cs - inset * 2,
            cs - inset * 2,
          ),
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
    final paint = _fillPaint;
    final darkerPaint = _darkerPaint;

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

    // Draw buff glow behind head only (perf: blur is expensive)
    if (glowColor != null && segments.isNotEmpty) {
      final glowOpacity = _game.shieldFlashTimer > 0
          ? (_game.shieldFlashTimer / 0.5).clamp(0.0, 1.0) * 0.5
          : 0.3;
      if (_lastGlowColor != glowColor || _lastGlowOpacity != glowOpacity) {
        _glowPaint.color = glowColor.withValues(alpha: glowOpacity);
        _lastGlowColor = glowColor;
        _lastGlowOpacity = glowOpacity;
      }
      final glowPaint = _glowPaint;
      final headSp = _game.gridToScreen(segments.first);
      canvas.drawCircle(
        Offset(headSp.x + cs / 2, headSp.y + cs / 2),
        cs * 0.7,
        glowPaint,
      );
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

  void _drawHead(
    Canvas canvas,
    double cx,
    double cy,
    double cs,
    Paint paint,
    Paint darkerPaint,
  ) {
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
    final eyePaint = _eyePaint;
    final pupilPaint = _pupilPaint;
    final eyeR = cs * 0.13;
    final pupilR = cs * 0.07;

    double e1x, e1y, e2x, e2y;
    double px1, py1, px2, py2; // pupil offsets
    switch (_game.currentDirection) {
      case Direction.right:
        e1x = cx + cs * 0.12;
        e1y = cy - cs * 0.14;
        e2x = cx + cs * 0.12;
        e2y = cy + cs * 0.14;
        px1 = e1x + cs * 0.04;
        py1 = e1y;
        px2 = e2x + cs * 0.04;
        py2 = e2y;
      case Direction.left:
        e1x = cx - cs * 0.12;
        e1y = cy - cs * 0.14;
        e2x = cx - cs * 0.12;
        e2y = cy + cs * 0.14;
        px1 = e1x - cs * 0.04;
        py1 = e1y;
        px2 = e2x - cs * 0.04;
        py2 = e2y;
      case Direction.up:
        e1x = cx - cs * 0.14;
        e1y = cy - cs * 0.12;
        e2x = cx + cs * 0.14;
        e2y = cy - cs * 0.12;
        px1 = e1x;
        py1 = e1y - cs * 0.04;
        px2 = e2x;
        py2 = e2y - cs * 0.04;
      case Direction.down:
        e1x = cx - cs * 0.14;
        e1y = cy + cs * 0.12;
        e2x = cx + cs * 0.14;
        e2y = cy + cs * 0.12;
        px1 = e1x;
        py1 = e1y + cs * 0.04;
        px2 = e2x;
        py2 = e2y + cs * 0.04;
    }

    canvas.drawCircle(Offset(e1x, e1y), eyeR, eyePaint);
    canvas.drawCircle(Offset(e2x, e2y), eyeR, eyePaint);
    canvas.drawCircle(Offset(px1, py1), pupilR, pupilPaint);
    canvas.drawCircle(Offset(px2, py2), pupilR, pupilPaint);

    // Tongue (small red flick in movement direction)
    final tongPaint = _tonguePaint..strokeWidth = cs * 0.04;
    double tx, ty, tx2a, ty2a, tx2b, ty2b;
    switch (_game.currentDirection) {
      case Direction.right:
        tx = cx + cs * 0.45;
        ty = cy;
        tx2a = tx + cs * 0.12;
        ty2a = ty - cs * 0.06;
        tx2b = tx + cs * 0.12;
        ty2b = ty + cs * 0.06;
      case Direction.left:
        tx = cx - cs * 0.45;
        ty = cy;
        tx2a = tx - cs * 0.12;
        ty2a = ty - cs * 0.06;
        tx2b = tx - cs * 0.12;
        ty2b = ty + cs * 0.06;
      case Direction.up:
        tx = cx;
        ty = cy - cs * 0.45;
        tx2a = tx - cs * 0.06;
        ty2a = ty - cs * 0.12;
        tx2b = tx + cs * 0.06;
        ty2b = ty - cs * 0.12;
      case Direction.down:
        tx = cx;
        ty = cy + cs * 0.45;
        tx2a = tx - cs * 0.06;
        ty2a = ty + cs * 0.12;
        tx2b = tx + cs * 0.06;
        ty2b = ty + cs * 0.12;
    }
    canvas.drawLine(Offset(tx, ty), Offset(tx2a, ty2a), tongPaint);
    canvas.drawLine(Offset(tx, ty), Offset(tx2b, ty2b), tongPaint);
  }

  void _drawBody(
    Canvas canvas,
    int i,
    double cx,
    double cy,
    double cs,
    Paint paint,
    Paint darkerPaint,
  ) {
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
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: cs,
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
              center: Offset(cx, cy),
              width: bodyWidth,
              height: cs,
            ),
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

  void _drawTail(
    Canvas canvas,
    int i,
    double cx,
    double cy,
    double cs,
    Paint paint,
  ) {
    final prev = segments[i - 1];
    final curr = segments[i];
    final dx = prev.x - curr.x;
    final dy = prev.y - curr.y;

    // Tapered triangle pointing away from the previous segment
    final path = _tailPath..reset();
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
