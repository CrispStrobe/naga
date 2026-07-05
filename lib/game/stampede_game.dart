import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/stampede_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Top-down animal race — snake races up a scrolling track, dodges obstacles,
/// collects boosts, and competes against AI animals.
class StampedeGame extends FlameGame with KeyboardEvents {
  final StampedeMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  static const int laneCount = 5;
  static const double trackWidth = 0.55; // fraction of screen width — narrower for smaller sprites

  late double laneWidth;
  late double trackLeft;
  late double trackRight;

  // Player snake
  int currentLane = 2; // middle lane (0-4)
  double playerY = 0;
  GameState gameState = GameState.playing;
  int score = 0;

  // Scrolling
  double _scrollSpeed = 200; // pixels per second
  double _scrollOffset = 0;
  double _distanceTraveled = 0;
  double _scoreTimer = 0;

  // Obstacles and collectibles
  final List<_TrackObject> _objects = [];
  double _spawnTimer = 0;
  double _spawnInterval = 0.8;

  // AI racers
  final List<_Racer> _racers = [];
  double _racerSpawnTimer = 0;

  // Lane dash marks
  static const double _dashLength = 30;
  static const double _dashGap = 20;

  final Random _random = Random();

  // Static jungle scenery on both sides of the track — rendered once into a
  // cached picture (fixed-seed Random, same idiom as GridBoard._renderFoliage)
  // so nothing re-randomizes or scrolls per frame.
  ui.Picture? _sidesPicture;
  Size _sidesPictureSize = Size.zero;
  final List<_SwayFrond> _swayFronds = [];
  double _elapsed = 0;

  StampedeGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
  });

  @override
  Color backgroundColor() => mode.grassColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _calculateLayout();
    _startNewGame();
  }

  void _calculateLayout() {
    final tw = size.x * trackWidth;
    trackLeft = (size.x - tw) / 2;
    trackRight = trackLeft + tw;
    laneWidth = tw / laneCount;
    playerY = size.y * 0.82;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _calculateLayout();
      _sidesPicture?.dispose();
      _sidesPicture = null;
    }
  }

  @override
  void onRemove() {
    _sidesPicture?.dispose();
    _sidesPicture = null;
    super.onRemove();
  }

  void _startNewGame() {
    score = 0;
    currentLane = 2;
    gameState = GameState.playing;
    _scrollSpeed = 140;
    _scrollOffset = 0;
    _distanceTraveled = 0;
    _spawnTimer = 0;
    _spawnInterval = 1.4;
    _objects.clear();
    _racers.clear();
    _racerSpawnTimer = 0;
    _scoreTimer = 0;

    // Start with just 1 racer, more spawn as difficulty increases
    _spawnRacer(initialSpawn: true);
  }

  double _laneCenter(int lane) {
    return trackLeft + lane * laneWidth + laneWidth / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt; // drives the slow foliage sway (independent of game state)
    if (gameState != GameState.playing) return;

    // Scroll
    _scrollOffset += _scrollSpeed * dt;
    _distanceTraveled += _scrollSpeed * dt;

    // Score: 1 point per ~50 pixels traveled
    _scoreTimer += _scrollSpeed * dt;
    if (_scoreTimer >= 50) {
      score += (_scoreTimer ~/ 50);
      _scoreTimer = _scoreTimer % 50;
      onScoreChanged(score);
    }

    // Difficulty ramp based on distance
    final difficulty = (_distanceTraveled / 5000).clamp(0.0, 1.0); // 0→1 over ~5000px
    _scrollSpeed = 140 + difficulty * 360; // 140→500
    _spawnInterval = 1.4 - difficulty * 0.9; // 1.4→0.5

    // Spawn obstacles
    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _spawnObject();
    }

    // Spawn AI racers — more as difficulty increases
    final maxRacers = 1 + (difficulty * 5).toInt(); // 1→6
    _racerSpawnTimer += dt;
    if (_racerSpawnTimer >= (4.0 - difficulty * 2.0) && _racers.length < maxRacers) {
      _racerSpawnTimer = 0;
      _spawnRacer();
    }

    // Move objects down
    for (final obj in _objects) {
      obj.y += _scrollSpeed * dt;
    }
    _objects.removeWhere((o) => o.y > size.y + 50);

    // Move AI racers
    _updateRacers(dt);

    // Check collisions
    _checkCollisions();
  }

  void _spawnObject() {
    final lane = _random.nextInt(laneCount);
    final isBoost = _random.nextDouble() < 0.2;
    _objects.add(_TrackObject(
      lane: lane,
      y: -40,
      type: isBoost ? _ObjectType.boost : _ObjectType.rock,
    ));
  }

  void _spawnRacer({bool initialSpawn = false}) {
    final lane = _random.nextInt(laneCount);
    final animalType = _AnimalType.values[_random.nextInt(_AnimalType.values.length)];
    _racers.add(_Racer(
      lane: lane,
      y: initialSpawn
          ? _random.nextDouble() * size.y * 0.4
          : -60,
      speed: 0.5 + _random.nextDouble() * 0.4, // relative to scroll speed
      animal: animalType,
      changeLaneTimer: 99, // initialized in _updateRacers based on difficulty
    ));
  }

  void _updateRacers(double dt) {
    final difficulty = (_distanceTraveled / 5000).clamp(0.0, 1.0);

    for (final racer in _racers) {
      // Racers move slower than scroll, so they drift down relative to screen
      final relativeSpeed = _scrollSpeed * (1.0 - racer.speed);
      racer.y += relativeSpeed * dt;

      // Lane changes only after difficulty > 0.3 (~1500px traveled)
      // Frequency increases with difficulty
      if (difficulty > 0.3) {
        racer.changeLaneTimer -= dt;
        if (racer.changeLaneTimer <= 0) {
          // Higher difficulty = more frequent lane changes
          racer.changeLaneTimer = 5.0 - difficulty * 3.0 + _random.nextDouble() * 2.0;
          final dir = _random.nextBool() ? 1 : -1;
          racer.lane = (racer.lane + dir).clamp(0, laneCount - 1);
        }
      }
    }
    _racers.removeWhere((r) => r.y > size.y + 80);
  }

  void _checkCollisions() {
    final playerCx = _laneCenter(currentLane);
    final playerRect = Rect.fromCenter(
      center: Offset(playerCx, playerY),
      width: laneWidth * 0.35,
      height: laneWidth * 0.6,
    );

    // Object collisions
    for (final obj in _objects.toList()) {
      final objCx = _laneCenter(obj.lane);
      final objRect = Rect.fromCenter(
        center: Offset(objCx, obj.y),
        width: laneWidth * 0.3,
        height: laneWidth * 0.3,
      );

      if (playerRect.overlaps(objRect)) {
        if (obj.type == _ObjectType.boost) {
          score += 25;
          onScoreChanged(score);
          _objects.remove(obj);
        } else {
          _die();
          return;
        }
      }
    }

    // Racer collisions
    for (final racer in _racers) {
      final racerCx = _laneCenter(racer.lane);
      final racerRect = Rect.fromCenter(
        center: Offset(racerCx, racer.y),
        width: laneWidth * 0.3,
        height: laneWidth * 0.5,
      );

      if (playerRect.overlaps(racerRect)) {
        _die();
        return;
      }
    }
  }

  void _die() {
    gameState = GameState.gameOver;
    onGameOver();
  }

  void changeDirection(Direction dir) {
    if (gameState != GameState.playing) return;
    if (dir == Direction.left && currentLane > 0) {
      currentLane--;
    } else if (dir == Direction.right && currentLane < laneCount - 1) {
      currentLane++;
    }
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
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        changeDirection(Direction.left);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        changeDirection(Direction.right);
        return KeyEventResult.handled;
      }
      // Up/down — no effect but handle to prevent default
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW ||
          event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.keyS) {
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _renderTrack(canvas);
    _renderObjects(canvas);
    _renderRacers(canvas);
    _renderPlayer(canvas);
    _renderHUD(canvas);
  }

  void _renderTrack(Canvas canvas) {
    // Jungle scenery on both sides (static, cached picture + gentle sway)
    _renderSides(canvas);

    // Track surface
    final trackPaint = Paint()..color = mode.trackColor;
    canvas.drawRect(
      Rect.fromLTRB(trackLeft, 0, trackRight, size.y),
      trackPaint,
    );

    // Lane dashes
    final dashPaint = Paint()
      ..color = mode.trackLineColor.withOpacity(0.4)
      ..strokeWidth = 2;
    for (int i = 1; i < laneCount; i++) {
      final x = trackLeft + i * laneWidth;
      final offset = _scrollOffset % (_dashLength + _dashGap);
      var y = -offset;
      while (y < size.y) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + _dashLength),
          dashPaint,
        );
        y += _dashLength + _dashGap;
      }
    }

    // Track borders
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(trackLeft, 0), Offset(trackLeft, size.y), borderPaint);
    canvas.drawLine(Offset(trackRight, 0), Offset(trackRight, size.y), borderPaint);
  }

  void _renderSides(Canvas canvas) {
    final currentSize = Size(size.x, size.y);
    if (_sidesPicture == null || _sidesPictureSize != currentSize) {
      _buildSidesPicture();
    }
    canvas.drawPicture(_sidesPicture!);

    // Gentle sway on a few fronds — deterministic positions, only the angle
    // moves (slow sine), so it reads as a breeze rather than flicker.
    final frondPaint = Paint()..color = const Color(0xFF2E7D32);
    final ribPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final f in _swayFronds) {
      final angle = f.baseAngle + sin(_elapsed * 0.5 + f.phase) * 0.04;
      canvas.save();
      canvas.clipRect(f.clipRect);
      canvas.translate(f.x, f.y);
      canvas.rotate(angle);
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(f.length * 0.5, -f.length * 0.18, f.length, 0)
        ..quadraticBezierTo(f.length * 0.5, f.length * 0.18, 0, 0)
        ..close();
      canvas.drawPath(leaf, frondPaint);
      canvas.drawLine(Offset.zero, Offset(f.length * 0.9, 0), ribPaint);
      canvas.restore();
    }
  }

  /// Builds the static side scenery once: layered jungle bands, bushes,
  /// scattered leaves, small flowers and palm-frond fans. Fixed-seed Random
  /// so the pattern is identical every rebuild (no flicker).
  void _buildSidesPicture() {
    _sidesPictureSize = Size(size.x, size.y);
    _sidesPicture?.dispose();
    _swayFronds.clear();

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final rng = Random(4242);

    _paintSide(c, rng, Rect.fromLTRB(0, 0, trackLeft, size.y), trackOnRight: true);
    _paintSide(c, rng, Rect.fromLTRB(trackRight, 0, size.x, size.y), trackOnRight: false);

    _sidesPicture = recorder.endRecording();
  }

  void _paintSide(Canvas canvas, Random rng, Rect r, {required bool trackOnRight}) {
    if (r.width <= 0) return;
    canvas.save();
    canvas.clipRect(r);

    final outerX = trackOnRight ? r.left : r.right; // screen edge
    final innerX = trackOnRight ? r.right : r.left; // track edge
    final w = r.width;

    // Base: deep jungle shade at the screen edge, brightening toward the
    // track — keeps the sides clearly darker than the sunlit track verge.
    final basePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(outerX, 0),
        Offset(innerX, 0),
        const [Color(0xFF1B5E20), Color(0xFF2E7D32)],
      );
    canvas.drawRect(r, basePaint);

    // Sunlit grass verge right next to the track border
    final vergeW = (w * 0.10).clamp(4.0, 10.0);
    final vergeRect = trackOnRight
        ? Rect.fromLTRB(r.right - vergeW, r.top, r.right, r.bottom)
        : Rect.fromLTRB(r.left, r.top, r.left + vergeW, r.bottom);
    canvas.drawRect(vergeRect, Paint()..color = const Color(0xFF43A047));

    // Dense canopy blobs hugging the screen edge
    final canopyDark = Paint()..color = const Color(0xFF14481A);
    final canopyMid = Paint()..color = const Color(0xFF1B5E20);
    double y = -20;
    while (y < r.bottom + 20) {
      final radius = w * (0.18 + rng.nextDouble() * 0.14);
      final cx = outerX + (trackOnRight ? 1 : -1) * rng.nextDouble() * w * 0.25;
      canvas.drawCircle(Offset(cx, y), radius, rng.nextBool() ? canopyDark : canopyMid);
      y += radius * (0.9 + rng.nextDouble() * 0.8);
    }

    // Bushes in the mid band: clusters of overlapping circles
    final bushDark = Paint()..color = const Color(0xFF256029);
    final bushLight = Paint()..color = const Color(0xFF388E3C);
    final bushCount = (r.height / 110).ceil();
    for (int i = 0; i < bushCount; i++) {
      final bx = outerX + (trackOnRight ? 1 : -1) * w * (0.35 + rng.nextDouble() * 0.4);
      final by = rng.nextDouble() * r.height;
      final br = w * (0.07 + rng.nextDouble() * 0.06);
      canvas.drawCircle(Offset(bx - br * 0.7, by + br * 0.2), br * 0.9, bushDark);
      canvas.drawCircle(Offset(bx + br * 0.7, by + br * 0.2), br * 0.9, bushDark);
      canvas.drawCircle(Offset(bx, by - br * 0.3), br, bushLight);
    }

    // Scattered leaves (same idiom as GridBoard._renderFoliage)
    final leafLight = Paint()..color = const Color(0xFF3B8A3F);
    final leafDark = Paint()..color = const Color(0xFF1E5423);
    final leafCount = (r.height * w / 5500).round();
    for (int i = 0; i < leafCount; i++) {
      final lx = r.left + rng.nextDouble() * w;
      final ly = rng.nextDouble() * r.height;
      final angle = rng.nextDouble() * 2 * pi;
      final len = w * (0.10 + rng.nextDouble() * 0.14);
      canvas.save();
      canvas.translate(lx, ly);
      canvas.rotate(angle);
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -len * 0.22, len, 0)
        ..quadraticBezierTo(len * 0.5, len * 0.22, 0, 0)
        ..close();
      canvas.drawPath(leaf, rng.nextBool() ? leafLight : leafDark);
      canvas.restore();
    }

    // Palm-frond fans anchored at the screen edge, fanning toward the track
    final frondPaint = Paint()..color = const Color(0xFF2E7D32);
    final fanCount = (r.height / 220).ceil();
    for (int i = 0; i < fanCount; i++) {
      final fy = (i + 0.5) * r.height / fanCount + (rng.nextDouble() - 0.5) * 40;
      final baseAngle = trackOnRight ? 0.0 : pi;
      for (int leafI = -2; leafI <= 2; leafI++) {
        final angle = baseAngle + leafI * 0.35 + (rng.nextDouble() - 0.5) * 0.1;
        final len = w * (0.45 + rng.nextDouble() * 0.2);
        canvas.save();
        canvas.translate(outerX, fy);
        canvas.rotate(angle);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(len * 0.5, -len * 0.14, len, 0)
          ..quadraticBezierTo(len * 0.5, len * 0.14, 0, 0)
          ..close();
        canvas.drawPath(leaf, frondPaint);
        canvas.restore();
      }
    }

    // Small tropical flowers: 5 petals + bright center (alpha baked into
    // the const colors — ~0.85 opacity)
    const petalColors = [Color(0xD9FF80AB), Color(0xD9FFD740), Color(0xD9E040FB)];
    final flowerCount = (r.height / 130).ceil();
    for (int i = 0; i < flowerCount; i++) {
      final fx = outerX + (trackOnRight ? 1 : -1) * w * (0.4 + rng.nextDouble() * 0.45);
      final fy = rng.nextDouble() * r.height;
      final pr = 1.6 + rng.nextDouble() * 1.4;
      final petalPaint = Paint()
        ..color = petalColors[rng.nextInt(petalColors.length)];
      for (int p = 0; p < 5; p++) {
        final a = p * 2 * pi / 5;
        canvas.drawCircle(Offset(fx + cos(a) * pr * 1.4, fy + sin(a) * pr * 1.4), pr, petalPaint);
      }
      canvas.drawCircle(Offset(fx, fy), pr * 0.8, Paint()..color = const Color(0xFFFFF59D));
    }

    canvas.restore();

    // Register a few fronds for the slow live sway (drawn every frame with a
    // sine-animated angle — positions fixed, never re-randomized)
    final swayCount = (r.height / 260).ceil().clamp(2, 4);
    for (int i = 0; i < swayCount; i++) {
      _swayFronds.add(_SwayFrond(
        x: outerX,
        y: (i + 0.5) * r.height / swayCount + (rng.nextDouble() - 0.5) * 60,
        baseAngle: (trackOnRight ? 0.0 : pi) + (rng.nextDouble() - 0.5) * 0.5,
        length: w * (0.55 + rng.nextDouble() * 0.2),
        phase: rng.nextDouble() * 2 * pi,
        clipRect: r,
      ));
    }
  }

  void _renderObjects(Canvas canvas) {
    for (final obj in _objects) {
      final cx = _laneCenter(obj.lane);
      final halfW = laneWidth * 0.18;

      if (obj.type == _ObjectType.rock) {
        // Rock: gray irregular shape
        final rockPaint = Paint()..color = mode.rockColor;
        final path = Path()
          ..moveTo(cx - halfW, obj.y + halfW * 0.5)
          ..lineTo(cx - halfW * 0.6, obj.y - halfW * 0.8)
          ..lineTo(cx + halfW * 0.3, obj.y - halfW)
          ..lineTo(cx + halfW, obj.y - halfW * 0.3)
          ..lineTo(cx + halfW * 0.8, obj.y + halfW * 0.7)
          ..close();
        canvas.drawPath(path, rockPaint);
        // Highlight
        final hlPaint = Paint()..color = Colors.white.withOpacity(0.15);
        canvas.drawCircle(Offset(cx - halfW * 0.2, obj.y - halfW * 0.3), halfW * 0.2, hlPaint);
      } else {
        // Boost: golden star
        final boostPaint = Paint()..color = mode.foodColor;
        final glowPaint = Paint()..color = mode.foodColor.withOpacity(0.3);
        canvas.drawCircle(Offset(cx, obj.y), halfW * 1.2, glowPaint);
        _drawStar(canvas, cx, obj.y, halfW * 0.8, 5, boostPaint);
      }
    }
  }

  void _drawStar(Canvas canvas, double cx, double cy, double r, int points, Paint paint) {
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * pi / points) - pi / 2;
      final radius = i.isEven ? r : r * 0.45;
      final x = cx + radius * cos(angle);
      final y = cy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _renderRacers(Canvas canvas) {
    for (final racer in _racers) {
      final cx = _laneCenter(racer.lane);
      final hw = laneWidth * 0.2;
      final hh = laneWidth * 0.3;

      switch (racer.animal) {
        case _AnimalType.frog:
          _drawFrog(canvas, cx, racer.y, hw, hh);
        case _AnimalType.lizard:
          _drawLizard(canvas, cx, racer.y, hw, hh);
        case _AnimalType.beetle:
          _drawBeetle(canvas, cx, racer.y, hw, hh);
        case _AnimalType.turtle:
          _drawTurtle(canvas, cx, racer.y, hw, hh);
      }
    }
  }

  void _drawFrog(Canvas canvas, double cx, double cy, double hw, double hh) {
    final bodyPaint = Paint()..color = const Color(0xFF4CAF50);
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;

    // Body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: hw * 2, height: hh * 2),
      bodyPaint,
    );
    // Back legs
    final legPaint = Paint()..color = const Color(0xFF388E3C);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - hw * 0.8, cy + hh * 0.6), width: hw * 0.8, height: hh * 0.6),
      legPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + hw * 0.8, cy + hh * 0.6), width: hw * 0.8, height: hh * 0.6),
      legPaint,
    );
    // Eyes (big, on top)
    canvas.drawCircle(Offset(cx - hw * 0.4, cy - hh * 0.5), hw * 0.3, eyePaint);
    canvas.drawCircle(Offset(cx + hw * 0.4, cy - hh * 0.5), hw * 0.3, eyePaint);
    canvas.drawCircle(Offset(cx - hw * 0.4, cy - hh * 0.5), hw * 0.15, pupilPaint);
    canvas.drawCircle(Offset(cx + hw * 0.4, cy - hh * 0.5), hw * 0.15, pupilPaint);
  }

  void _drawLizard(Canvas canvas, double cx, double cy, double hw, double hh) {
    final bodyPaint = Paint()..color = const Color(0xFFFF9800);
    final eyePaint = Paint()..color = Colors.yellow;
    final pupilPaint = Paint()..color = Colors.black;

    // Tail
    final tailPaint = Paint()
      ..color = const Color(0xFFE65100)
      ..strokeWidth = hw * 0.25
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tailPath = Path()
      ..moveTo(cx, cy + hh * 0.7)
      ..quadraticBezierTo(cx + hw * 0.5, cy + hh * 1.3, cx - hw * 0.3, cy + hh * 1.5);
    canvas.drawPath(tailPath, tailPaint);

    // Body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: hw * 1.6, height: hh * 2),
      bodyPaint,
    );
    // Legs
    final legPaint = Paint()
      ..color = const Color(0xFFE65100)
      ..strokeWidth = hw * 0.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - hw * 0.5, cy - hh * 0.2), Offset(cx - hw, cy - hh * 0.5), legPaint);
    canvas.drawLine(Offset(cx + hw * 0.5, cy - hh * 0.2), Offset(cx + hw, cy - hh * 0.5), legPaint);
    canvas.drawLine(Offset(cx - hw * 0.5, cy + hh * 0.3), Offset(cx - hw, cy + hh * 0.6), legPaint);
    canvas.drawLine(Offset(cx + hw * 0.5, cy + hh * 0.3), Offset(cx + hw, cy + hh * 0.6), legPaint);
    // Eyes
    canvas.drawCircle(Offset(cx - hw * 0.3, cy - hh * 0.5), hw * 0.2, eyePaint);
    canvas.drawCircle(Offset(cx + hw * 0.3, cy - hh * 0.5), hw * 0.2, eyePaint);
    canvas.drawCircle(Offset(cx - hw * 0.3, cy - hh * 0.5), hw * 0.1, pupilPaint);
    canvas.drawCircle(Offset(cx + hw * 0.3, cy - hh * 0.5), hw * 0.1, pupilPaint);
  }

  void _drawBeetle(Canvas canvas, double cx, double cy, double hw, double hh) {
    final shellPaint = Paint()..color = const Color(0xFF6D4C41);
    final headPaint = Paint()..color = const Color(0xFF3E2723);
    final eyePaint = Paint()..color = Colors.white;

    // Shell
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + hh * 0.1), width: hw * 2, height: hh * 1.8),
      shellPaint,
    );
    // Shell line
    final linePaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(cx, cy - hh * 0.7), Offset(cx, cy + hh * 0.9), linePaint);
    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - hh * 0.8), width: hw * 1.0, height: hh * 0.6),
      headPaint,
    );
    // Antennae
    final antPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - hw * 0.2, cy - hh), Offset(cx - hw * 0.5, cy - hh * 1.4), antPaint);
    canvas.drawLine(Offset(cx + hw * 0.2, cy - hh), Offset(cx + hw * 0.5, cy - hh * 1.4), antPaint);
    // Eyes
    canvas.drawCircle(Offset(cx - hw * 0.2, cy - hh * 0.8), hw * 0.12, eyePaint);
    canvas.drawCircle(Offset(cx + hw * 0.2, cy - hh * 0.8), hw * 0.12, eyePaint);
    // Legs
    final legPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = hw * 0.12
      ..strokeCap = StrokeCap.round;
    for (final dy in [-0.2, 0.1, 0.4]) {
      canvas.drawLine(Offset(cx - hw * 0.8, cy + hh * dy), Offset(cx - hw * 1.2, cy + hh * (dy - 0.15)), legPaint);
      canvas.drawLine(Offset(cx + hw * 0.8, cy + hh * dy), Offset(cx + hw * 1.2, cy + hh * (dy - 0.15)), legPaint);
    }
  }

  void _drawTurtle(Canvas canvas, double cx, double cy, double hw, double hh) {
    final shellPaint = Paint()..color = const Color(0xFF558B2F);
    final shellDarkPaint = Paint()..color = const Color(0xFF33691E);
    final skinPaint = Paint()..color = const Color(0xFF8BC34A);
    final eyePaint = Paint()..color = Colors.black;

    // Legs (drawn behind shell)
    for (final dx in [-0.7, 0.7]) {
      for (final dy in [-0.3, 0.4]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + hw * dx, cy + hh * dy),
            width: hw * 0.5,
            height: hh * 0.35,
          ),
          skinPaint,
        );
      }
    }
    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - hh * 0.7), width: hw * 0.7, height: hh * 0.5),
      skinPaint,
    );
    canvas.drawCircle(Offset(cx - hw * 0.15, cy - hh * 0.75), hw * 0.08, eyePaint);
    canvas.drawCircle(Offset(cx + hw * 0.15, cy - hh * 0.75), hw * 0.08, eyePaint);
    // Shell
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: hw * 1.8, height: hh * 1.6),
      shellPaint,
    );
    // Shell pattern
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: hw * 1.0, height: hh * 0.9),
      shellDarkPaint,
    );
  }

  void _renderPlayer(Canvas canvas) {
    final cx = _laneCenter(currentLane);
    final hw = laneWidth * 0.2;
    final hh = laneWidth * 0.35;

    // Snake body segments trailing behind
    final bodyPaint = Paint()..color = mode.snakeColor;
    final bodyDarkPaint = Paint()..color = const Color(0xFF00C853);
    for (int i = 4; i >= 1; i--) {
      final segY = playerY + i * hh * 0.6;
      final segR = hw * (1.0 - i * 0.1);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, segY), width: segR * 1.8, height: hh * 0.55),
        bodyDarkPaint,
      );
    }

    // Head — larger, pointed upward
    final headPath = Path()
      ..moveTo(cx, playerY - hh)
      ..quadraticBezierTo(cx + hw * 1.2, playerY - hh * 0.3, cx + hw, playerY + hh * 0.3)
      ..quadraticBezierTo(cx, playerY + hh * 0.5, cx - hw, playerY + hh * 0.3)
      ..quadraticBezierTo(cx - hw * 1.2, playerY - hh * 0.3, cx, playerY - hh)
      ..close();
    canvas.drawPath(headPath, bodyPaint);

    // Eyes
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(cx - hw * 0.35, playerY - hh * 0.4), hw * 0.22, eyePaint);
    canvas.drawCircle(Offset(cx + hw * 0.35, playerY - hh * 0.4), hw * 0.22, eyePaint);
    canvas.drawCircle(Offset(cx - hw * 0.35, playerY - hh * 0.5), hw * 0.12, pupilPaint);
    canvas.drawCircle(Offset(cx + hw * 0.35, playerY - hh * 0.5), hw * 0.12, pupilPaint);

    // Forked tongue
    final tongPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, playerY - hh), Offset(cx, playerY - hh * 1.4), tongPaint);
    canvas.drawLine(Offset(cx, playerY - hh * 1.4), Offset(cx - hw * 0.2, playerY - hh * 1.6), tongPaint);
    canvas.drawLine(Offset(cx, playerY - hh * 1.4), Offset(cx + hw * 0.2, playerY - hh * 1.6), tongPaint);
  }

  void _renderHUD(Canvas canvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'DIST: ${(_distanceTraveled ~/ 50)}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(trackRight + 8, 8));

    // Speed indicator
    final speedTp = TextPainter(
      text: TextSpan(
        text: '${_scrollSpeed.toInt()} km/h',
        style: TextStyle(
          color: mode.foodColor.withOpacity(0.7),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    speedTp.paint(canvas, Offset(trackRight + 8, 24));
  }
}

/// A single side-scenery frond that sways slowly around a fixed anchor.
class _SwayFrond {
  final double x;
  final double y;
  final double baseAngle;
  final double length;
  final double phase;
  final Rect clipRect;
  _SwayFrond({
    required this.x,
    required this.y,
    required this.baseAngle,
    required this.length,
    required this.phase,
    required this.clipRect,
  });
}

enum _ObjectType { rock, boost }
enum _AnimalType { frog, lizard, beetle, turtle }

class _TrackObject {
  int lane;
  double y;
  final _ObjectType type;
  _TrackObject({required this.lane, required this.y, required this.type});
}

class _Racer {
  int lane;
  double y;
  final double speed;
  final _AnimalType animal;
  double changeLaneTimer;
  _Racer({
    required this.lane,
    required this.y,
    required this.speed,
    required this.animal,
    required this.changeLaneTimer,
  });
}
