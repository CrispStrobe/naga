import 'shared/direction_buffer.dart';
import 'dart:math';
import 'shared/grid_motion.dart';
import 'shared/grid_snake_body.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/snake2_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Snake II — maze levels, wrap-around, bonus items, multiple food, chain-link segments.
class Snake2Game extends FlameGame with KeyboardEvents {
  final Snake2Mode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  final int gridWidth;
  final int gridHeight;
  final double? startSpeed;
  late double cellSize;
  late Vector2 boardOffset;

  // Snake
  List<Point<int>> snakeSegments = GridSnakeBody([]);
  Direction currentDirection = Direction.right;
  final _directionQueue = DirectionBuffer(capacity: _maxQueuedInputs);
  static const int _maxQueuedInputs = 4;
  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;

  // Food — multiple items on screen
  List<Point<int>> foodPositions = [];

  // Bonus item
  Point<int>? bonusPosition;
  double _bonusTimer = 0;
  double _bonusSpawnTimer = 0;

  // Maze
  int _currentMaze = 0;
  List<Point<int>> mazeWalls = [];

  final Random _random = Random();

  late final Paint _borderPaint = Paint()
    ..color = mode.snakeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  late final Paint _wallPaint = Paint()..color = mode.wallColor;
  late final Paint _foodPaint = Paint()..color = mode.foodColor;
  late final Paint _bonusPaint = Paint()..color = mode.snakeColor;
  late final Paint _snakeFillPaint = Paint()..color = mode.snakeColor;
  late final Paint _snakeBorderPaint = Paint()
    ..color = mode.snakeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  late final Paint _snakeBgPaint = Paint()..color = mode.backgroundColor;

  Snake2Game({
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
    _currentMaze = 0;
    gameState = GameState.playing;
    currentDirection = Direction.right;
    _directionQueue.clear();
    _bonusSpawnTimer = 0;
    bonusPosition = null;

    _loadMaze(_currentMaze);
    _spawnSnake();
    _spawnAllFood();
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
    _spawnSnake();
    foodPositions.clear();
    bonusPosition = null;
    _spawnAllFood();
  }

  // ─── Maze layouts ──────────────────────────────────────────────────

  void _loadMaze(int index) {
    mazeWalls = _generateMaze(index % 5);
  }

  List<Point<int>> _generateMaze(int type) {
    final walls = <Point<int>>[];
    switch (type) {
      case 0:
        // Empty — no internal walls
        break;
      case 1:
        // Cross in the center
        for (int i = 5; i < gridWidth - 5; i++) {
          walls.add(Point(i, gridHeight ~/ 2));
        }
        for (int j = 7; j < gridHeight - 7; j++) {
          walls.add(Point(gridWidth ~/ 2, j));
        }
        break;
      case 2:
        // Corridors — horizontal bars
        for (int i = 2; i < gridWidth - 4; i++) {
          walls.add(Point(i, 7));
          walls.add(Point(i, 20));
        }
        for (int i = 4; i < gridWidth - 2; i++) {
          walls.add(Point(i, 13));
        }
        break;
      case 3:
        // Rooms — four boxes
        for (int i = 3; i < 8; i++) {
          walls.add(Point(i, 5));
          walls.add(Point(i, 10));
          walls.add(Point(i + 9, 5));
          walls.add(Point(i + 9, 10));
          walls.add(Point(i, 17));
          walls.add(Point(i, 22));
          walls.add(Point(i + 9, 17));
          walls.add(Point(i + 9, 22));
        }
        for (int j = 5; j <= 10; j++) {
          walls.add(Point(3, j));
          walls.add(Point(7, j));
          walls.add(Point(12, j));
          walls.add(Point(16, j));
          walls.add(Point(3, j + 12));
          walls.add(Point(7, j + 12));
          walls.add(Point(12, j + 12));
          walls.add(Point(16, j + 12));
        }
        break;
      case 4:
        // Spiral
        // Top bar
        for (int i = 2; i < gridWidth - 2; i++) {
          walls.add(Point(i, 4));
        }
        // Right bar
        for (int j = 4; j < gridHeight - 4; j++) {
          walls.add(Point(gridWidth - 3, j));
        }
        // Bottom bar
        for (int i = 4; i < gridWidth - 2; i++) {
          walls.add(Point(i, gridHeight - 5));
        }
        // Left inner bar
        for (int j = 7; j < gridHeight - 4; j++) {
          walls.add(Point(4, j));
        }
        // Top inner bar
        for (int i = 4; i < gridWidth - 5; i++) {
          walls.add(Point(i, 7));
        }
        break;
    }
    return walls;
  }

  bool _isWall(Point<int> pos) {
    return mazeWalls.any((w) => w.x == pos.x && w.y == pos.y);
  }

  // ─── Spawning ──────────────────────────────────────────────────────

  void _spawnSnake() {
    // Find a clear area for snake
    final startX = gridWidth ~/ 2;
    final startY = gridHeight ~/ 2;
    snakeSegments = GridSnakeBody([
      Point(startX, startY),
      Point(startX - 1, startY),
      Point(startX - 2, startY),
    ]);
    // Clear any walls at snake start position
    mazeWalls.removeWhere(
      (w) =>
          (w.x >= startX - 3 && w.x <= startX + 1) &&
          (w.y >= startY - 1 && w.y <= startY + 1),
    );
  }

  void _spawnAllFood() {
    foodPositions.clear();
    for (int i = 0; i < mode.foodCount; i++) {
      _spawnOneFood();
    }
  }

  void _spawnOneFood() {
    Point<int> pos;
    int attempts = 0;
    do {
      pos = Point(_random.nextInt(gridWidth), _random.nextInt(gridHeight));
      attempts++;
      if (attempts > 200) return; // Safety
    } while (_isOccupied(pos));
    foodPositions.add(pos);
  }

  bool _isOccupied(Point<int> pos) {
    if (snakeSegments.contains(pos)) return true;
    if (foodPositions.any((f) => f.x == pos.x && f.y == pos.y)) return true;
    if (_isWall(pos)) return true;
    if (bonusPosition != null &&
        bonusPosition!.x == pos.x &&
        bonusPosition!.y == pos.y) {
      return true;
    }
    return false;
  }

  void _spawnBonus() {
    Point<int> pos;
    int attempts = 0;
    do {
      pos = Point(_random.nextInt(gridWidth), _random.nextInt(gridHeight));
      attempts++;
      if (attempts > 200) return;
    } while (_isOccupied(pos));
    bonusPosition = pos;
    _bonusTimer = mode.bonusDuration;
  }

  // ─── Update ────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    // Bonus timer
    if (bonusPosition != null) {
      _bonusTimer -= dt;
      if (_bonusTimer <= 0) {
        bonusPosition = null;
      }
    }

    // Spawn bonus periodically
    _bonusSpawnTimer += dt;
    if (_bonusSpawnTimer >= 12.0 && bonusPosition == null) {
      _bonusSpawnTimer = 0;
      _spawnBonus();
    }

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

    // Wall collision (maze walls kill)
    if (_isWall(newHead)) {
      _die();
      return;
    }

    // Self collision
    if (snakeSegments.contains(newHead)) {
      _die();
      return;
    }

    // Check food
    final foodIndex = foodPositions.indexWhere(
      (f) => f.x == newHead.x && f.y == newHead.y,
    );
    final ateFood = foodIndex >= 0;

    // Check bonus
    final ateBonus =
        bonusPosition != null &&
        bonusPosition!.x == newHead.x &&
        bonusPosition!.y == newHead.y;

    snakeSegments.insert(0, newHead);
    if (!ateFood && !ateBonus) {
      snakeSegments.removeLast();
    }

    if (ateFood) {
      foodPositions.removeAt(foodIndex);
      score += mode.pointsPerFood(score);
      onScoreChanged(score);
      _spawnOneFood();

      // Advance maze every 100 points
      final newMaze = (score ~/ 100) % 5;
      if (newMaze != _currentMaze) {
        _currentMaze = newMaze;
        _loadMaze(_currentMaze);
        // Clear walls that overlap snake
        mazeWalls.removeWhere((w) => snakeSegments.contains(w));
      }
    }

    if (ateBonus) {
      score += mode.pointsPerBonus;
      onScoreChanged(score);
      bonusPosition = null;
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

    // Trigger early tick for responsiveness
    if (_directionQueue.length == 1) {
      final interval = mode.tickInterval(score);
      if (_tickTimer > interval * 0.4) {
        _tickTimer = interval;
      }
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

  Vector2 gridToScreen(Point<int> pos) {
    return Vector2(
      boardOffset.x + pos.x * cellSize,
      boardOffset.y + pos.y * cellSize,
    );
  }

  // ─── Rendering ─────────────────────────────────────────────────────

  TextPainter? _tp;
  int? _tpKey;

  TextPainter _getTp() {
    final key = _currentMaze;
    if (_tp != null && _tpKey == key) return _tp!;
    _tp?.dispose();
    _tpKey = key;
    return _tp = TextPainter(
      text: TextSpan(
        text: 'MAZE ${_currentMaze + 1}',
        style: TextStyle(
          color: mode.mazeLabelColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void onRemove() {
    _tp?.dispose();
    _tp = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;

    // Draw border
    final borderPaint = _borderPaint;
    canvas.drawRect(
      Rect.fromLTWH(
        boardOffset.x,
        boardOffset.y,
        cs * gridWidth,
        cs * gridHeight,
      ),
      borderPaint,
    );

    // Draw maze walls as dark blocks
    final wallPaint = _wallPaint;
    for (final wall in mazeWalls) {
      final sp = gridToScreen(wall);
      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), wallPaint);
    }

    // Draw food items
    final foodPaint = _foodPaint;
    for (final f in foodPositions) {
      final sp = gridToScreen(f);
      final inset = cs * 0.2;
      canvas.drawRect(
        Rect.fromLTWH(
          sp.x + inset,
          sp.y + inset,
          cs - inset * 2,
          cs - inset * 2,
        ),
        foodPaint,
      );
    }

    // Draw bonus item (flashing)
    if (bonusPosition != null) {
      final sp = gridToScreen(bonusPosition!);
      final flash = (_bonusTimer * 4).floor() % 2 == 0;
      if (flash) {
        final bonusPaint = _bonusPaint;
        final inset = cs * 0.1;
        // Star/diamond shape for bonus
        final cx = sp.x + cs / 2;
        final cy = sp.y + cs / 2;
        final r = (cs - inset * 2) / 2;
        final path = Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r * 0.4, cy - r * 0.4)
          ..lineTo(cx + r, cy)
          ..lineTo(cx + r * 0.4, cy + r * 0.4)
          ..lineTo(cx, cy + r)
          ..lineTo(cx - r * 0.4, cy + r * 0.4)
          ..lineTo(cx - r, cy)
          ..lineTo(cx - r * 0.4, cy - r * 0.4)
          ..close();
        canvas.drawPath(path, bonusPaint);
      }
    }

    // Draw snake as chain-link segments (small outlined squares with gap)
    final snakeFillPaint = _snakeFillPaint;
    final snakeBorderPaint = _snakeBorderPaint;
    final snakeBgPaint = _snakeBgPaint;

    for (int i = 0; i < snakeSegments.length; i++) {
      final seg = snakeSegments[i];
      final sp = gridToScreen(seg);
      // Each segment is a small square with 1px border, slight gap
      final gap = cs * 0.1;
      final segRect = Rect.fromLTWH(
        sp.x + gap,
        sp.y + gap,
        cs - gap * 2,
        cs - gap * 2,
      );
      // Fill with background first (to create the outlined look)
      canvas.drawRect(segRect, snakeBgPaint);
      // Draw border
      canvas.drawRect(segRect, snakeBorderPaint);
      // Fill a smaller inner rect for the chain-link effect
      final innerGap = cs * 0.2;
      final innerRect = Rect.fromLTWH(
        sp.x + innerGap,
        sp.y + innerGap,
        cs - innerGap * 2,
        cs - innerGap * 2,
      );
      canvas.drawRect(innerRect, snakeFillPaint);
    }

    // Maze level indicator
    final tp = _getTp();
    tp.paint(
      canvas,
      Offset(boardOffset.x + gridWidth * cs - tp.width - 4, boardOffset.y - 16),
    );
  }
}
