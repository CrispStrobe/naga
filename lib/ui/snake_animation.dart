import 'dart:math';
import 'package:flutter/material.dart';

/// Bright, cheerful home screen background — green snake with red eyes
/// slithering around a sunny meadow, hunting down and eating red apples.
class SnakeAnimation extends StatefulWidget {
  const SnakeAnimation({super.key});

  @override
  State<SnakeAnimation> createState() => _SnakeAnimationState();
}

class _EatBurst {
  final Offset pos;
  double age = 0;
  _EatBurst(this.pos);
}

class _SnakeAnimationState extends State<SnakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const double _speed = 75.0; // px per second
  static const double _turnRate = 3.2; // rad per second
  static const double _segmentSpacing = 7.0;
  static const int _startSegments = 16;
  static const int _maxSegments = 30;
  static const double _eatRadius = 13.0;

  double _t = 0;
  Size _size = Size.zero;

  Offset _head = Offset.zero;
  double _heading = 0;
  int _segments = _startSegments;
  final List<Offset> _trail = [];
  double _chompTimer = 0;

  final List<Offset> _apples = [];
  final List<_EatBurst> _bursts = [];
  final Random _random = Random();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _randomAppleSpot() {
    return Offset(
      30 + _random.nextDouble() * (_size.width - 60),
      40 + _random.nextDouble() * (_size.height * 0.7 - 40),
    );
  }

  void _initWorld() {
    _head = Offset(_size.width * 0.5, _size.height * 0.35);
    _heading = _random.nextDouble() * 2 * pi;
    _trail
      ..clear()
      ..add(_head);
    _apples.clear();
    for (int i = 0; i < 6; i++) {
      _apples.add(_randomAppleSpot());
    }
    _initialized = true;
  }

  void _tick() {
    const dt = 1.0 / 60.0;
    _t += dt;
    if (!_initialized || _size == Size.zero) return;

    // Steer toward the nearest apple, with a slithery wiggle.
    Offset? target;
    double best = double.infinity;
    for (final a in _apples) {
      final d = (a - _head).distance;
      if (d < best) {
        best = d;
        target = a;
      }
    }
    if (target != null) {
      final desired =
          atan2(target.dy - _head.dy, target.dx - _head.dx) +
              sin(_t * 4.5) * 0.45; // wiggle fades nothing near apple
      var diff = (desired - _heading) % (2 * pi);
      if (diff > pi) diff -= 2 * pi;
      if (diff < -pi) diff += 2 * pi;
      final maxTurn = _turnRate * dt;
      _heading += diff.clamp(-maxTurn, maxTurn);
    }

    // Move forward.
    _head += Offset(cos(_heading), sin(_heading)) * (_speed * dt);

    // Keep inside bounds — bounce heading back toward the middle.
    const margin = 14.0;
    if (_head.dx < margin || _head.dx > _size.width - margin ||
        _head.dy < margin || _head.dy > _size.height - margin) {
      _head = Offset(
        _head.dx.clamp(margin, _size.width - margin),
        _head.dy.clamp(margin, _size.height - margin),
      );
      final center = Offset(_size.width / 2, _size.height / 2);
      _heading = atan2(center.dy - _head.dy, center.dx - _head.dx);
    }

    // Record trail (body follows head along its actual path).
    if (_trail.isEmpty || (_trail.first - _head).distance > 1.0) {
      _trail.insert(0, _head);
    }
    final maxTrail = (_segments * _segmentSpacing / 1.0).ceil() + 60;
    if (_trail.length > maxTrail) {
      _trail.removeRange(maxTrail, _trail.length);
    }

    // Eat apples the head touches.
    for (int i = _apples.length - 1; i >= 0; i--) {
      if ((_apples[i] - _head).distance < _eatRadius) {
        _bursts.add(_EatBurst(_apples[i]));
        _apples[i] = _randomAppleSpot();
        _chompTimer = 0.35;
        if (_segments < _maxSegments) _segments++;
      }
    }

    if (_chompTimer > 0) _chompTimer -= dt;

    // Age out sparkle bursts.
    for (final b in _bursts) {
      b.age += dt;
    }
    _bursts.removeWhere((b) => b.age > 0.6);
  }

  /// Sample segment positions by walking back along the recorded trail.
  List<Offset> _segmentPositions() {
    final positions = <Offset>[_head];
    double needed = _segmentSpacing;
    double walked = 0;
    for (int i = 1; i < _trail.length && positions.length < _segments; i++) {
      final a = _trail[i - 1];
      final b = _trail[i];
      final stepLen = (b - a).distance;
      while (walked + stepLen >= needed && positions.length < _segments) {
        final f = (needed - walked) / stepLen;
        positions.add(Offset.lerp(a, b, f)!);
        needed += _segmentSpacing;
      }
      walked += stepLen;
    }
    // If the trail is still short (just spawned), pad behind the head.
    while (positions.length < _segments) {
      positions.add(positions.last -
          Offset(cos(_heading), sin(_heading)) * _segmentSpacing);
    }
    return positions;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final newSize = Size(constraints.maxWidth, constraints.maxHeight);
            if (newSize != _size && newSize.width > 0 && newSize.height > 0) {
              _size = newSize;
              if (!_initialized) {
                _initWorld();
              } else {
                // Keep everything in bounds after a resize.
                _head = Offset(
                  _head.dx.clamp(14.0, _size.width - 14),
                  _head.dy.clamp(14.0, _size.height - 14),
                );
                for (int i = 0; i < _apples.length; i++) {
                  final a = _apples[i];
                  if (a.dx > _size.width - 30 || a.dy > _size.height - 40) {
                    _apples[i] = _randomAppleSpot();
                  }
                }
              }
            }
            return ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => CustomPaint(
                painter: _MeadowBackgroundPainter(t: _t),
                foregroundPainter: _SnakeAndApplesPainter(
                  t: _t,
                  positions: _initialized ? _segmentPositions() : const [],
                  heading: _heading,
                  apples: _apples,
                  bursts: _bursts,
                  chomping: _chompTimer > 0,
                ),
                size: Size.infinite,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bright sunny meadow background with flowers, grass, and butterflies.
class _MeadowBackgroundPainter extends CustomPainter {
  final double t;
  _MeadowBackgroundPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Warm sunny gradient — light yellow to soft green
    final bgGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFF9C4), // warm sunlit yellow
          Color(0xFFFFF3E0), // peach
          Color(0xFFC8E6C9), // soft meadow green
          Color(0xFFA5D6A7), // grass green
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgGradient);

    _drawRiver(canvas, w, h);
    _drawPalms(canvas, w, h);
    _drawVines(canvas, w, h);

    // Grass tufts along the bottom
    for (double x = 0; x < w; x += 8) {
      final sway = sin(t * 0.8 + x * 0.15) * 3;
      final gh = 12 + sin(x * 0.4) * 6 + cos(x * 0.9) * 4;
      final grassColor = Color.lerp(
        const Color(0xFF66BB6A),
        const Color(0xFF43A047),
        (sin(x * 0.3) * 0.5 + 0.5),
      )!;
      final grassPaint = Paint()..color = grassColor.withOpacity(0.6);
      final path = Path()
        ..moveTo(x, h)
        ..quadraticBezierTo(x + sway + 2, h - gh * 0.6, x + sway, h - gh)
        ..quadraticBezierTo(x + sway + 4, h - gh * 0.6, x + 5, h)
        ..close();
      canvas.drawPath(path, grassPaint);
    }

    // Small flowers scattered
    final flowerColors = [
      const Color(0xFFFF5252), // red
      const Color(0xFFFFD740), // yellow
      const Color(0xFFFF80AB), // pink
      const Color(0xFFFF6E40), // orange
      const Color(0xFFE040FB), // purple
    ];
    for (int i = 0; i < 20; i++) {
      final fx = (i * 47.0 + 15) % w;
      final fy = h - 20 - (sin(i * 2.3) * 12 + cos(i * 1.7) * 8).abs();
      final color = flowerColors[i % flowerColors.length];
      final sway = sin(t * 0.6 + i * 1.1) * 2;

      // Stem
      final stemPaint = Paint()
        ..color = const Color(0xFF4CAF50).withOpacity(0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(fx + sway, fy), Offset(fx, h), stemPaint);

      // Petals
      final petalPaint = Paint()..color = color.withOpacity(0.5);
      for (int p = 0; p < 5; p++) {
        final angle = p * pi * 2 / 5 + t * 0.2;
        final px = fx + sway + cos(angle) * 4;
        final py = fy + sin(angle) * 4;
        canvas.drawCircle(Offset(px, py), 2.5, petalPaint);
      }
      // Center
      canvas.drawCircle(
        Offset(fx + sway, fy),
        1.5,
        Paint()..color = const Color(0xFFFFEB3B).withOpacity(0.6),
      );
    }

    _drawDragonflies(canvas, w, h);

    // Butterflies floating around
    for (int i = 0; i < 5; i++) {
      final bx = (i * 89.0 + sin(t * 0.4 + i * 2.3) * 40) % w;
      final by = h * 0.3 + sin(t * 0.6 + i * 1.5) * h * 0.15;
      final wingFlap = sin(t * 6 + i * 2) * 0.4;
      final bColor = flowerColors[(i + 2) % flowerColors.length];

      final wingPaint = Paint()..color = bColor.withOpacity(0.35);
      // Left wing
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bx - 4 * cos(wingFlap), by),
          width: 6, height: 4 * (1 + wingFlap.abs()),
        ),
        wingPaint,
      );
      // Right wing
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bx + 4 * cos(wingFlap), by),
          width: 6, height: 4 * (1 + wingFlap.abs()),
        ),
        wingPaint,
      );
      // Body
      canvas.drawCircle(Offset(bx, by), 1.2, Paint()..color = Colors.brown.withOpacity(0.4));
    }

    // Subtle sun in top-right corner
    final sunPaint = Paint()
      ..color = const Color(0xFFFFD740).withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(Offset(w * 0.85, h * 0.05), 40, sunPaint);
    final sunCore = Paint()..color = const Color(0xFFFFECB3).withOpacity(0.35);
    canvas.drawCircle(Offset(w * 0.85, h * 0.05), 18, sunCore);
  }

  /// Winding river band with shimmer and floating lotus.
  void _drawRiver(Canvas canvas, double w, double h) {
    final topY = h * 0.66;
    final bottomY = h * 0.78;

    final river = Path()..moveTo(0, topY + sin(0.5) * 6);
    for (double x = 0; x <= w; x += 24) {
      river.lineTo(x, topY + sin(x * 0.02 + 1.0) * 7);
    }
    river.lineTo(w, bottomY + sin(w * 0.015) * 8);
    for (double x = w; x >= 0; x -= 24) {
      river.lineTo(x, bottomY + sin(x * 0.015 + 2.5) * 8);
    }
    river.close();
    canvas.drawPath(
      river,
      Paint()..color = const Color(0xFF81D4FA).withOpacity(0.55),
    );

    // Shimmer streaks drifting with the current
    final shimmer = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 7; i++) {
      final sx = ((i * 73.0 + t * 24) % (w + 40)) - 20;
      final sy = topY + 8 + (i % 3) * (bottomY - topY - 16) / 3 + sin(t + i) * 2;
      canvas.drawLine(Offset(sx, sy), Offset(sx + 14, sy), shimmer);
    }

    // Lotus pads + blossoms
    for (int i = 0; i < 3; i++) {
      final lx = w * (0.2 + i * 0.3) + sin(t * 0.5 + i * 2.0) * 6;
      final ly = (topY + bottomY) / 2 + (i - 1) * 6;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(lx, ly + 3), width: 18, height: 7),
        Paint()..color = const Color(0xFF2E7D32).withOpacity(0.5),
      );
      if (i != 1) continue; // one blossom in the middle
      final petal = Paint()..color = const Color(0xFFFF80AB).withOpacity(0.8);
      for (int p = 0; p < 6; p++) {
        final a = p * pi / 3 + t * 0.1;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(lx + cos(a) * 4, ly - 2 + sin(a) * 2.5),
            width: 7,
            height: 4,
          ),
          petal,
        );
      }
      canvas.drawCircle(
        Offset(lx, ly - 2),
        2,
        Paint()..color = const Color(0xFFFFEB3B),
      );
    }
  }

  /// Palm trees leaning in from the sides.
  void _drawPalms(Canvas canvas, double w, double h) {
    for (final side in [-1, 1]) {
      final baseX = side == -1 ? w * 0.06 : w * 0.94;
      final baseY = h * 0.98;
      final topX = baseX + side * w * 0.05;
      final topY = h * 0.62;
      final sway = sin(t * 0.5 + side) * 4;

      final trunk = Paint()
        ..color = const Color(0xFF8D6E63).withOpacity(0.55)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final trunkPath = Path()
        ..moveTo(baseX, baseY)
        ..quadraticBezierTo(
            baseX + side * 10, (baseY + topY) / 2, topX + sway, topY);
      canvas.drawPath(trunkPath, trunk);

      // Fronds fanning out from the crown
      final frond = Paint()
        ..color = const Color(0xFF2E7D32).withOpacity(0.45)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int f = 0; f < 6; f++) {
        final a = pi * (0.15 + f * 0.14) + sway * 0.01;
        final len = w * 0.09 + (f % 2) * 8;
        final ex = topX + sway + cos(a) * len * -side;
        final ey = topY - sin(a) * len * 0.6 + 10;
        final frondPath = Path()
          ..moveTo(topX + sway, topY)
          ..quadraticBezierTo(
              (topX + sway + ex) / 2, topY - 18 + sin(t + f) * 2, ex, ey);
        canvas.drawPath(frondPath, frond);
      }
      // Coconuts
      canvas.drawCircle(Offset(topX + sway - 4, topY + 4), 3.5,
          Paint()..color = const Color(0xFF6D4C41).withOpacity(0.6));
      canvas.drawCircle(Offset(topX + sway + 4, topY + 5), 3.5,
          Paint()..color = const Color(0xFF6D4C41).withOpacity(0.6));
    }
  }

  /// Hanging vines swaying along the top edge.
  void _drawVines(Canvas canvas, double w, double h) {
    final vinePaint = Paint()
      ..color = const Color(0xFF388E3C).withOpacity(0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final leafPaint = Paint()..color = const Color(0xFF43A047).withOpacity(0.4);

    for (int i = 0; i < 4; i++) {
      final vx = w * (0.12 + i * 0.24);
      final len = h * (0.10 + (i % 2) * 0.05);
      final sway = sin(t * 0.7 + i * 1.4) * 6;
      final vine = Path()
        ..moveTo(vx, 0)
        ..quadraticBezierTo(vx + sway * 0.5, len * 0.5, vx + sway, len);
      canvas.drawPath(vine, vinePaint);
      // Leaves along the vine
      for (int l = 1; l <= 3; l++) {
        final f = l / 3.0;
        final lx = vx + sway * f * f;
        final ly = len * f;
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(lx + (l.isEven ? 5 : -5), ly), width: 9, height: 5),
          leafPaint,
        );
      }
    }
  }

  /// Dragonflies zipping above the river.
  void _drawDragonflies(Canvas canvas, double w, double h) {
    for (int i = 0; i < 3; i++) {
      final dx = (i * 127.0 + t * 30 + sin(t * 1.3 + i * 2) * 25) % (w + 30) - 15;
      final dy = h * 0.6 + sin(t * 2.1 + i * 1.7) * h * 0.06;
      final flap = sin(t * 14 + i) * 0.5;

      final wing = Paint()..color = const Color(0xFF80DEEA).withOpacity(0.45);
      for (final side in [-1, 1]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(dx + side * 4.0, dy - 2),
            width: 9,
            height: 2.5 + flap.abs() * 2,
          ),
          wing,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(dx + side * 3.0, dy + 1),
            width: 7,
            height: 2 + flap.abs() * 1.5,
          ),
          wing,
        );
      }
      // Long thin body
      canvas.drawLine(
        Offset(dx - 6, dy),
        Offset(dx + 6, dy),
        Paint()
          ..color = const Color(0xFF00838F).withOpacity(0.6)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeadowBackgroundPainter old) => true;
}

/// Green snake with red eyes chasing and eating bright red apples.
class _SnakeAndApplesPainter extends CustomPainter {
  final double t;
  final List<Offset> positions;
  final double heading;
  final List<Offset> apples;
  final List<_EatBurst> bursts;
  final bool chomping;

  _SnakeAndApplesPainter({
    required this.t,
    required this.positions,
    required this.heading,
    required this.apples,
    required this.bursts,
    required this.chomping,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty) return;

    _drawApples(canvas);
    _drawBursts(canvas);
    _drawSnakeBody(canvas);
    _drawSnakeHead(canvas);
  }

  void _drawApples(Canvas canvas) {
    for (final apple in apples) {
      // Apple shadow
      canvas.drawOval(
        Rect.fromCenter(center: Offset(apple.dx + 1, apple.dy + 2), width: 14, height: 8),
        Paint()..color = Colors.black.withOpacity(0.08),
      );

      // Apple body — bright red
      final applePaint = Paint()..color = const Color(0xFFE53935);
      canvas.drawCircle(apple, 7, applePaint);

      // Shine
      canvas.drawCircle(
        Offset(apple.dx - 2, apple.dy - 2),
        2.5,
        Paint()..color = Colors.white.withOpacity(0.4),
      );

      // Stem
      final stemPaint = Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(apple.dx, apple.dy - 7),
        Offset(apple.dx + 2, apple.dy - 10),
        stemPaint,
      );

      // Tiny leaf
      final leafPaint = Paint()..color = const Color(0xFF4CAF50);
      final leafPath = Path()
        ..moveTo(apple.dx + 2, apple.dy - 10)
        ..quadraticBezierTo(apple.dx + 6, apple.dy - 12, apple.dx + 5, apple.dy - 8);
      canvas.drawPath(leafPath, leafPaint);
    }
  }

  void _drawBursts(Canvas canvas) {
    for (final b in bursts) {
      final p = (b.age / 0.6).clamp(0.0, 1.0);
      final fade = 1.0 - p;

      // Expanding ring
      canvas.drawCircle(
        b.pos,
        6 + p * 18,
        Paint()
          ..color = const Color(0xFFFFD740).withOpacity(0.5 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * fade + 0.5,
      );

      // Flying apple bits
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3 + 0.4;
        final r = 4 + p * 20;
        canvas.drawCircle(
          Offset(b.pos.dx + cos(a) * r, b.pos.dy + sin(a) * r - p * 6),
          2.2 * fade,
          Paint()..color = const Color(0xFFE53935).withOpacity(0.7 * fade),
        );
      }
    }
  }

  void _drawSnakeBody(Canvas canvas) {
    // Body segments — bright green, getting thinner toward tail
    for (int i = positions.length - 1; i >= 1; i--) {
      final progress = 1.0 - (i / positions.length);
      final radius = 6.0 + progress * 4.0; // 6→10

      // Alternating darker/lighter green scales
      final isEven = i % 2 == 0;
      final color = isEven
          ? const Color(0xFF4CAF50) // medium green
          : const Color(0xFF388E3C); // darker green
      final bodyPaint = Paint()..color = color.withOpacity(0.7);
      canvas.drawCircle(positions[i], radius, bodyPaint);

      // Belly highlight
      final bellyPaint = Paint()..color = const Color(0xFFA5D6A7).withOpacity(0.3);
      canvas.drawCircle(
        Offset(positions[i].dx, positions[i].dy + radius * 0.3),
        radius * 0.5,
        bellyPaint,
      );
    }
  }

  void _drawSnakeHead(Canvas canvas) {
    final head = positions.first;
    final angle = heading;

    // Distance to nearest apple — open mouth when closing in
    double nearest = double.infinity;
    for (final a in apples) {
      final d = (a - head).distance;
      if (d < nearest) nearest = d;
    }
    final mouthOpen = chomping || nearest < 45;

    // Head — larger, bright green
    final headPaint = Paint()..color = const Color(0xFF2E7D32).withOpacity(0.85);
    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 17, height: 13),
      headPaint,
    );
    // Top of head — lighter
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-1, -1), width: 12, height: 8),
      Paint()..color = const Color(0xFF66BB6A).withOpacity(0.6),
    );

    // Open mouth — dark red wedge at the front of the head
    if (mouthOpen) {
      final gape = chomping ? 0.55 : 0.35;
      final mouth = Path()
        ..moveTo(2, 0)
        ..lineTo(2 + cos(gape) * 9, -sin(gape) * 9)
        ..lineTo(2 + cos(gape) * 9, sin(gape) * 9)
        ..close();
      canvas.drawPath(mouth, Paint()..color = const Color(0xFFB71C1C).withOpacity(0.85));
    }
    canvas.restore();

    // Eyes — bright red with black pupils
    const eyeOffset = 4.0;
    const eyeForward = 2.0;
    final e1 = Offset(
      head.dx + cos(angle) * eyeForward + cos(angle + pi / 2) * eyeOffset,
      head.dy + sin(angle) * eyeForward + sin(angle + pi / 2) * eyeOffset,
    );
    final e2 = Offset(
      head.dx + cos(angle) * eyeForward - cos(angle + pi / 2) * eyeOffset,
      head.dy + sin(angle) * eyeForward - sin(angle + pi / 2) * eyeOffset,
    );

    // Red eye glow
    final eyeGlow = Paint()
      ..color = const Color(0xFFFF1744).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(e1, 4, eyeGlow);
    canvas.drawCircle(e2, 4, eyeGlow);

    // Eye whites
    final eyePaint = Paint()..color = const Color(0xFFFF1744).withOpacity(0.8);
    canvas.drawCircle(e1, 3, eyePaint);
    canvas.drawCircle(e2, 3, eyePaint);

    // Pupils — black, looking forward
    final pupilPaint = Paint()..color = Colors.black.withOpacity(0.8);
    final pupilDir = Offset(cos(angle) * 0.8, sin(angle) * 0.8);
    canvas.drawCircle(e1 + pupilDir, 1.5, pupilPaint);
    canvas.drawCircle(e2 + pupilDir, 1.5, pupilPaint);

    // Forked tongue — flickers (tucked away while the mouth is open)
    final tongueOut = !mouthOpen && sin(t * 6) > 0.3;
    if (tongueOut) {
      final tongPaint = Paint()
        ..color = const Color(0xFFFF1744).withOpacity(0.7)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final tongBase = Offset(
        head.dx + cos(angle) * 9,
        head.dy + sin(angle) * 9,
      );
      final tongTip = Offset(
        head.dx + cos(angle) * 16,
        head.dy + sin(angle) * 16,
      );
      canvas.drawLine(tongBase, tongTip, tongPaint);
      // Fork
      const forkLen = 4.0;
      canvas.drawLine(
        tongTip,
        Offset(
          tongTip.dx + cos(angle + 0.4) * forkLen,
          tongTip.dy + sin(angle + 0.4) * forkLen,
        ),
        tongPaint,
      );
      canvas.drawLine(
        tongTip,
        Offset(
          tongTip.dx + cos(angle - 0.4) * forkLen,
          tongTip.dy + sin(angle - 0.4) * forkLen,
        ),
        tongPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SnakeAndApplesPainter oldDelegate) => true;
}
