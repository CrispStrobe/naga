import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/ascii_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// ASCII mode — terminal/DOS look, text-based rendering with TextPainter.
class AsciiGame extends FlameGame with KeyboardEvents {
  final AsciiMode mode;
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
  bool _foodIsSpecial = false; // alternates between * and $

  final Random _random = Random();

  // Cached text painters for performance
  final Map<String, TextPainter> _charCache = {};

  AsciiGame({
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
    _foodIsSpecial = _random.nextBool();
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

    // Wrap around
    newHead = Point(
      (newHead.x + gridWidth) % gridWidth,
      (newHead.y + gridHeight) % gridHeight,
    );

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

  TextPainter _getCharPainter(String ch, Color color, double fontSize) {
    final key = '$ch-${color.toARGB32()}-${fontSize.toStringAsFixed(1)}';
    if (_charCache.containsKey(key)) return _charCache[key]!;
    final tp = TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _charCache[key] = tp;
    return tp;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;
    final fontSize = cs * 0.85;
    final green = mode.snakeColor;

    // ─── ASCII border: +---+ style ───────────────────────────────────
    final borderColor = green.withOpacity(0.7);
    final cornerChar = _getCharPainter('+', borderColor, fontSize);
    final hChar = _getCharPainter('-', borderColor, fontSize);
    final vChar = _getCharPainter('|', borderColor, fontSize);

    // Top border
    _paintCharAt(canvas, cornerChar, boardOffset.x - cs, boardOffset.y - cs);
    for (int x = 0; x < gridWidth; x++) {
      _paintCharAt(canvas, hChar, boardOffset.x + x * cs, boardOffset.y - cs);
    }
    _paintCharAt(canvas, cornerChar, boardOffset.x + gridWidth * cs, boardOffset.y - cs);

    // Bottom border
    _paintCharAt(canvas, cornerChar, boardOffset.x - cs, boardOffset.y + gridHeight * cs);
    for (int x = 0; x < gridWidth; x++) {
      _paintCharAt(canvas, hChar, boardOffset.x + x * cs, boardOffset.y + gridHeight * cs);
    }
    _paintCharAt(canvas, cornerChar, boardOffset.x + gridWidth * cs, boardOffset.y + gridHeight * cs);

    // Side borders
    for (int y = 0; y < gridHeight; y++) {
      _paintCharAt(canvas, vChar, boardOffset.x - cs, boardOffset.y + y * cs);
      _paintCharAt(canvas, vChar, boardOffset.x + gridWidth * cs, boardOffset.y + y * cs);
    }

    // ─── Food ────────────────────────────────────────────────────────
    final foodChar = _foodIsSpecial ? r'$' : '*';
    final foodPainter = _getCharPainter(foodChar, green, fontSize);
    final fsp = _gridToScreen(foodPosition);
    _paintCharCentered(canvas, foodPainter, fsp.x, fsp.y, cs);

    // ─── Snake ───────────────────────────────────────────────────────
    for (int i = 0; i < snakeSegments.length; i++) {
      final seg = snakeSegments[i];
      final sp = _gridToScreen(seg);
      final ch = i == 0 ? '@' : '#';
      final painter = _getCharPainter(ch, green, fontSize);
      _paintCharCentered(canvas, painter, sp.x, sp.y, cs);
    }

    // ─── Score as monospace text ─────────────────────────────────────
    final scorePainter = TextPainter(
      text: TextSpan(
        text: 'SCORE: $score',
        style: TextStyle(
          color: green.withOpacity(0.8),
          fontSize: 12,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scorePainter.paint(
      canvas,
      Offset(boardOffset.x, boardOffset.y - cs - 16),
    );
  }

  void _paintCharAt(Canvas canvas, TextPainter tp, double x, double y) {
    tp.paint(canvas, Offset(x, y));
  }

  void _paintCharCentered(
    Canvas canvas,
    TextPainter tp,
    double x,
    double y,
    double cs,
  ) {
    tp.paint(
      canvas,
      Offset(
        x + (cs - tp.width) / 2,
        y + (cs - tp.height) / 2,
      ),
    );
  }
}
