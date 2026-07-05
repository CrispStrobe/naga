import 'dart:collection';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/rush_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Endless runner mode — auto-scrolling level, dodge obstacles, eat food.
class RushGame extends FlameGame with KeyboardEvents {
  final RushMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  static const int gridWidth = 20;
  static const int gridHeight = 28;
  late double cellSize;
  late Vector2 boardOffset;

  // Snake
  List<Point<int>> snakeSegments = [];
  Direction currentDirection = Direction.up;
  final Queue<Direction> _directionQueue = Queue<Direction>();
  static const int _maxQueuedInputs = 4;
  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;

  // Scrolling obstacles
  List<_Obstacle> obstacles = [];
  List<Point<int>> food = [];
  double _scrollTimer = 0;
  double _scrollInterval = 2.0; // how often new row spawns
  int _distanceTraveled = 0;

  final Random _random = Random();

  // Cached habitat decoration layer (board fill + savanna doodles).
  ui.Picture? _decorPicture;
  double _decorCellSize = -1;

  RushGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
  });

  @override
  Color backgroundColor() =>
      Color.lerp(mode.backgroundColor, Colors.black, 0.18)!;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _calculateGrid();
    _startNewGame();
  }

  void _calculateGrid() {
    final w = size.x;
    final h = size.y;
    cellSize = min(w / gridWidth, h / gridHeight);
    boardOffset = Vector2(
      (w - cellSize * gridWidth) / 2,
      (h - cellSize * gridHeight) / 2,
    );
  }

  void _startNewGame() {
    score = 0;
    _distanceTraveled = 0;
    _scrollInterval = 2.0;
    gameState = GameState.playing;
    currentDirection = Direction.up;
    _directionQueue.clear();
    obstacles.clear();
    food.clear();

    // Snake starts at bottom center, moving up
    final startX = gridWidth ~/ 2;
    final startY = gridHeight - 5;
    snakeSegments = [
      Point(startX, startY),
      Point(startX, startY + 1),
      Point(startX, startY + 2),
    ];

    // Pre-fill some obstacle rows
    for (int y = 0; y < gridHeight - 8; y += 3) {
      _spawnObstacleRow(y);
    }
  }

  void _spawnObstacleRow(int y) {
    // Create a row with random gaps
    final gapStart = _random.nextInt(gridWidth - 6);
    final gapWidth = 4 + _random.nextInt(4); // gap of 4-7 cells

    for (int x = 0; x < gridWidth; x++) {
      if (x >= gapStart && x < gapStart + gapWidth) {
        // Gap — maybe place food here
        if (_random.nextDouble() < 0.3) {
          food.add(Point(x, y));
        }
        continue;
      }
      // Only place obstacle with low probability (20%) to keep it playable
      if (_random.nextDouble() < 0.2) {
        obstacles.add(_Obstacle(position: Point(x, y)));
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    // Snake tick
    _tickTimer += dt;
    if (_tickTimer >= mode.tickInterval(score)) {
      _tickTimer = 0;
      _tickSnake();
    }

    // Scroll tick — everything moves down
    _scrollTimer += dt;
    if (_scrollTimer >= _scrollInterval) {
      _scrollTimer = 0;
      _scroll();
    }
  }

  void _tickSnake() {
    if (_directionQueue.isNotEmpty) {
      currentDirection = _directionQueue.removeFirst();
    }
    final head = snakeSegments.first;
    late Point<int> newHead;

    switch (currentDirection) {
      case Direction.up:
        newHead = Point(head.x, head.y - 1);
      case Direction.down:
        newHead = Point(head.x, head.y + 1);
      case Direction.left:
        newHead = Point(head.x - 1, head.y);
      case Direction.right:
        newHead = Point(head.x + 1, head.y);
    }

    // Wrap horizontally, die at top/bottom
    if (newHead.y < 0 || newHead.y >= gridHeight) {
      _die();
      return;
    }
    newHead = Point((newHead.x + gridWidth) % gridWidth, newHead.y);

    // Obstacle collision
    if (obstacles.any((o) => o.position.x == newHead.x && o.position.y == newHead.y)) {
      _die();
      return;
    }

    // Self collision
    if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
      _die();
      return;
    }

    // Food collection
    bool ate = false;
    food.removeWhere((f) {
      if (f.x == newHead.x && f.y == newHead.y) {
        score += 5;
        onScoreChanged(score);
        ate = true;
        return true;
      }
      return false;
    });

    snakeSegments.insert(0, newHead);
    if (!ate) {
      snakeSegments.removeLast();
    }
  }

  void _scroll() {
    _distanceTraveled++;

    // Score for surviving
    score += 1;
    onScoreChanged(score);

    // Speed up gradually
    _scrollInterval = max(0.5, 2.0 - _distanceTraveled * 0.002);

    // Move everything down by 1
    for (final obs in obstacles) {
      obs.position = Point(obs.position.x, obs.position.y + 1);
    }
    for (int i = 0; i < food.length; i++) {
      food[i] = Point(food[i].x, food[i].y + 1);
    }

    // Remove off-screen
    obstacles.removeWhere((o) => o.position.y >= gridHeight);
    food.removeWhere((f) => f.y >= gridHeight);

    // Spawn new row at top
    _spawnObstacleRow(0);

    // Check if obstacles landed on snake
    final head = snakeSegments.first;
    if (obstacles.any((o) => o.position.x == head.x && o.position.y == head.y)) {
      _die();
      return;
    }

    // Push snake down with scroll (if not moving up)
    // Snake stays put — obstacles scroll toward it
  }

  void _die() {
    gameState = GameState.gameOver;
    onGameOver();
  }

  void changeDirection(Direction dir) {
    final lastDir = _directionQueue.isNotEmpty
        ? _directionQueue.last
        : currentDirection;
    if (dir == Direction.up && lastDir == Direction.down) return;
    if (dir == Direction.down && lastDir == Direction.up) return;
    if (dir == Direction.left && lastDir == Direction.right) return;
    if (dir == Direction.right && lastDir == Direction.left) return;
    if (dir == lastDir) return;
    if (_directionQueue.length < _maxQueuedInputs) {
      _directionQueue.add(dir);
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
      if (event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.keyW) {
        changeDirection(Direction.up);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.keyS) {
        changeDirection(Direction.down);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.keyA) {
        changeDirection(Direction.left);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.keyD) {
        changeDirection(Direction.right);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Vector2 _gridToScreen(Point<int> pos) {
    return Vector2(
      boardOffset.x + pos.x * cellSize,
      boardOffset.y + pos.y * cellSize,
    );
  }

  /// Builds the cached habitat layer: bright savanna board on the darker
  /// surround, plus grass tufts, streaks and small shrubs.
  /// Deterministic (fixed seed) and cached so render stays cheap.
  ui.Picture _buildDecorPicture() {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final cs = cellSize;
    final bg = mode.backgroundColor;
    final boardRect = Rect.fromLTWH(
        boardOffset.x, boardOffset.y, gridWidth * cs, gridHeight * cs);

    // Bright play field on the darker surround
    c.drawRect(boardRect, Paint()..color = bg);

    c.save();
    c.clipRect(boardRect);
    final rng = Random(7331); // fixed seed: same pattern every rebuild

    // Grass streaks — thin horizontal-ish dashes, sun-bleached and shaded
    final streakLight = Paint()
      ..color = Color.lerp(bg, Colors.white, 0.09)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = cs * 0.08;
    final streakDark = Paint()
      ..color = Color.lerp(bg, Colors.black, 0.07)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = cs * 0.08;
    final streakCount = (gridWidth * gridHeight * 0.04).round();
    for (int i = 0; i < streakCount; i++) {
      final x = boardRect.left + rng.nextDouble() * boardRect.width;
      final y = boardRect.top + rng.nextDouble() * boardRect.height;
      final len = cs * (0.6 + rng.nextDouble() * 1.0);
      final tilt = (rng.nextDouble() - 0.5) * cs * 0.3;
      c.drawLine(
        Offset(x, y),
        Offset(x + len, y + tilt),
        rng.nextBool() ? streakLight : streakDark,
      );
    }

    // Grass tufts — small fans of blades
    final tuftPaint = Paint()
      ..color = Color.lerp(bg, Colors.black, 0.10)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = cs * 0.07
      ..strokeCap = StrokeCap.round;
    final tuftCount = (gridWidth * gridHeight * 0.02).round();
    for (int i = 0; i < tuftCount; i++) {
      final x = boardRect.left + rng.nextDouble() * boardRect.width;
      final y = boardRect.top + rng.nextDouble() * boardRect.height;
      final h = cs * (0.35 + rng.nextDouble() * 0.35);
      for (final dx in [-0.28, 0.0, 0.28]) {
        c.drawLine(
          Offset(x, y),
          Offset(x + h * dx * 1.5, y - h),
          tuftPaint,
        );
      }
    }

    // Small savanna shrubs — olive-tinted blob clusters
    final shrubPaint = Paint()
      ..color = Color.lerp(bg, const Color(0xFF33691E), 0.18)!;
    for (int i = 0; i < 7; i++) {
      final x = boardRect.left + rng.nextDouble() * boardRect.width;
      final y = boardRect.top + rng.nextDouble() * boardRect.height;
      final r = cs * (0.25 + rng.nextDouble() * 0.2);
      c.drawCircle(Offset(x - r * 0.7, y), r * 0.8, shrubPaint);
      c.drawCircle(Offset(x + r * 0.7, y), r * 0.8, shrubPaint);
      c.drawCircle(Offset(x, y - r * 0.5), r, shrubPaint);
    }

    c.restore();
    return recorder.endRecording();
  }

  @override
  void onRemove() {
    _decorPicture?.dispose();
    _decorPicture = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;

    // Habitat layer — bright board on darker surround (cached)
    if (_decorPicture == null || _decorCellSize != cs) {
      _decorCellSize = cs;
      _decorPicture?.dispose();
      _decorPicture = _buildDecorPicture();
    }
    canvas.drawPicture(_decorPicture!);

    // Border
    final borderPaint = Paint()
      ..color = mode.snakeColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(boardOffset.x, boardOffset.y, cs * gridWidth, cs * gridHeight),
      borderPaint,
    );

    // Obstacles
    final obsPaint = Paint()..color = mode.obstacleColor;
    for (final obs in obstacles) {
      final sp = _gridToScreen(obs.position);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sp.x + cs * 0.05, sp.y + cs * 0.05, cs * 0.9, cs * 0.9),
          Radius.circular(cs * 0.1),
        ),
        obsPaint,
      );
    }

    // Food
    final foodPaint = Paint()..color = mode.foodColor;
    for (final f in food) {
      final sp = _gridToScreen(f);
      canvas.drawCircle(Offset(sp.x + cs / 2, sp.y + cs / 2), cs * 0.25, foodPaint);
    }

    // Snake
    final snakePaint = Paint()..color = mode.snakeColor;
    for (int i = 0; i < snakeSegments.length; i++) {
      final seg = snakeSegments[i];
      final sp = _gridToScreen(seg);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sp.x + cs * 0.05, sp.y + cs * 0.05, cs * 0.9, cs * 0.9),
          Radius.circular(cs * 0.12),
        ),
        snakePaint,
      );
    }

    // Distance counter
    final tp = TextPainter(
      text: TextSpan(
        text: 'DIST: $_distanceTraveled',
        // Sits on the darker surround outside the board — keep it light.
        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(boardOffset.x + gridWidth * cs - tp.width - 4, boardOffset.y - 16));
  }
}

class _Obstacle {
  Point<int> position;
  _Obstacle({required this.position});
}
