import 'package:flutter/material.dart';

/// Draws "NAGA" as thick snake-like tube letters matching the app icon style.
/// The first "N" has a snake head with eyes and forked tongue.
class NagaLogo extends StatelessWidget {
  final double height;
  const NagaLogo({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    // Extra top padding for snake head + tongue extending above letters
    final totalHeight = height * 1.25;
    return SizedBox(
      height: totalHeight,
      width: height * 3.6,
      child: CustomPaint(
        painter: _NagaLogoPainter(topPadding: totalHeight - height),
      ),
    );
  }
}

class _NagaLogoPainter extends CustomPainter {
  final double topPadding;
  _NagaLogoPainter({this.topPadding = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - topPadding;
    canvas.translate(0, topPadding);
    final letterW = h * 0.65;
    final gap = h * 0.15;
    final strokeW = h * 0.13;
    final totalW = letterW * 4 + gap * 3;
    final offsetX = (size.width - totalW) / 2;

    // Colors matching the app icon
    const mainGreen = Color(0xFF00E676);
    const darkGreen = Color(0xFF00C853);
    const highlightGreen = Color(0xFF69F0AE);
    const glowGreen = Color(0xFF00E676);

    // Glow paint
    final glowPaint = Paint()
      ..color = glowGreen.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Main stroke paint
    final mainPaint = Paint()
      ..color = mainGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Inner highlight paint
    final highlightPaint = Paint()
      ..color = highlightGreen.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 0.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Darker edge paint for depth
    final edgePaint = Paint()
      ..color = darkGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pad = strokeW * 0.7; // padding inside letter bounds

    // Draw each letter
    for (int i = 0; i < 4; i++) {
      final x = offsetX + i * (letterW + gap);
      final path = _letterPath(i, x, pad, letterW, h, strokeW);

      // Layer: glow -> edge -> main -> highlight
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, edgePaint);
      canvas.drawPath(path, mainPaint);
      canvas.drawPath(path, highlightPaint);
    }

    // Draw snake head on top of the "N" (end of the path = top of right stroke)
    final nX = offsetX;
    final nRight = nX + letterW - pad;
    final nTop = pad;
    _drawSnakeHead(canvas, nRight, nTop, strokeW, mainGreen);
  }

  Path _letterPath(int index, double x, double pad, double w, double h, double sw) {
    final path = Path();
    final top = pad;
    final bot = h - pad;
    final left = x + pad;
    final right = x + w - pad;

    switch (index) {
      case 0: // N
        path.moveTo(left, bot);
        path.lineTo(left, top);
        path.lineTo(right, bot);
        path.lineTo(right, top);
      case 1: // A
        final mid = (left + right) / 2;
        final crossY = top + (bot - top) * 0.55;
        path.moveTo(left, bot);
        path.lineTo(mid, top);
        path.lineTo(right, bot);
        // crossbar
        path.moveTo(left + (mid - left) * 0.55, crossY);
        path.lineTo(right - (right - mid) * 0.55, crossY);
      case 2: // G
        final midY = (top + bot) / 2;
        final midX = (left + right) / 2;
        // Arc: top-right → clockwise around
        path.moveTo(right, top + (bot - top) * 0.15);
        path.quadraticBezierTo(right, top, midX, top);
        path.quadraticBezierTo(left, top, left, midY);
        path.quadraticBezierTo(left, bot, midX, bot);
        path.quadraticBezierTo(right, bot, right, midY);
        path.lineTo(midX + (right - midX) * 0.2, midY);
      case 3: // A (same as index 1)
        final mid = (left + right) / 2;
        final crossY = top + (bot - top) * 0.55;
        path.moveTo(left, bot);
        path.lineTo(mid, top);
        path.lineTo(right, bot);
        path.moveTo(left + (mid - left) * 0.55, crossY);
        path.lineTo(right - (right - mid) * 0.55, crossY);
    }
    return path;
  }

  void _drawSnakeHead(Canvas canvas, double cx, double topY, double sw, Color color) {
    final headR = sw * 0.75;
    final headCy = topY - headR * 0.5;

    // Head — slightly elongated upward
    final headPaint = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headCy), width: headR * 2, height: headR * 2.3),
      headPaint,
    );

    // Eyes — larger, positioned looking up
    final eyeR = headR * 0.28;
    final pupilR = headR * 0.15;
    final eyeOffX = headR * 0.38;
    final eyeY = headCy - headR * 0.2;

    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;

    canvas.drawCircle(Offset(cx - eyeOffX, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(cx + eyeOffX, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(cx - eyeOffX, eyeY - pupilR * 0.4), pupilR, pupilPaint);
    canvas.drawCircle(Offset(cx + eyeOffX, eyeY - pupilR * 0.4), pupilR, pupilPaint);

    // Forked tongue — thicker and more visible
    final tongPaint = Paint()
      ..color = Colors.red.shade400
      ..strokeWidth = headR * 0.12
      ..strokeCap = StrokeCap.round;
    final tongBase = Offset(cx, headCy - headR * 1.1);
    final tongTip = Offset(cx, headCy - headR * 1.7);
    canvas.drawLine(tongBase, tongTip, tongPaint);
    final forkLen = headR * 0.4;
    canvas.drawLine(tongTip, Offset(cx - forkLen * 0.5, tongTip.dy - forkLen), tongPaint);
    canvas.drawLine(tongTip, Offset(cx + forkLen * 0.5, tongTip.dy - forkLen), tongPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
