import 'dart:math';
import 'package:flutter/material.dart';

/// Bright, cheerful home screen background — green snake with red eyes
/// crawling around eating red apples on a sunny meadow.
class SnakeAnimation extends StatefulWidget {
  const SnakeAnimation({super.key});

  @override
  State<SnakeAnimation> createState() => _SnakeAnimationState();
}

class _SnakeAnimationState extends State<SnakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const int _segmentCount = 18;
  static const double _speed = 0.35;

  double _t = 0;

  // Apples — scattered, respawn when eaten
  final List<Offset> _apples = [];
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

  void _tick() {
    final dt = 1.0 / 60.0;
    _t += _speed * dt;
  }

  Offset _snakePosition(double t, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.32;
    final rx = size.width * 0.36;
    final ry = size.height * 0.18;
    final x = cx + rx * sin(2 * t + pi / 4);
    final y = cy + ry * sin(3 * t);
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => CustomPaint(
            painter: _MeadowBackgroundPainter(t: _t),
            foregroundPainter: _SnakeAndApplesPainter(
              t: _t,
              segmentCount: _segmentCount,
              snakePosition: _snakePosition,
              apples: _apples,
              random: _random,
              initialized: _initialized,
              onInitialized: () => _initialized = true,
            ),
            size: Size.infinite,
          ),
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

  @override
  bool shouldRepaint(covariant _MeadowBackgroundPainter old) => true;
}

/// Green snake with red eyes crawling around eating bright red apples.
class _SnakeAndApplesPainter extends CustomPainter {
  final double t;
  final int segmentCount;
  final Offset Function(double t, Size size) snakePosition;
  final List<Offset> apples;
  final Random random;
  bool initialized;
  final VoidCallback onInitialized;

  _SnakeAndApplesPainter({
    required this.t,
    required this.segmentCount,
    required this.snakePosition,
    required this.apples,
    required this.random,
    required this.initialized,
    required this.onInitialized,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Initialize apples once we know the size
    if (!initialized) {
      for (int i = 0; i < 6; i++) {
        apples.add(Offset(
          30 + random.nextDouble() * (size.width - 60),
          40 + random.nextDouble() * (size.height * 0.5 - 40),
        ));
      }
      onInitialized();
    }

    // Build snake segment positions
    final positions = <Offset>[];
    const segmentDelay = 0.06;
    for (int i = 0; i < segmentCount; i++) {
      positions.add(snakePosition(t - i * segmentDelay, size));
    }

    final head = positions.first;

    // Check if head is near any apple — "eat" it
    for (int i = apples.length - 1; i >= 0; i--) {
      if ((apples[i] - head).distance < 18) {
        // Respawn at random position
        apples[i] = Offset(
          30 + random.nextDouble() * (size.width - 60),
          40 + random.nextDouble() * (size.height * 0.5 - 40),
        );
      }
    }

    // Draw apples
    _drawApples(canvas);

    // Draw snake body
    _drawSnakeBody(canvas, positions);

    // Draw snake head with eyes
    _drawSnakeHead(canvas, positions);
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

  void _drawSnakeBody(Canvas canvas, List<Offset> positions) {
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

  void _drawSnakeHead(Canvas canvas, List<Offset> positions) {
    final head = positions.first;

    // Direction the snake is facing
    double angle = 0;
    if (positions.length > 1) {
      angle = atan2(head.dy - positions[1].dy, head.dx - positions[1].dx);
    }

    // Head — larger, bright green
    final headPaint = Paint()..color = const Color(0xFF2E7D32).withOpacity(0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: head,
        width: 16,
        height: 13,
      ),
      headPaint,
    );

    // Top of head — lighter
    final headTopPaint = Paint()..color = const Color(0xFF66BB6A).withOpacity(0.6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(head.dx, head.dy - 1),
        width: 12,
        height: 8,
      ),
      headTopPaint,
    );

    // Eyes — bright red with black pupils
    final eyeOffset = 4.0;
    final eyeForward = 2.0;
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

    // Forked tongue — flickers
    final tongueOut = sin(t * 6) > 0.3;
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
      final forkLen = 4.0;
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
