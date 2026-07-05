import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/naga_dive_mode.dart';
import 'snake_game.dart' show GameState;

/// Flappy Bird-style underwater swim — tap/press to rise, dodge coral columns.
class NagaDiveGame extends FlameGame with KeyboardEvents, TapCallbacks {
  final NagaDiveMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  // Snake position (vertical center of head)
  double snakeY = 0;
  double snakeVelocity = 0;
  static const double gravity = 600; // pixels/sec²
  static const double flapStrength = -220; // pixels/sec on flap
  static const double maxFallSpeed = 350;

  // Horizontal scroll
  double scrollSpeed = 120;
  double _scrollOffset = 0;

  // Columns (coral reefs)
  final List<_CoralColumn> _columns = [];
  double _columnTimer = 0;
  double _columnInterval = 2.2;
  static const double columnWidth = 50;
  double _gapHeight = 140;

  // Fish collectibles
  final List<_Fish> _fish = [];

  // Bubbles (decorative)
  final List<_Bubble> _bubbles = [];

  // Score
  int score = 0;
  GameState gameState = GameState.playing;
  bool _started = false; // wait for first tap

  // Snake body trail
  final List<Offset> _bodyTrail = [];
  static const int maxTrailLength = 12;

  final Random _random = Random();

  NagaDiveGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
  });

  @override
  Color backgroundColor() => mode.backgroundColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _startNewGame();
  }

  void _startNewGame() {
    snakeY = size.y * 0.4;
    snakeVelocity = 0;
    scrollSpeed = 120;
    _scrollOffset = 0;
    _columnTimer = 0;
    _columnInterval = 2.2;
    _gapHeight = 140;
    score = 0;
    gameState = GameState.playing;
    _started = false;
    _columns.clear();
    _fish.clear();
    _bubbles.clear();
    _bodyTrail.clear();
  }

  double get _snakeX => size.x * 0.25;
  double get _headRadius => 12.0;

  void _flap() {
    if (gameState != GameState.playing) return;
    if (!_started) _started = true;
    snakeVelocity = flapStrength;
  }

  @override
  void onTapDown(TapDownEvent event) {
    _flap();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;
    if (!_started) return;

    // Physics
    snakeVelocity += gravity * dt;
    snakeVelocity = snakeVelocity.clamp(-400, maxFallSpeed);
    snakeY += snakeVelocity * dt;

    // Floor/ceiling death
    if (snakeY < _headRadius || snakeY > size.y - _headRadius) {
      _die();
      return;
    }

    // Scroll
    _scrollOffset += scrollSpeed * dt;

    // Update body trail
    _bodyTrail.insert(0, Offset(_snakeX, snakeY));
    if (_bodyTrail.length > maxTrailLength) {
      _bodyTrail.removeLast();
    }

    // Spawn columns
    _columnTimer += dt;
    if (_columnTimer >= _columnInterval) {
      _columnTimer = 0;
      _spawnColumn();
    }

    // Move columns
    for (final col in _columns) {
      col.x -= scrollSpeed * dt;
    }

    // Score when passing a column
    for (final col in _columns) {
      if (!col.scored && col.x + columnWidth < _snakeX) {
        col.scored = true;
        score++;
        onScoreChanged(score);
      }
    }

    // Remove off-screen columns
    _columns.removeWhere((c) => c.x < -columnWidth - 10);

    // Move fish
    for (final fish in _fish) {
      fish.x -= scrollSpeed * dt;
      fish.y += sin(fish.phase + _scrollOffset * 0.02) * 0.5;
    }
    _fish.removeWhere((f) => f.x < -20);

    // Check fish collection
    _fish.removeWhere((f) {
      final dist = (Offset(f.x, f.y) - Offset(_snakeX, snakeY)).distance;
      if (dist < _headRadius + 10) {
        score += 3;
        onScoreChanged(score);
        return true;
      }
      return false;
    });

    // Collision with columns
    for (final col in _columns) {
      if (_snakeX + _headRadius > col.x && _snakeX - _headRadius < col.x + columnWidth) {
        // In column x-range — check gap
        if (snakeY - _headRadius < col.gapTop || snakeY + _headRadius > col.gapBottom) {
          _die();
          return;
        }
      }
    }

    // Spawn decorative bubbles
    if (_random.nextDouble() < 0.05) {
      _bubbles.add(_Bubble(
        x: _random.nextDouble() * size.x,
        y: size.y + 10,
        speed: 30 + _random.nextDouble() * 40,
        radius: 2 + _random.nextDouble() * 4,
      ));
    }
    for (final b in _bubbles) {
      b.y -= b.speed * dt;
      b.x += sin(b.y * 0.05) * 0.3;
    }
    _bubbles.removeWhere((b) => b.y < -10);

    // Difficulty ramp
    scrollSpeed = min(250, 120 + score * 2.0);
    _columnInterval = max(1.2, 2.2 - score * 0.03);
    _gapHeight = max(90, 140 - score * 1.5);
  }

  void _spawnColumn() {
    final minGapTop = 60.0;
    final maxGapTop = size.y - _gapHeight - 60;
    final gapTop = minGapTop + _random.nextDouble() * (maxGapTop - minGapTop);

    _columns.add(_CoralColumn(
      x: size.x + 10,
      gapTop: gapTop,
      gapBottom: gapTop + _gapHeight,
      colorVariant: _random.nextInt(3),
    ));

    // Maybe spawn fish in the gap
    if (_random.nextDouble() < 0.4) {
      _fish.add(_Fish(
        x: size.x + 10 + columnWidth / 2,
        y: gapTop + _gapHeight / 2 + (_random.nextDouble() - 0.5) * _gapHeight * 0.4,
        phase: _random.nextDouble() * pi * 2,
      ));
    }
  }

  void _die() {
    gameState = GameState.gameOver;
    onGameOver();
  }

  void togglePause() {
    if (gameState == GameState.playing) {
      gameState = GameState.paused;
    } else if (gameState == GameState.paused) {
      gameState = GameState.playing;
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        togglePause();
        return KeyEventResult.handled;
      }
      // Any key = flap (Space, Up, W, etc.)
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW) {
        _flap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _renderWaterBackground(canvas);
    _renderBubbles(canvas);
    _renderColumns(canvas);
    _renderFish(canvas);
    _renderSnake(canvas);
    _renderHUD(canvas);

    if (!_started) {
      _renderStartPrompt(canvas);
    }
  }

  void _renderWaterBackground(Canvas canvas) {
    // Gradient water layers — more bands for smoother gradient
    for (int i = 0; i < 8; i++) {
      final t = i / 8.0;
      final color = Color.lerp(mode.backgroundColor, mode.deepWaterColor, t)!;
      final y = size.y * t;
      final h = size.y / 8 + 2;
      canvas.drawRect(Rect.fromLTWH(0, y, size.x, h), Paint()..color = color);
    }

    // Light rays from surface
    final rayPaint = Paint()
      ..color = const Color(0xFF80D8FF).withOpacity(0.04);
    for (int i = 0; i < 5; i++) {
      final rx = (i * size.x / 4) + sin(_scrollOffset * 0.003 + i) * 30;
      final path = Path()
        ..moveTo(rx, 0)
        ..lineTo(rx + 40, 0)
        ..lineTo(rx + 80 + sin(i * 1.3) * 20, size.y * 0.6)
        ..lineTo(rx - 20 + sin(i * 1.3) * 20, size.y * 0.6)
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    // Sandy bottom
    final sandPaint = Paint()..color = const Color(0xFF3E2723).withOpacity(0.3);
    canvas.drawRect(Rect.fromLTWH(0, size.y - 15, size.x, 15), sandPaint);

    // Seaweed tufts at bottom — taller, more organic
    for (double x = 0; x < size.x; x += 18) {
      final sway = sin(x * 0.15 + _scrollOffset * 0.008) * 12;
      final h = 25 + sin(x * 0.4) * 20 + cos(x * 0.7) * 10;
      final brightness = 0.3 + sin(x * 0.5) * 0.15;
      final seaweedPaint = Paint()..color = mode.seaweedColor.withOpacity(brightness);

      // Each tuft is 2-3 curved blades
      for (final dx in [-3.0, 0.0, 3.0]) {
        final bladeSway = sway + dx * 0.8;
        final bladeH = h + dx.abs() * 2;
        final path = Path()
          ..moveTo(x + dx, size.y)
          ..quadraticBezierTo(
            x + dx + bladeSway, size.y - bladeH * 0.6,
            x + dx + bladeSway * 0.7, size.y - bladeH,
          )
          ..quadraticBezierTo(
            x + dx + bladeSway + 3, size.y - bladeH * 0.6,
            x + dx + 4, size.y,
          )
          ..close();
        canvas.drawPath(path, seaweedPaint);
      }
    }

    // Distant background particles (plankton)
    final planktonPaint = Paint()..color = Colors.white.withOpacity(0.06);
    for (int i = 0; i < 15; i++) {
      final px = (i * 73.0 + _scrollOffset * 0.15) % size.x;
      final py = (i * 47.0 + sin(i + _scrollOffset * 0.01) * 20) % size.y;
      canvas.drawCircle(Offset(px, py), 1.5, planktonPaint);
    }
  }

  void _renderBubbles(Canvas canvas) {
    for (final b in _bubbles) {
      // Outer ring
      final ringPaint = Paint()
        ..color = mode.bubbleColor.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(Offset(b.x, b.y), b.radius, ringPaint);

      // Fill with subtle gradient effect
      final fillPaint = Paint()..color = mode.bubbleColor.withOpacity(0.06);
      canvas.drawCircle(Offset(b.x, b.y), b.radius, fillPaint);

      // Specular highlight
      if (b.radius > 2.5) {
        final hlPaint = Paint()..color = Colors.white.withOpacity(0.2);
        canvas.drawCircle(
          Offset(b.x - b.radius * 0.25, b.y - b.radius * 0.3),
          b.radius * 0.3,
          hlPaint,
        );
      }
    }
  }

  void _renderColumns(Canvas canvas) {
    for (final col in _columns) {
      final cx = col.x + columnWidth / 2;
      final baseColors = [
        [const Color(0xFF2E7D32), const Color(0xFF1B5E20), const Color(0xFF4CAF50)], // kelp green
        [const Color(0xFFAD1457), const Color(0xFF880E4F), const Color(0xFFE91E63)], // pink coral
        [const Color(0xFFE65100), const Color(0xFFBF360C), const Color(0xFFFF9800)], // orange anemone
      ];
      final colors = baseColors[col.colorVariant];
      final mainPaint = Paint()..color = colors[0];
      final darkPaint = Paint()..color = colors[1];
      final lightPaint = Paint()..color = colors[2];

      // --- Top obstacle: hanging vines / stalactite coral ---
      _renderHangingPlant(canvas, cx, col.gapTop, col, mainPaint, darkPaint, lightPaint);

      // --- Bottom obstacle: rising kelp / reef ---
      _renderRisingPlant(canvas, cx, col.gapBottom, col, mainPaint, darkPaint, lightPaint);
    }
  }

  void _renderHangingPlant(Canvas canvas, double cx, double gapTop,
      _CoralColumn col, Paint mainPaint, Paint darkPaint, Paint lightPaint) {
    final hw = columnWidth / 2;

    if (col.colorVariant == 0) {
      // Kelp vines hanging down — multiple wavy strands
      for (final ox in [-hw * 0.6, -hw * 0.1, hw * 0.3, hw * 0.7]) {
        final strandX = cx + ox;
        final sway = sin(strandX * 0.1 + _scrollOffset * 0.006) * 6;
        final path = Path()..moveTo(strandX, 0);
        // Wavy bezier down to gap
        final segments = 4;
        for (int i = 0; i < segments; i++) {
          final t0 = i / segments;
          final t1 = (i + 1) / segments;
          final y0 = gapTop * t0;
          final y1 = gapTop * t1;
          final swayDir = i.isEven ? 1.0 : -1.0;
          path.quadraticBezierTo(
            strandX + sway * swayDir + sin(i * 2.0) * 4, (y0 + y1) / 2,
            strandX + sin(i * 1.5) * 2, y1,
          );
        }
        // Return path to form filled shape
        path.lineTo(strandX + 5, gapTop);
        for (int i = segments - 1; i >= 0; i--) {
          final t0 = i / segments;
          final y0 = gapTop * t0;
          path.lineTo(strandX + 5 + sin(i * 1.2) * 2, y0);
        }
        path.close();
        canvas.drawPath(path, mainPaint);
      }
      // Leaf blobs at vine tips
      for (final ox in [-hw * 0.4, hw * 0.1, hw * 0.5]) {
        final leafX = cx + ox + sin(ox + _scrollOffset * 0.005) * 4;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(leafX, gapTop - 4), width: 14, height: 10),
          lightPaint,
        );
      }
    } else {
      // Coral / rock formation — organic blobby shape
      final path = Path()..moveTo(cx - hw - 4, 0);
      path.lineTo(cx + hw + 4, 0);
      // Irregular bottom edge with bumps
      final steps = 8;
      for (int i = steps; i >= 0; i--) {
        final t = i / steps;
        final x = cx + hw + 4 - (hw * 2 + 8) * (1 - t);
        final bump = sin(t * 7 + col.x * 0.1) * 8 + cos(t * 4) * 5;
        path.lineTo(x, gapTop + bump);
      }
      path.close();
      canvas.drawPath(path, mainPaint);

      // Texture: small barnacles / polyps
      for (double y = 15; y < gapTop - 10; y += 18) {
        for (final dx in [-hw * 0.4, 0.0, hw * 0.4]) {
          final bx = cx + dx + sin(y * 0.3 + dx) * 3;
          final bSize = 3.0 + sin(y * 0.5 + dx * 0.7) * 1.5;
          canvas.drawCircle(Offset(bx, y), bSize, darkPaint);
          canvas.drawCircle(Offset(bx, y), bSize * 0.5, lightPaint);
        }
      }
    }
  }

  void _renderRisingPlant(Canvas canvas, double cx, double gapBottom,
      _CoralColumn col, Paint mainPaint, Paint darkPaint, Paint lightPaint) {
    final hw = columnWidth / 2;

    if (col.colorVariant == 0) {
      // Tall kelp stalks rising from bottom
      for (final ox in [-hw * 0.5, 0.0, hw * 0.5]) {
        final stalkX = cx + ox;
        final sway = sin(stalkX * 0.12 + _scrollOffset * 0.007) * 8;
        final stalkH = size.y - gapBottom;

        final path = Path()..moveTo(stalkX - 3, size.y);
        final segments = 5;
        for (int i = 0; i <= segments; i++) {
          final t = i / segments;
          final y = size.y - stalkH * t;
          final swayAmt = sway * t;
          path.lineTo(stalkX - 3 + swayAmt + sin(i * 1.8) * 3, y);
        }
        for (int i = segments; i >= 0; i--) {
          final t = i / segments;
          final y = size.y - stalkH * t;
          final swayAmt = sway * t;
          path.lineTo(stalkX + 3 + swayAmt + sin(i * 1.8) * 3, y);
        }
        path.close();
        canvas.drawPath(path, mainPaint);

        // Leaves along the stalk
        for (int i = 1; i < segments; i++) {
          final t = i / segments;
          final ly = size.y - stalkH * t;
          final lx = stalkX + sway * t;
          final side = i.isEven ? 1.0 : -1.0;
          final leafPath = Path()
            ..moveTo(lx, ly)
            ..quadraticBezierTo(
              lx + side * 15, ly - 5,
              lx + side * 12, ly - 12,
            )
            ..quadraticBezierTo(
              lx + side * 6, ly - 4,
              lx, ly,
            );
          canvas.drawPath(leafPath, lightPaint);
        }
      }
    } else if (col.colorVariant == 1) {
      // Sea anemone — bulbous base with tentacle tips
      final aneH = size.y - gapBottom;
      // Bulbous body
      final bodyPath = Path()
        ..moveTo(cx - hw - 6, size.y)
        ..lineTo(cx - hw - 6, gapBottom + aneH * 0.3)
        ..quadraticBezierTo(cx - hw, gapBottom - 5, cx, gapBottom + 5)
        ..quadraticBezierTo(cx + hw, gapBottom - 5, cx + hw + 6, gapBottom + aneH * 0.3)
        ..lineTo(cx + hw + 6, size.y)
        ..close();
      canvas.drawPath(bodyPath, mainPaint);

      // Tentacles at the top
      for (double t = -1.0; t <= 1.0; t += 0.25) {
        final tx = cx + t * hw;
        final sway = sin(tx * 0.2 + _scrollOffset * 0.01) * 6;
        final tipPath = Path()
          ..moveTo(tx, gapBottom + 8)
          ..quadraticBezierTo(tx + sway, gapBottom - 8, tx + sway * 0.5, gapBottom - 2);
        canvas.drawPath(tipPath, Paint()
          ..color = lightPaint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
      }
    } else {
      // Coral reef mound — irregular organic shape
      final reefPath = Path()..moveTo(cx - hw - 8, size.y);
      // Build up irregular top edge
      final steps = 10;
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final x = (cx - hw - 8) + (hw * 2 + 16) * t;
        final bump = sin(t * 9 + col.x * 0.15) * 10 + cos(t * 5) * 6;
        reefPath.lineTo(x, gapBottom - bump);
      }
      reefPath.lineTo(cx + hw + 8, size.y);
      reefPath.close();
      canvas.drawPath(reefPath, mainPaint);

      // Coral branches on top
      for (double t = 0.15; t < 0.85; t += 0.2) {
        final bx = (cx - hw) + (hw * 2) * t;
        final by = gapBottom - sin(t * 9 + col.x * 0.15) * 10;
        final branchH = 12 + sin(t * 7) * 6;
        final branchSway = sin(bx * 0.1 + _scrollOffset * 0.005) * 3;
        final branchPath = Path()
          ..moveTo(bx - 2, by)
          ..quadraticBezierTo(bx + branchSway, by - branchH * 0.6, bx + branchSway, by - branchH)
          ..quadraticBezierTo(bx + branchSway + 4, by - branchH * 0.6, bx + 3, by)
          ..close();
        canvas.drawPath(branchPath, lightPaint);
      }

      // Polyp dots
      for (double t = 0.1; t < 0.9; t += 0.15) {
        final px = (cx - hw) + (hw * 2) * t;
        final py = gapBottom + 15 + sin(t * 11) * 8;
        canvas.drawCircle(Offset(px, py), 2.5, darkPaint);
        canvas.drawCircle(Offset(px, py), 1.2, lightPaint);
      }
    }
  }

  void _renderFish(Canvas canvas) {
    for (final fish in _fish) {
      final tailWag = sin(_scrollOffset * 0.08 + fish.phase) * 3;

      // Glow
      final glowPaint = Paint()
        ..color = mode.fishColor.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(fish.x, fish.y), 12, glowPaint);

      // Body — oval
      final bodyPaint = Paint()..color = mode.fishColor;
      final bodyPath = Path()
        ..moveTo(fish.x + 10, fish.y)
        ..quadraticBezierTo(fish.x + 6, fish.y - 6, fish.x - 3, fish.y - 5)
        ..quadraticBezierTo(fish.x - 8, fish.y - 3, fish.x - 7, fish.y)
        ..quadraticBezierTo(fish.x - 8, fish.y + 3, fish.x - 3, fish.y + 5)
        ..quadraticBezierTo(fish.x + 6, fish.y + 6, fish.x + 10, fish.y)
        ..close();
      canvas.drawPath(bodyPath, bodyPaint);

      // Tail fin
      final tailPaint = Paint()..color = mode.fishColor.withOpacity(0.8);
      final tailPath = Path()
        ..moveTo(fish.x - 7, fish.y)
        ..lineTo(fish.x - 14 + tailWag, fish.y - 5)
        ..quadraticBezierTo(fish.x - 12 + tailWag, fish.y, fish.x - 14 + tailWag, fish.y + 5)
        ..close();
      canvas.drawPath(tailPath, tailPaint);

      // Dorsal fin
      final dorsalPath = Path()
        ..moveTo(fish.x + 2, fish.y - 5)
        ..quadraticBezierTo(fish.x - 1, fish.y - 9, fish.x - 4, fish.y - 5);
      canvas.drawPath(dorsalPath, tailPaint);

      // Belly stripe
      final stripePaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(fish.x + 6, fish.y + 1), Offset(fish.x - 4, fish.y + 2), stripePaint);

      // Eye
      canvas.drawCircle(Offset(fish.x + 5, fish.y - 1.5), 2, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(fish.x + 5.5, fish.y - 1.5), 1, Paint()..color = Colors.black);
    }
  }

  void _renderSnake(Canvas canvas) {
    // Body trail — gets thinner toward tail
    for (int i = _bodyTrail.length - 1; i >= 1; i--) {
      final t = 1.0 - (i / maxTrailLength);
      final radius = _headRadius * 0.8 * t;
      if (radius < 1) continue;

      final pos = _bodyTrail[i];
      // Offset each segment slightly behind
      final drawX = pos.dx - i * 3.5;

      final bodyPaint = Paint()
        ..color = mode.snakeColor.withOpacity(0.3 + 0.5 * t);
      canvas.drawCircle(Offset(drawX, pos.dy), radius, bodyPaint);

      // Lighter belly
      final bellyPaint = Paint()
        ..color = Colors.white.withOpacity(0.1 * t);
      canvas.drawCircle(Offset(drawX, pos.dy + radius * 0.3), radius * 0.5, bellyPaint);
    }

    // Head
    final headPaint = Paint()..color = mode.snakeColor;
    final headGlow = Paint()
      ..color = mode.snakeColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(Offset(_snakeX, snakeY), _headRadius + 4, headGlow);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(_snakeX + 2, snakeY),
        width: _headRadius * 2.4,
        height: _headRadius * 2,
      ),
      headPaint,
    );

    // Eyes
    final angle = atan2(snakeVelocity, scrollSpeed) * 0.3; // slight eye tilt
    final eyeY = snakeY - _headRadius * 0.2 + sin(angle) * 2;
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(_snakeX + _headRadius * 0.3, eyeY - _headRadius * 0.15), _headRadius * 0.3, eyePaint);
    canvas.drawCircle(Offset(_snakeX + _headRadius * 0.3, eyeY + _headRadius * 0.15), _headRadius * 0.3, eyePaint);
    canvas.drawCircle(Offset(_snakeX + _headRadius * 0.35, eyeY - _headRadius * 0.15), _headRadius * 0.15, pupilPaint);
    canvas.drawCircle(Offset(_snakeX + _headRadius * 0.35, eyeY + _headRadius * 0.15), _headRadius * 0.15, pupilPaint);

    // Tongue (when diving)
    if (snakeVelocity > 50) {
      final tongPaint = Paint()
        ..color = Colors.red.shade400
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final tongX = _snakeX + _headRadius * 1.2;
      canvas.drawLine(Offset(tongX, snakeY), Offset(tongX + 6, snakeY), tongPaint);
      canvas.drawLine(Offset(tongX + 6, snakeY), Offset(tongX + 9, snakeY - 3), tongPaint);
      canvas.drawLine(Offset(tongX + 6, snakeY), Offset(tongX + 9, snakeY + 3), tongPaint);
    }
  }

  void _renderHUD(Canvas canvas) {
    // Score — large, centered at top
    final scoreTp = TextPainter(
      text: TextSpan(
        text: '$score',
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scoreTp.paint(
      canvas,
      Offset((size.x - scoreTp.width) / 2, 20),
    );
  }

  void _renderStartPrompt(Canvas canvas) {
    final promptTp = TextPainter(
      text: TextSpan(
        text: 'TAP or SPACE to swim',
        style: TextStyle(
          color: mode.snakeColor.withOpacity(0.7),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    promptTp.paint(
      canvas,
      Offset((size.x - promptTp.width) / 2, size.y * 0.55),
    );
  }
}

class _CoralColumn {
  double x;
  final double gapTop;
  final double gapBottom;
  final int colorVariant;
  bool scored = false;

  _CoralColumn({
    required this.x,
    required this.gapTop,
    required this.gapBottom,
    required this.colorVariant,
  });
}

class _Fish {
  double x;
  double y;
  final double phase;
  _Fish({required this.x, required this.y, required this.phase});
}

class _Bubble {
  double x;
  double y;
  final double speed;
  final double radius;
  _Bubble({required this.x, required this.y, required this.speed, required this.radius});
}
