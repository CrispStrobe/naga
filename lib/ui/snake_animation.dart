import 'dart:math';
import 'package:flutter/material.dart';

/// Animated snake that slithers across the home screen background,
/// cycling through visual styles representing different game modes.
class SnakeAnimation extends StatefulWidget {
  const SnakeAnimation({super.key});

  @override
  State<SnakeAnimation> createState() => _SnakeAnimationState();
}

class _SnakeAnimationState extends State<SnakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const int _segmentCount = 15;
  static const double _speed = 0.4; // parameter increment per second

  // Current parametric position along the Lissajous curve
  double _t = 0;

  // Style cycling
  int _currentStyleIndex = 0;
  double _styleCycleTimer = 0;
  static const double _styleCycleDuration = 3.0;

  // ASCII characters for ASCII style
  static const String _asciiChars = '█▓▒░@#%&*';

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
    final dt = 1.0 / 60.0; // ~60fps
    _t += _speed * dt;
    _styleCycleTimer += dt;
    if (_styleCycleTimer >= _styleCycleDuration) {
      _styleCycleTimer = 0;
      _currentStyleIndex =
          (_currentStyleIndex + 1) % _snakeStyles.length;
    }
    // No setState — CustomPaint repaints via the AnimationController's Listenable
  }

  Offset _lissajousPosition(double t, Size size) {
    // Lissajous figure that spans the screen
    final cx = size.width * 0.5;
    final cy = size.height * 0.35;
    final rx = size.width * 0.38;
    final ry = size.height * 0.2;
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
            painter: _JungleBackgroundPainter(t: _t),
            foregroundPainter: _SnakePainter(
              t: _t,
              segmentCount: _segmentCount,
              style: _snakeStyles[_currentStyleIndex],
              lissajousPosition: _lissajousPosition,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// Draws a subtle jungle/forest background with trees, vines, and fireflies.
class _JungleBackgroundPainter extends CustomPainter {
  final double t;
  _JungleBackgroundPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gradient background — rich jungle greens
    final bgGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1A3320),
          Color(0xFF14291A),
          Color(0xFF1E3B22),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgGradient);

    // Tree silhouettes on left and right edges
    _drawTree(canvas, w * 0.02, h, w * 0.15, true);
    _drawTree(canvas, w * 0.88, h, w * 0.14, false);
    _drawTree(canvas, w * -0.05, h, w * 0.12, true);
    _drawTree(canvas, w * 0.93, h, w * 0.10, false);

    // Hanging vines from top
    final vinePaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final vx = w * (0.05 + i * 0.13);
      final vineLen = h * (0.08 + sin(i * 1.7) * 0.06);
      final sway = sin(t * 0.5 + i * 2.1) * 8;
      final path = Path()
        ..moveTo(vx, 0)
        ..quadraticBezierTo(vx + sway, vineLen * 0.5, vx + sway * 0.6, vineLen);
      canvas.drawPath(path, vinePaint);
      // Leaf at tip
      final leafPaint = Paint()..color = const Color(0xFF4CAF50).withOpacity(0.35);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(vx + sway * 0.6, vineLen + 3),
          width: 8, height: 5,
        ),
        leafPaint,
      );
    }

    // Ground foliage at bottom
    final foliagePaint = Paint()..color = const Color(0xFF388E3C).withOpacity(0.35);
    for (double x = 0; x < w; x += 12) {
      final fh = 8 + sin(x * 0.3) * 5 + cos(x * 0.7) * 3;
      final sway = sin(t * 0.3 + x * 0.1) * 3;
      final path = Path()
        ..moveTo(x, h)
        ..quadraticBezierTo(x + sway + 3, h - fh, x + 6, h - fh - 2)
        ..quadraticBezierTo(x + sway + 9, h - fh, x + 12, h)
        ..close();
      canvas.drawPath(path, foliagePaint);
    }

    // Fireflies — small glowing dots that float
    for (int i = 0; i < 12; i++) {
      final fx = (i * 79.0 + sin(t * 0.7 + i * 1.3) * 30) % w;
      final fy = (i * 53.0 + cos(t * 0.5 + i * 0.9) * 20) % (h * 0.7) + h * 0.1;
      final brightness = (sin(t * 2.0 + i * 1.7) * 0.5 + 0.5).clamp(0.0, 1.0);
      if (brightness < 0.3) continue;

      // Glow
      final glowPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFD740),
          const Color(0xFF76FF03),
          (i % 3) / 2.0,
        )!.withOpacity(brightness * 0.3);
      canvas.drawCircle(Offset(fx, fy), 8, glowPaint);
      // Core
      final corePaint = Paint()
        ..color = const Color(0xFFFFD740).withOpacity(brightness * 0.7);
      canvas.drawCircle(Offset(fx, fy), 2, corePaint);
    }
  }

  void _drawTree(Canvas canvas, double x, double h, double trunkW, bool leanRight) {
    final trunkPaint = Paint()..color = const Color(0xFF3E2723).withOpacity(0.45);
    final lean = leanRight ? 1.0 : -1.0;

    // Trunk
    final trunkPath = Path()
      ..moveTo(x, h)
      ..lineTo(x + trunkW * 0.3, h)
      ..quadraticBezierTo(
        x + trunkW * 0.4 + lean * trunkW * 0.1, h * 0.3,
        x + trunkW * 0.35 + lean * trunkW * 0.2, h * 0.05,
      )
      ..lineTo(x + trunkW * 0.15 + lean * trunkW * 0.2, h * 0.05)
      ..quadraticBezierTo(
        x + trunkW * 0.1 + lean * trunkW * 0.05, h * 0.3,
        x, h,
      )
      ..close();
    canvas.drawPath(trunkPath, trunkPaint);

    // Canopy blobs
    final canopyPaint = Paint()..color = const Color(0xFF2E7D32).withOpacity(0.4);
    final cx = x + trunkW * 0.25 + lean * trunkW * 0.2;
    final cy = h * 0.08;
    for (final offset in [Offset(-trunkW * 0.3, 0), Offset(trunkW * 0.2, -trunkW * 0.1), Offset(0, trunkW * 0.15)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + offset.dx, cy + offset.dy),
          width: trunkW * 0.8,
          height: trunkW * 0.5,
        ),
        canopyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _JungleBackgroundPainter old) => true;
}

/// Visual style definitions for each game mode.
class _SnakeStyle {
  final String name;
  final Color primaryColor;
  final Color? secondaryColor;
  final _SnakeDrawMode drawMode;

  const _SnakeStyle({
    required this.name,
    required this.primaryColor,
    this.secondaryColor,
    required this.drawMode,
  });
}

enum _SnakeDrawMode {
  blocky, // Classic LCD squares
  neonRounded, // Arcade neon glow
  softGlow, // Zen smooth
  pacman, // Maze Hunter
  trail, // Trail with fading segments
  dungeon, // Stone-textured
  ascii, // Text characters
}

const List<_SnakeStyle> _snakeStyles = [
  _SnakeStyle(
    name: 'Classic',
    primaryColor: Color(0xFF9BBC0F),
    secondaryColor: Color(0xFF0F380F),
    drawMode: _SnakeDrawMode.blocky,
  ),
  _SnakeStyle(
    name: 'Arcade',
    primaryColor: Color(0xFF00FF88),
    drawMode: _SnakeDrawMode.neonRounded,
  ),
  _SnakeStyle(
    name: 'Zen',
    primaryColor: Color(0xFF7B68EE),
    drawMode: _SnakeDrawMode.softGlow,
  ),
  _SnakeStyle(
    name: 'Maze Hunter',
    primaryColor: Color(0xFFFFFF00),
    drawMode: _SnakeDrawMode.pacman,
  ),
  _SnakeStyle(
    name: 'Trail',
    primaryColor: Color(0xFF00E5FF),
    drawMode: _SnakeDrawMode.trail,
  ),
  _SnakeStyle(
    name: 'Dungeon',
    primaryColor: Color(0xFF00FF66),
    drawMode: _SnakeDrawMode.dungeon,
  ),
  _SnakeStyle(
    name: 'ASCII',
    primaryColor: Color(0xFF00FF00),
    drawMode: _SnakeDrawMode.ascii,
  ),
];

class _SnakePainter extends CustomPainter {
  final double t;
  final int segmentCount;
  final _SnakeStyle style;
  final Offset Function(double t, Size size) lissajousPosition;

  _SnakePainter({
    required this.t,
    required this.segmentCount,
    required this.style,
    required this.lissajousPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Build segment positions by sampling the curve with delays
    final positions = <Offset>[];
    const segmentDelay = 0.07;
    for (int i = 0; i < segmentCount; i++) {
      final segT = t - i * segmentDelay;
      positions.add(lissajousPosition(segT, size));
    }

    switch (style.drawMode) {
      case _SnakeDrawMode.blocky:
        _drawBlocky(canvas, positions);
      case _SnakeDrawMode.neonRounded:
        _drawNeonRounded(canvas, positions);
      case _SnakeDrawMode.softGlow:
        _drawSoftGlow(canvas, positions);
      case _SnakeDrawMode.pacman:
        _drawPacman(canvas, positions);
      case _SnakeDrawMode.trail:
        _drawTrail(canvas, positions);
      case _SnakeDrawMode.dungeon:
        _drawDungeon(canvas, positions);
      case _SnakeDrawMode.ascii:
        _drawAscii(canvas, positions);
    }
  }

  void _drawBlocky(Canvas canvas, List<Offset> positions) {
    const segSize = 14.0;
    final fillColor = style.secondaryColor ?? style.primaryColor;
    final paint = Paint()
      ..color = fillColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < positions.length; i++) {
      final p = positions[i];
      // Snap to grid for retro feel
      final sx = (p.dx / segSize).round() * segSize;
      final sy = (p.dy / segSize).round() * segSize;
      canvas.drawRect(
        Rect.fromLTWH(sx, sy, segSize - 1, segSize - 1),
        paint,
      );
    }
  }

  void _drawNeonRounded(Canvas canvas, List<Offset> positions) {
    const radius = 8.0;
    // Glow layer
    final glowPaint = Paint()
      ..color = style.primaryColor.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    for (final p in positions) {
      canvas.drawCircle(p, radius + 6, glowPaint);
    }
    // Main segments
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < positions.length; i++) {
      final scale = 1.0 - (i / positions.length) * 0.4;
      canvas.drawCircle(positions[i], radius * scale, paint);
    }
  }

  void _drawSoftGlow(Canvas canvas, List<Offset> positions) {
    const radius = 9.0;
    final glowPaint = Paint()
      ..color = style.primaryColor.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    for (final p in positions) {
      canvas.drawCircle(p, radius + 10, glowPaint);
    }
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < positions.length; i++) {
      final scale = 1.0 - (i / positions.length) * 0.3;
      canvas.drawCircle(positions[i], radius * scale, paint);
    }
  }

  void _drawPacman(Canvas canvas, List<Offset> positions) {
    const radius = 8.0;
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Body segments as circles
    for (int i = 1; i < positions.length; i++) {
      final scale = 1.0 - (i / positions.length) * 0.3;
      canvas.drawCircle(positions[i], radius * scale * 0.8, paint);
    }

    // Head as Pac-Man with animated mouth
    if (positions.isNotEmpty) {
      final head = positions[0];
      final mouthAngle = (sin(t * 8) * 0.3).abs() + 0.1;
      // Direction from head to next segment (reversed = forward direction)
      double direction = 0;
      if (positions.length > 1) {
        final dx = positions[0].dx - positions[1].dx;
        final dy = positions[0].dy - positions[1].dy;
        direction = atan2(dy, dx);
      }
      canvas.drawArc(
        Rect.fromCircle(center: head, radius: radius),
        direction + mouthAngle,
        2 * pi - 2 * mouthAngle,
        true,
        paint,
      );
    }
  }

  void _drawTrail(Canvas canvas, List<Offset> positions) {
    const radius = 7.0;
    for (int i = positions.length - 1; i >= 0; i--) {
      final progress = 1.0 - (i / positions.length);
      final alpha = 0.05 + progress * 0.25;
      final paint = Paint()
        ..color = style.primaryColor.withOpacity(alpha)
        ..style = PaintingStyle.fill;
      // Light trail glow on tail segments
      if (i > positions.length ~/ 2) {
        final trailGlow = Paint()
          ..color = style.primaryColor.withOpacity(alpha * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(positions[i], radius + 4, trailGlow);
      }
      canvas.drawCircle(positions[i], radius * progress.clamp(0.3, 1.0), paint);
    }
  }

  void _drawDungeon(Canvas canvas, List<Offset> positions) {
    const segSize = 12.0;
    final paint = Paint()
      ..color = style.primaryColor.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = style.primaryColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < positions.length; i++) {
      final p = positions[i];
      final scale = 1.0 - (i / positions.length) * 0.3;
      final s = segSize * scale;
      final rect = Rect.fromCenter(center: p, width: s, height: s);
      // Slightly rounded for stone-like feel
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      canvas.drawRRect(rr, paint);
      canvas.drawRRect(rr, borderPaint);
    }
  }

  void _drawAscii(Canvas canvas, List<Offset> positions) {
    const chars = _SnakeAnimationState._asciiChars;
    for (int i = 0; i < positions.length; i++) {
      final charIndex = (i + (t * 4).toInt()) % chars.length;
      final alpha = 0.3 - (i / positions.length) * 0.15;
      final tp = TextPainter(
        text: TextSpan(
          text: chars[charIndex],
          style: TextStyle(
            color: style.primaryColor.withOpacity(alpha.clamp(0.05, 0.3)),
            fontSize: 16 - (i / positions.length) * 4,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        positions[i] - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePainter oldDelegate) => true;
}
