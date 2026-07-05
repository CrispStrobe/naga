import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/cga_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// CGA mode game — 4-color palette with chunky 2x2-looking blocks.
class CgaGame extends FlameGame with KeyboardEvents {
  final CgaMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  static const int gridWidth = 20;
  static const int gridHeight = 28;
  late double cellSize;
  late Vector2 boardOffset;

  // Snake
  List<Point<int>> snakeSegments = [];
  Direction currentDirection = Direction.right;
  Direction _nextDirection = Direction.right;
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
  });

  @override
  Color backgroundColor() => mode.backgroundColor;

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
    _nextDirection = Direction.right;

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
    _nextDirection = Direction.right;
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
    if (_tickTimer >= mode.tickInterval(score)) {
      _tickTimer = 0;
      _tick();
    }
  }

  void _tick() {
    currentDirection = _nextDirection;

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
    if (dir == Direction.up && currentDirection == Direction.down) return;
    if (dir == Direction.down && currentDirection == Direction.up) return;
    if (dir == Direction.left && currentDirection == Direction.right) return;
    if (dir == Direction.right && currentDirection == Direction.left) return;
    _nextDirection = dir;
    final interval = mode.tickInterval(score);
    if (_tickTimer > interval * 0.4) {
      _tickTimer = interval;
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
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

    // ─── Chunky CGA border (white) ──────────────────────────────────
    final borderPaint = Paint()
      ..color = mode.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(
      Rect.fromLTWH(boardOffset.x - 2, boardOffset.y - 2,
          cs * gridWidth + 4, cs * gridHeight + 4),
      borderPaint,
    );

    // ─── Snake — chunky cyan blocks ─────────────────────────────────
    final snakePaint = Paint()..color = mode.snakeColor;
    for (final seg in snakeSegments) {
      final sp = _gridToScreen(seg);
      // Chunky 2x2 look: fill the entire cell, no gaps
      canvas.drawRect(
        Rect.fromLTWH(sp.x, sp.y, cs, cs),
        snakePaint,
      );
      // Inner highlight for chunky pixel effect
      final highlightPaint = Paint()
        ..color = mode.snakeColor.withOpacity(0.6);
      final half = cs / 2;
      canvas.drawRect(
        Rect.fromLTWH(sp.x, sp.y, half, half),
        highlightPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(sp.x + half, sp.y + half, half, half),
        highlightPaint,
      );
    }

    // ─── Food — chunky magenta block ────────────────────────────────
    final foodPaint = Paint()..color = mode.foodColor;
    final fsp = _gridToScreen(foodPosition);
    canvas.drawRect(
      Rect.fromLTWH(fsp.x, fsp.y, cs, cs),
      foodPaint,
    );
    // Inner pixel pattern
    final foodHighlight = Paint()
      ..color = mode.foodColor.withOpacity(0.6);
    final half = cs / 2;
    canvas.drawRect(
      Rect.fromLTWH(fsp.x + half, fsp.y, half, half),
      foodHighlight,
    );
    canvas.drawRect(
      Rect.fromLTWH(fsp.x, fsp.y + half, half, half),
      foodHighlight,
    );
  }
}
