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
    setState(() {
      final dt = 1.0 / 60.0; // ~60fps
      _t += _speed * dt;
      _styleCycleTimer += dt;
      if (_styleCycleTimer >= _styleCycleDuration) {
        _styleCycleTimer = 0;
        _currentStyleIndex =
            (_currentStyleIndex + 1) % _snakeStyles.length;
      }
    });
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
      child: CustomPaint(
        painter: _SnakePainter(
          t: _t,
          segmentCount: _segmentCount,
          style: _snakeStyles[_currentStyleIndex],
          lissajousPosition: _lissajousPosition,
        ),
        size: Size.infinite,
      ),
    );
  }
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
