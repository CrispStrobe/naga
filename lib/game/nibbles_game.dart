import 'shared/direction_buffer.dart';
import 'dart:math';
import 'shared/free_cell.dart';
import 'shared/grid_motion.dart';
import 'shared/grid_snake_body.dart';
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
  final VoidCallback? onVictory;
  bool hasWon = false;
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
  int _level = 1;
  int _foodEaten = 0;
  double _tickTimer = 0;

  // Food — numbered 1-9 like original Nibbles
  Point<int> foodPosition = const Point(0, 0);
  int _foodNumber = 1;

  final Random _random = Random();

  late final Paint _statusBarPaint = Paint()..color = mode.statusBarColor;
  late final Paint _borderPaint = Paint()..color = mode.playfieldBorderColor;
  late final Paint _snakePaint = Paint()..color = mode.snakeColor;

  // Cached text painters for food numbers
  final Map<int, TextPainter> _numberCache = {};
  double? _cachedFontSize;

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
    this.onVictory,
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
    hasWon = false;
    _tickTimer = 0;
    score = 0;
    _level = 1;
    _foodNumber = 1;
    _foodEaten = 0;
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
    hasWon = false;
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
    final pos = randomFreeCell(
      width: _playMaxX - _playMinX + 1,
      height: _playMaxY - _playMinY + 1,
      left: _playMinX,
      top: _playMinY,
      occupied: snakeSegments,
      random: _random,
    );
    if (pos == null) {
      _win();
      return;
    }
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
    currentDirection = _directionQueue.consume(currentDirection);

    final head = snakeSegments.first;
    late Point<int> newHead;

    newHead = gridStep(head, currentDirection);

    // Wall collision (hit the border = die, like original Nibbles)
    if (newHead.x < _playMinX ||
        newHead.x > _playMaxX ||
        newHead.y < _playMinY ||
        newHead.y > _playMaxY) {
      _die();
      return;
    }

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

  void _win() {
    if (gameState == GameState.gameOver) return;
    hasWon = true;
    gameState = GameState.gameOver;
    (onVictory ?? onGameOver)();
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

  TextPainter _getNumberPainter(int number, double fontSize) {
    if (_cachedFontSize != fontSize) {
      for (final painter in _numberCache.values) {
        painter.dispose();
      }
      _numberCache.clear();
      _cachedFontSize = fontSize;
    }
    final key = number;
    final cached = _numberCache[key];
    if (cached != null) return cached;
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: mode.foodColor,
          fontSize: fontSize,
          fontFamily: 'NagaMono',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _numberCache[key] = tp;
    return tp;
  }

  TextPainter? _statusTp;
  (int, double)? _statusTpKey;
  TextPainter? _levelTp;
  (int, double)? _levelTpKey;

  TextPainter _getStatusTp(double cs) {
    final key = (score, cs);
    if (_statusTp != null && _statusTpKey == key) return _statusTp!;
    _statusTp?.dispose();
    _statusTpKey = key;
    return _statusTp = TextPainter(
      text: TextSpan(
        text: '  Score: $score',
        style: TextStyle(
          color: mode.statusTextColor,
          fontSize: cs * 0.7,
          fontFamily: 'NagaMono',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  TextPainter _getLevelTp(double cs) {
    final key = (_level, cs);
    if (_levelTp != null && _levelTpKey == key) return _levelTp!;
    _levelTp?.dispose();
    _levelTpKey = key;
    return _levelTp = TextPainter(
      text: TextSpan(
        text: 'Level: $_level  ',
        style: TextStyle(
          color: mode.statusTextColor,
          fontSize: cs * 0.7,
          fontFamily: 'NagaMono',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void onRemove() {
    _statusTp?.dispose();
    _statusTp = null;
    _levelTp?.dispose();
    _levelTp = null;
    for (final painter in _numberCache.values) {
      painter.dispose();
    }
    _numberCache.clear();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;

    // ─── Blue status bar at top (like DOS status bar) ───────────────
    final statusBarPaint = _statusBarPaint;
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
    final statusTp = _getStatusTp(cs);
    statusTp.paint(
      canvas,
      Offset(
        boardOffset.x,
        boardOffset.y + (cs * _statusBarRows - statusTp.height) / 2,
      ),
    );

    final levelTp = _getLevelTp(cs);
    levelTp.paint(
      canvas,
      Offset(
        boardOffset.x + cs * gridWidth - levelTp.width,
        boardOffset.y + (cs * _statusBarRows - levelTp.height) / 2,
      ),
    );

    // ─── Blue border (1 cell thick, filled solid blocks) ────────────
    final borderPaint = _borderPaint;

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
    final snakePaint = _snakePaint;
    for (final seg in snakeSegments) {
      final sp = _gridToScreen(seg);
      // Fill the entire cell — no gaps, no rounded corners
      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), snakePaint);
    }

    // ─── Food — numbered digit in bright yellow ─────────────────────
    if (hasWon) return;
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
