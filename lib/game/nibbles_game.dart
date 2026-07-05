import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/nibbles_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Nibbles mode game — QBasic NIBBLES.BAS style with numbered food items,
/// solid block snake, blue border, and DOS status bar.
class NibblesGame extends FlameGame with KeyboardEvents {
  final NibblesMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  final int gridWidth;
  final int gridHeight;
  final double? startSpeed;
  late double cellSize;
  late Vector2 boardOffset;

  // QBasic colors
  static const Color _black = Color(0xFF000000);
  static const Color _brightGreen = Color(0xFF00FF00);
  static const Color _brightYellow = Color(0xFFFFFF00);
  static const Color _brightBlue = Color(0xFF0000AA);
  static const Color _white = Color(0xFFFFFFFF);

  // Snake
  List<Point<int>> snakeSegments = [];
  Direction currentDirection = Direction.right;
  Direction _nextDirection = Direction.right;
  GameState gameState = GameState.playing;
  int score = 0;
  int _level = 1;
  int _foodEaten = 0;
  double _tickTimer = 0;

  // Food — numbered 1-9 like original Nibbles
  Point<int> foodPosition = const Point(0, 0);
  int _foodNumber = 1;

  final Random _random = Random();

  // Cached text painters for food numbers
  final Map<String, TextPainter> _numberCache = {};

  // The play area starts after the status bar and border
  // Status bar: 1 cell at top
  // Border: 1 cell thick around the play area
  // Play area: inside the border
  static const int _statusBarRows = 1;
  static const int _borderThickness = 1;
  // Effective play area for the snake (inside border)
  static const int _playMinX = _borderThickness;
  static const int _playMinY = _statusBarRows + _borderThickness;
  int get _playMaxX => gridWidth - _borderThickness - 1;
  int get _playMaxY => gridHeight - _borderThickness - 1;

  NibblesGame({
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
    _level = 1;
    _foodNumber = 1;
    _foodEaten = 0;
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
      pos = Point(
        _playMinX + _random.nextInt(_playMaxX - _playMinX + 1),
        _playMinY + _random.nextInt(_playMaxY - _playMinY + 1),
      );
    } while (snakeSegments.any((s) => s.x == pos.x && s.y == pos.y));
    foodPosition = pos;
    _foodNumber = (_foodNumber % 9) + 1;
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

    // Wall collision (hit the border = die, like original Nibbles)
    if (newHead.x < _playMinX ||
        newHead.x > _playMaxX ||
        newHead.y < _playMinY ||
        newHead.y > _playMaxY) {
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
      _foodEaten++;
      score += mode.pointsPerFood(score) * _foodNumber;
      onScoreChanged(score);
      // Level up every 9 food items (one cycle of 1-9)
      if (_foodEaten % 9 == 0) {
        _level++;
      }
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

  TextPainter _getNumberPainter(int number, double fontSize) {
    final key = '$number-${fontSize.toStringAsFixed(1)}';
    if (_numberCache.containsKey(key)) return _numberCache[key]!;
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: _brightYellow,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _numberCache[key] = tp;
    return tp;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;

    // ─── Blue status bar at top (like DOS status bar) ───────────────
    final statusBarPaint = Paint()..color = _brightBlue;
    canvas.drawRect(
      Rect.fromLTWH(
        boardOffset.x,
        boardOffset.y,
        cs * gridWidth,
        cs * _statusBarRows,
      ),
      statusBarPaint,
    );

    // Status bar text: score and level
    final statusTp = TextPainter(
      text: TextSpan(
        text: '  Score: $score',
        style: TextStyle(
          color: _white,
          fontSize: cs * 0.7,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    statusTp.paint(
      canvas,
      Offset(
        boardOffset.x,
        boardOffset.y + (cs * _statusBarRows - statusTp.height) / 2,
      ),
    );

    final levelTp = TextPainter(
      text: TextSpan(
        text: 'Level: $_level  ',
        style: TextStyle(
          color: _white,
          fontSize: cs * 0.7,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    levelTp.paint(
      canvas,
      Offset(
        boardOffset.x + cs * gridWidth - levelTp.width,
        boardOffset.y + (cs * _statusBarRows - levelTp.height) / 2,
      ),
    );

    // ─── Blue border (1 cell thick, filled solid blocks) ────────────
    final borderPaint = Paint()..color = _brightBlue;

    // Top border row (below status bar)
    for (int x = 0; x < gridWidth; x++) {
      final sp = _gridToScreen(Point(x, _statusBarRows));
      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), borderPaint);
    }
    // Bottom border row
    for (int x = 0; x < gridWidth; x++) {
      final sp = _gridToScreen(Point(x, gridHeight - 1));
      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), borderPaint);
    }
    // Left border column
    for (int y = _statusBarRows; y < gridHeight; y++) {
      final sp = _gridToScreen(Point(0, y));
      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), borderPaint);
    }
    // Right border column
    for (int y = _statusBarRows; y < gridHeight; y++) {
      final sp = _gridToScreen(Point(gridWidth - 1, y));
      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), borderPaint);
    }

    // ─── Snake — solid bright green blocks, zero gap ────────────────
    final snakePaint = Paint()..color = _brightGreen;
    for (final seg in snakeSegments) {
      final sp = _gridToScreen(seg);
      // Fill the entire cell — no gaps, no rounded corners
      canvas.drawRect(
        Rect.fromLTWH(sp.x, sp.y, cs, cs),
        snakePaint,
      );
    }

    // ─── Food — numbered digit in bright yellow ─────────────────────
    final fontSize = cs * 0.85;
    final numberPainter = _getNumberPainter(_foodNumber, fontSize);
    final fsp = _gridToScreen(foodPosition);
    numberPainter.paint(
      canvas,
      Offset(
        fsp.x + (cs - numberPainter.width) / 2,
        fsp.y + (cs - numberPainter.height) / 2,
      ),
    );
  }
}
