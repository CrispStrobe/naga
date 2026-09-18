import 'shared/direction_buffer.dart';
import 'dart:math';
import 'shared/free_cell.dart';
import 'shared/grid_motion.dart';
import 'shared/grid_snake_body.dart';
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
  double _tickTimer = 0;

  // Food
  Point<int> foodPosition = const Point(0, 0);

  final Random _random = Random();

  late final Paint _borderPaint = Paint()
    ..color = mode.borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  late final Paint _snakePaint = Paint()..color = mode.snakeColor;
  late final Paint _innerBorderPaint = Paint()
    ..color = mode.blockInsetColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  late final Paint _outerBorderPaint = Paint()
    ..color = mode.blockOutlineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  late final Paint _foodPaint = Paint()..color = mode.foodColor;
  late final Paint _scanlinePaint = Paint()..color = mode.scanlineColor;

  CgaGame({
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
      width: gridWidth,
      height: gridHeight,
      occupied: snakeSegments,
      random: _random,
    );
    if (pos == null) {
      _win();
      return;
    }
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
    currentDirection = _directionQueue.consume(currentDirection);

    final head = snakeSegments.first;
    late Point<int> newHead;

    newHead = gridStep(head, currentDirection);

    // Walls kill
    if (newHead.x < 0 ||
        newHead.x >= gridWidth ||
        newHead.y < 0 ||
        newHead.y >= gridHeight) {
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
      score += mode.pointsPerFood(score);
      onScoreChanged(score);
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

  TextPainter? _scoreTp;
  int? _scoreTpKey;

  TextPainter _getScoreTp() {
    final key = score;
    if (_scoreTp != null && _scoreTpKey == key) return _scoreTp!;
    _scoreTp?.dispose();
    _scoreTpKey = key;
    return _scoreTp = TextPainter(
      text: TextSpan(
        text: 'SCORE: $score',
        style: TextStyle(
          color: mode.scoreColor,
          fontSize: 14,
          fontFamily: 'NagaMono',
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void onRemove() {
    _scoreTp?.dispose();
    _scoreTp = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;

    // ─── Thick white CGA border (3px) ───────────────────────────────
    final borderPaint = _borderPaint;
    canvas.drawRect(
      Rect.fromLTWH(
        boardOffset.x - 2,
        boardOffset.y - 2,
        cs * gridWidth + 4,
        cs * gridHeight + 4,
      ),
      borderPaint,
    );

    // ─── Snake — chunky cyan 2x2-looking blocks ────────────────────
    final snakePaint = _snakePaint;
    final innerBorderPaint = _innerBorderPaint;
    final outerBorderPaint = _outerBorderPaint;
    for (final seg in snakeSegments) {
      final sp = _gridToScreen(seg);
      // Outer filled rectangle (full cell)

      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), snakePaint);
      // Thick inner border to create chunky 2x2 pixel block feel

      canvas.drawRect(
        Rect.fromLTWH(sp.x + cs * 0.25, sp.y + cs * 0.25, cs * 0.5, cs * 0.5),
        innerBorderPaint,
      );
      // Outer thick border on each cell

      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), outerBorderPaint);
    }

    // ─── Food — magenta diamond shape ──────────────────────────────
    if (!hasWon) {
      final foodPaint = _foodPaint;
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
    }

    // ─── Score text — blocky monospace ──────────────────────────────
    final scoreTp = _getScoreTp();
    scoreTp.paint(canvas, Offset(boardOffset.x + 4, boardOffset.y - 18));

    // ─── CRT scanline effect ───────────────────────────────────────
    final scanlinePaint = _scanlinePaint;
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
