import 'dart:collection';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/cga_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// CGA mode game — 4-color palette with chunky 2x2-looking blocks and
/// CRT scanline effect.
class CgaGame extends FlameGame with KeyboardEvents {
  final CgaMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  final int gridWidth;
  final int gridHeight;
  final double? startSpeed;
  late double cellSize;
  late Vector2 boardOffset;

  // CGA palette 1 colors
  static const Color _black = Color(0xFF000000);
  static const Color _cyan = Color(0xFF00AAAA);
  static const Color _magenta = Color(0xFFAA00AA);
  static const Color _white = Color(0xFFAAAAAA);

  // Snake
  List<Point<int>> snakeSegments = [];
  Direction currentDirection = Direction.right;
  final Queue<Direction> _directionQueue = Queue<Direction>();
  static const int _maxQueuedInputs = 4;
  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;

  // Food
  Point<int> foodPosition = const Point(0, 0);

  final Random _random = Random();

  CgaGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
    int? gridWidth,
    int? gridHeight,
    this.startSpeed,
  })  : gridWidth = gridWidth ?? 20,
        gridHeight = gridHeight ?? 28;

  @override
  Color backgroundColor() => _black;

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
    gameState = GameState.playing;
    currentDirection = Direction.right;
    _directionQueue.clear();

    final startX = gridWidth ~/ 2;
    final startY = gridHeight ~/ 2;
    snakeSegments = [
      Point(startX, startY),
      Point(startX - 1, startY),
      Point(startX - 2, startY),
    ];

    _spawnFood();
  }

  void restart() {
    _startNewGame();
    onScoreChanged(0);
  }

  void respawn() {
    _tickTimer = 0;
    currentDirection = Direction.right;
    _directionQueue.clear();
    gameState = GameState.playing;
    final startX = gridWidth ~/ 2;
    final startY = gridHeight ~/ 2;
    snakeSegments = [
      Point(startX, startY),
      Point(startX - 1, startY),
      Point(startX - 2, startY),
    ];
    _spawnFood();
  }

  void _spawnFood() {
    Point<int> pos;
    do {
      pos = Point(_random.nextInt(gridWidth), _random.nextInt(gridHeight));
    } while (snakeSegments.any((s) => s.x == pos.x && s.y == pos.y));
    foodPosition = pos;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    _tickTimer += dt;
    if (_tickTimer >= (startSpeed ?? mode.tickInterval(score))) {
      _tickTimer = 0;
      _tick();
    }
  }

  void _tick() {
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

    // Walls kill
    if (newHead.x < 0 ||
        newHead.x >= gridWidth ||
        newHead.y < 0 ||
        newHead.y >= gridHeight) {
      _die();
      return;
    }

    // Self collision
    if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
      _die();
      return;
    }

    final ate = newHead.x == foodPosition.x && newHead.y == foodPosition.y;

    snakeSegments.insert(0, newHead);
    if (!ate) {
      snakeSegments.removeLast();
    }

    if (ate) {
      score += mode.pointsPerFood(score);
      onScoreChanged(score);
      _spawnFood();
    }
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
    final interval = mode.tickInterval(score);
    if (_tickTimer > interval * 0.4) {
      _tickTimer = interval;
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
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        togglePause();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW) {
        changeDirection(Direction.up);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.keyS) {
        changeDirection(Direction.down);
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
    }
    return KeyEventResult.ignored;
  }

  Vector2 _gridToScreen(Point<int> pos) {
    return Vector2(
      boardOffset.x + pos.x * cellSize,
      boardOffset.y + pos.y * cellSize,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;

    // ─── Thick white CGA border (3px) ───────────────────────────────
    final borderPaint = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(
      Rect.fromLTWH(boardOffset.x - 2, boardOffset.y - 2,
          cs * gridWidth + 4, cs * gridHeight + 4),
      borderPaint,
    );

    // ─── Snake — chunky cyan 2x2-looking blocks ────────────────────
    for (final seg in snakeSegments) {
      final sp = _gridToScreen(seg);
      // Outer filled rectangle (full cell)
      final snakePaint = Paint()..color = _cyan;
      canvas.drawRect(
        Rect.fromLTWH(sp.x, sp.y, cs, cs),
        snakePaint,
      );
      // Thick inner border to create chunky 2x2 pixel block feel
      final innerBorderPaint = Paint()
        ..color = _black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromLTWH(sp.x + cs * 0.25, sp.y + cs * 0.25,
            cs * 0.5, cs * 0.5),
        innerBorderPaint,
      );
      // Outer thick border on each cell
      final outerBorderPaint = Paint()
        ..color = _cyan.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromLTWH(sp.x, sp.y, cs, cs),
        outerBorderPaint,
      );
    }

    // ─── Food — magenta diamond shape ──────────────────────────────
    final foodPaint = Paint()..color = _magenta;
    final fsp = _gridToScreen(foodPosition);
    final centerX = fsp.x + cs / 2;
    final centerY = fsp.y + cs / 2;
    final diamondRadius = cs * 0.4;
    final diamondPath = Path()
      ..moveTo(centerX, centerY - diamondRadius) // top
      ..lineTo(centerX + diamondRadius, centerY) // right
      ..lineTo(centerX, centerY + diamondRadius) // bottom
      ..lineTo(centerX - diamondRadius, centerY) // left
      ..close();
    canvas.drawPath(diamondPath, foodPaint);

    // ─── Score text — blocky monospace ──────────────────────────────
    final scoreTp = TextPainter(
      text: TextSpan(
        text: 'SCORE: $score',
        style: const TextStyle(
          color: _white,
          fontSize: 14,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scoreTp.paint(
      canvas,
      Offset(boardOffset.x + 4, boardOffset.y - 18),
    );

    // ─── CRT scanline effect ───────────────────────────────────────
    final scanlinePaint = Paint()
      ..color = _black.withOpacity(0.15);
    final screenRect = Rect.fromLTWH(
      boardOffset.x - 2,
      boardOffset.y - 2,
      cs * gridWidth + 4,
      cs * gridHeight + 4,
    );
    for (double y = screenRect.top; y < screenRect.bottom; y += 3) {
      canvas.drawLine(
        Offset(screenRect.left, y),
        Offset(screenRect.right, y),
        scanlinePaint,
      );
    }
  }
}
