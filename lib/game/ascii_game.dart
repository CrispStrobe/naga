import 'shared/direction_buffer.dart';
import 'dart:math';
import 'shared/grid_motion.dart';
import 'shared/grid_snake_body.dart';
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

  final int gridWidth;
  final int gridHeight;
  final double? startSpeed;
  late double cellSize;
  late Vector2 boardOffset;

  // Snake
  List<Point<int>> snakeSegments = GridSnakeBody();
  Direction currentDirection = Direction.right;
  final _directionQueue = DirectionBuffer(capacity: _maxQueuedInputs);
  static const int _maxQueuedInputs = 4;
  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;

  // Food
  Point<int> foodPosition = const Point(0, 0);
  bool _foodIsSpecial = false; // alternates between * and $

  final Random _random = Random();

  // Cached text painters for performance
  final Map<(String, Color), TextPainter> _charCache = {};
  double? _cachedFontSize;

  AsciiGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
    int? gridWidth,
    int? gridHeight,
    this.startSpeed,
  }) : gridWidth = gridWidth ?? 20,
       gridHeight = gridHeight ?? 28;

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
    _directionQueue.clear();

    final startX = gridWidth ~/ 2;
    final startY = gridHeight ~/ 2;
    snakeSegments = GridSnakeBody([
      Point(startX, startY),
      Point(startX - 1, startY),
      Point(startX - 2, startY),
    ]);

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
    snakeSegments = GridSnakeBody([
      Point(startX, startY),
      Point(startX - 1, startY),
      Point(startX - 2, startY),
    ]);
    _spawnFood();
  }

  void _spawnFood() {
    Point<int> pos;
    do {
      pos = Point(_random.nextInt(gridWidth), _random.nextInt(gridHeight));
    } while (snakeSegments.contains(pos));
    foodPosition = pos;
    _foodIsSpecial = _random.nextBool();
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
    currentDirection = _directionQueue.consume(currentDirection);

    final head = snakeSegments.first;
    late Point<int> newHead;

    newHead = gridStep(head, currentDirection);

    // Wrap around
    newHead = wrapGrid(newHead, gridWidth, gridHeight);

    // Self collision
    if (snakeSegments.contains(newHead)) {
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
    if (_directionQueue.enqueue(dir, currentDirection) ==
        DirectionInput.rejected) {
      return;
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

  TextPainter _getCharPainter(String ch, Color color, double fontSize) {
    if (_cachedFontSize != fontSize) {
      for (final painter in _charCache.values) {
        painter.dispose();
      }
      _charCache.clear();
      _cachedFontSize = fontSize;
    }
    final key = (ch, color);
    final cached = _charCache[key];
    if (cached != null) return cached;
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

  TextPainter? _scorePainter;
  int? _scorePainterKey;

  TextPainter _getScorePainter() {
    final key = score;
    if (_scorePainter != null && _scorePainterKey == key) return _scorePainter!;
    _scorePainter?.dispose();
    _scorePainterKey = key;
    return _scorePainter = TextPainter(
      text: TextSpan(
        text: 'SCORE: $score',
        style: TextStyle(
          color: mode.scoreColor,
          fontSize: 12,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void onRemove() {
    _scorePainter?.dispose();
    _scorePainter = null;
    for (final painter in _charCache.values) {
      painter.dispose();
    }
    _charCache.clear();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;
    final fontSize = cs * 0.85;
    final green = mode.snakeColor;

    // ─── ASCII border: +---+ style ───────────────────────────────────
    final borderColor = mode.borderColor;
    final cornerChar = _getCharPainter('+', borderColor, fontSize);
    final hChar = _getCharPainter('-', borderColor, fontSize);
    final vChar = _getCharPainter('|', borderColor, fontSize);

    // Top border
    _paintCharAt(canvas, cornerChar, boardOffset.x - cs, boardOffset.y - cs);
    for (int x = 0; x < gridWidth; x++) {
      _paintCharAt(canvas, hChar, boardOffset.x + x * cs, boardOffset.y - cs);
    }
    _paintCharAt(
      canvas,
      cornerChar,
      boardOffset.x + gridWidth * cs,
      boardOffset.y - cs,
    );

    // Bottom border
    _paintCharAt(
      canvas,
      cornerChar,
      boardOffset.x - cs,
      boardOffset.y + gridHeight * cs,
    );
    for (int x = 0; x < gridWidth; x++) {
      _paintCharAt(
        canvas,
        hChar,
        boardOffset.x + x * cs,
        boardOffset.y + gridHeight * cs,
      );
    }
    _paintCharAt(
      canvas,
      cornerChar,
      boardOffset.x + gridWidth * cs,
      boardOffset.y + gridHeight * cs,
    );

    // Side borders
    for (int y = 0; y < gridHeight; y++) {
      _paintCharAt(canvas, vChar, boardOffset.x - cs, boardOffset.y + y * cs);
      _paintCharAt(
        canvas,
        vChar,
        boardOffset.x + gridWidth * cs,
        boardOffset.y + y * cs,
      );
    }

    // ─── Food ────────────────────────────────────────────────────────
    final foodChar = _foodIsSpecial ? r'$' : '*';
    final foodPainter = _getCharPainter(foodChar, green, fontSize);
    final fsp = _gridToScreen(foodPosition);
    _paintCharCentered(canvas, foodPainter, fsp.x, fsp.y, cs);

    // Resolve just twice per frame, rather than a key allocation per segment.
    final headPainter = _getCharPainter('@', green, fontSize);
    final bodyPainter = _getCharPainter('#', green, fontSize);
    // ─── Snake ───────────────────────────────────────────────────────
    for (int i = 0; i < snakeSegments.length; i++) {
      final seg = snakeSegments[i];
      final sp = _gridToScreen(seg);
      final painter = i == 0 ? headPainter : bodyPainter;
      _paintCharCentered(canvas, painter, sp.x, sp.y, cs);
    }

    // ─── Score as monospace text ─────────────────────────────────────
    final scorePainter = _getScorePainter();
    scorePainter.paint(canvas, Offset(boardOffset.x, boardOffset.y - cs - 16));
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
    tp.paint(canvas, Offset(x + (cs - tp.width) / 2, y + (cs - tp.height) / 2));
  }
}
