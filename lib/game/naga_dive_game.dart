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
    // Gradient water layers
    for (int i = 0; i < 4; i++) {
      final t = i / 4.0;
      final color = Color.lerp(mode.backgroundColor, mode.deepWaterColor, t)!;
      final y = size.y * t;
      final h = size.y / 4 + 2;
      canvas.drawRect(Rect.fromLTWH(0, y, size.x, h), Paint()..color = color);
    }

    // Seaweed at bottom
    final seaweedPaint = Paint()..color = mode.seaweedColor.withOpacity(0.4);
    for (double x = 0; x < size.x; x += 30) {
      final waveOffset = sin(x * 0.1 + _scrollOffset * 0.01) * 15;
      final height = 20 + sin(x * 0.3) * 15;
      final path = Path()
        ..moveTo(x, size.y)
        ..quadraticBezierTo(x + waveOffset, size.y - height, x + 5, size.y - height - 5)
        ..quadraticBezierTo(x + 10 + waveOffset, size.y - height, x + 15, size.y)
        ..close();
      canvas.drawPath(path, seaweedPaint);
    }
  }

  void _renderBubbles(Canvas canvas) {
    final bubblePaint = Paint()
      ..color = mode.bubbleColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final bubbleFill = Paint()..color = mode.bubbleColor.withOpacity(0.08);

    for (final b in _bubbles) {
      canvas.drawCircle(Offset(b.x, b.y), b.radius, bubbleFill);
      canvas.drawCircle(Offset(b.x, b.y), b.radius, bubblePaint);
    }
  }

  void _renderColumns(Canvas canvas) {
    for (final col in _columns) {
      // Coral colors
      final baseColor = [
        mode.coralColor,
        const Color(0xFFD84315),
        const Color(0xFFAD1457),
      ][col.colorVariant];

      final coralPaint = Paint()..color = baseColor;
      final coralDark = Paint()..color = baseColor.withOpacity(0.7);

      // Top coral (hanging down from ceiling)
      final topRect = Rect.fromLTWH(col.x, 0, columnWidth, col.gapTop);
      canvas.drawRect(topRect, coralPaint);
      // Coral tip (rounded)
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(col.x + columnWidth / 2, col.gapTop),
          width: columnWidth + 8,
          height: 20,
        ),
        coralPaint,
      );
      // Texture lines
      for (double y = 10; y < col.gapTop; y += 15) {
        canvas.drawLine(
          Offset(col.x + 3, y),
          Offset(col.x + columnWidth - 3, y),
          coralDark,
        );
      }

      // Bottom coral (rising from floor)
      final bottomRect = Rect.fromLTWH(col.x, col.gapBottom, columnWidth, size.y - col.gapBottom);
      canvas.drawRect(bottomRect, coralPaint);
      // Coral tip
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(col.x + columnWidth / 2, col.gapBottom),
          width: columnWidth + 8,
          height: 20,
        ),
        coralPaint,
      );
      for (double y = col.gapBottom + 10; y < size.y; y += 15) {
        canvas.drawLine(
          Offset(col.x + 3, y),
          Offset(col.x + columnWidth - 3, y),
          coralDark,
        );
      }
    }
  }

  void _renderFish(Canvas canvas) {
    for (final fish in _fish) {
      final fishPaint = Paint()..color = mode.fishColor;
      // Simple fish shape
      final path = Path()
        ..moveTo(fish.x + 8, fish.y)
        ..lineTo(fish.x - 6, fish.y - 5)
        ..lineTo(fish.x - 6, fish.y + 5)
        ..close();
      canvas.drawPath(path, fishPaint);
      // Tail
      canvas.drawPath(
        Path()
          ..moveTo(fish.x - 6, fish.y)
          ..lineTo(fish.x - 12, fish.y - 4)
          ..lineTo(fish.x - 12, fish.y + 4)
          ..close(),
        fishPaint,
      );
      // Eye
      canvas.drawCircle(Offset(fish.x + 3, fish.y - 1.5), 1.5, Paint()..color = Colors.black);
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
