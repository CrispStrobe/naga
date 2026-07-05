import 'dart:collection';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/game_mode.dart';
import '../components/snake.dart';
import '../components/food.dart';
import '../components/power_up.dart';
import '../components/grid_board.dart';

enum Direction { up, down, left, right }

enum GameState { playing, paused, gameOver }

class SnakeGame extends FlameGame with KeyboardEvents, HasCollisionDetection {
  final GameMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  late Snake snake;
  late Food food;
  late GridBoard board;

  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;
  final Queue<Direction> _directionQueue = Queue<Direction>();
  static const int _maxQueuedInputs = 4;
  Direction currentDirection = Direction.right;
  final Random _random = Random();

  // Buff/power-up state
  final Map<PowerUpType, double> activeBuffs = {};
  PowerUp? _currentPowerUp;
  double _powerUpSpawnTimer = 0;
  late double _nextPowerUpSpawnTime;
  double shieldFlashTimer = 0;

  bool get _powerUpsEnabled => mode.name != 'Classic';

  // Grid dimensions — configurable via settings
  late final int gridWidth;
  late final int gridHeight;
  final bool? wallsKillOverride;
  late double cellSize;
  late Vector2 boardOffset;

  SnakeGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
    int? gridWidth,
    int? gridHeight,
    this.wallsKillOverride,
  })  : gridWidth = gridWidth ?? 20,
        gridHeight = gridHeight ?? 28;

  bool get _wallsKill => wallsKillOverride ?? mode.wallsKill;

  @override
  Color backgroundColor() => mode.backgroundColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _calculateGrid();
    board = GridBoard(game: this);
    add(board);
    _startNewGame();
  }

  void _calculateGrid() {
    final availableWidth = size.x;
    final availableHeight = size.y;
    cellSize = min(availableWidth / gridWidth, availableHeight / gridHeight);
    final boardWidth = cellSize * gridWidth;
    final boardHeight = cellSize * gridHeight;
    boardOffset = Vector2(
      (availableWidth - boardWidth) / 2,
      (availableHeight - boardHeight) / 2,
    );
  }

  void _startNewGame() {
    score = 0;
    _tickTimer = 0;
    currentDirection = Direction.right;
    _directionQueue.clear();
    gameState = GameState.playing;
    activeBuffs.clear();
    _powerUpSpawnTimer = 0;
    _nextPowerUpSpawnTime = 20.0 + _random.nextDouble() * 10.0;
    shieldFlashTimer = 0;
    _currentPowerUp = null;

    _spawnSnake();
    _spawnFood();
  }

  void _spawnSnake() {
    final startX = gridWidth ~/ 2;
    final startY = gridHeight ~/ 2;

    snake = Snake(
      initialSegments: [
        Point(startX, startY),
        Point(startX - 1, startY),
        Point(startX - 2, startY),
      ],
      game: this,
    );
    add(snake);
  }

  void _spawnFood() {
    Point<int> pos;
    do {
      pos = Point(_random.nextInt(gridWidth), _random.nextInt(gridHeight));
    } while (snake.occupies(pos));

    food = Food(gridPosition: pos, game: this);
    add(food);
  }

  /// Respawn snake after losing a life — keeps score, resets position.
  void respawn() {
    removeAll(children.where((c) => c is Snake || c is Food || c is PowerUp));
    _tickTimer = 0;
    currentDirection = Direction.right;
    _directionQueue.clear();
    gameState = GameState.playing;
    activeBuffs.clear();
    _currentPowerUp = null;
    shieldFlashTimer = 0;
    _spawnSnake();
    _spawnFood();
  }

  void restart() {
    removeAll(children.where((c) => c is Snake || c is Food || c is PowerUp));
    _startNewGame();
    onScoreChanged(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    // Update buff durations
    _updateBuffs(dt);

    // Shield flash decay
    if (shieldFlashTimer > 0) {
      shieldFlashTimer -= dt;
      if (shieldFlashTimer < 0) shieldFlashTimer = 0;
    }

    // Spawn power-ups periodically (non-Classic only)
    if (_powerUpsEnabled) {
      _powerUpSpawnTimer += dt;
      if (_powerUpSpawnTimer >= _nextPowerUpSpawnTime) {
        _powerUpSpawnTimer = 0;
        _nextPowerUpSpawnTime = 20.0 + _random.nextDouble() * 10.0;
        _trySpawnPowerUp();
      }

      // Magnet effect: move food toward snake head
      if (activeBuffs.containsKey(PowerUpType.magnet)) {
        _applyMagnetEffect();
      }
    }

    _tickTimer += dt;
    final interval = _effectiveTickInterval();
    if (_tickTimer >= interval) {
      _tickTimer = 0;
      _tick();
    }
  }

  double _effectiveTickInterval() {
    double interval = mode.tickInterval(score);
    if (activeBuffs.containsKey(PowerUpType.speed)) {
      interval *= 0.6; // 40% faster
    }
    if (activeBuffs.containsKey(PowerUpType.slow)) {
      interval *= 1.5; // 50% slower
    }
    return interval;
  }

  void _updateBuffs(double dt) {
    final expired = <PowerUpType>[];
    for (final entry in activeBuffs.entries) {
      activeBuffs[entry.key] = entry.value - dt;
      if (activeBuffs[entry.key]! <= 0) {
        expired.add(entry.key);
      }
    }
    for (final type in expired) {
      activeBuffs.remove(type);
    }
  }

  void _trySpawnPowerUp() {
    if (_currentPowerUp != null) return; // only one at a time

    Point<int> pos;
    int attempts = 0;
    do {
      pos = Point(_random.nextInt(gridWidth), _random.nextInt(gridHeight));
      attempts++;
      if (attempts > 100) return;
    } while (snake.occupies(pos) ||
        (pos.x == food.gridPosition.x && pos.y == food.gridPosition.y));

    final types = PowerUpType.values;
    final type = types[_random.nextInt(types.length)];

    _currentPowerUp = PowerUp(gridPosition: pos, type: type, game: this);
    add(_currentPowerUp!);
  }

  void removePowerUp(PowerUp powerUp) {
    if (_currentPowerUp == powerUp) {
      _currentPowerUp = null;
    }
    if (powerUp.isMounted) {
      remove(powerUp);
    }
  }

  void _collectPowerUp(PowerUp powerUp) {
    switch (powerUp.type) {
      case PowerUpType.speed:
        activeBuffs[PowerUpType.speed] = 5.0;
      case PowerUpType.shield:
        activeBuffs[PowerUpType.shield] = 999.0; // lasts until used
      case PowerUpType.magnet:
        activeBuffs[PowerUpType.magnet] = 5.0;
      case PowerUpType.slow:
        activeBuffs[PowerUpType.slow] = 5.0;
      case PowerUpType.shrink:
        _applyShrink();
    }
    removePowerUp(powerUp);
  }

  void _applyShrink() {
    // Remove up to 2 tail segments (keep at least 1 segment — the head)
    int toRemove = min(2, snake.segments.length - 1);
    for (int i = 0; i < toRemove; i++) {
      snake.segments.removeLast();
    }
  }

  void _applyMagnetEffect() {
    if (snake.segments.isEmpty) return;
    final head = snake.segments.first;
    final fx = food.gridPosition.x;
    final fy = food.gridPosition.y;
    final dx = head.x - fx;
    final dy = head.y - fy;

    // Only attract if within 6 cells (Manhattan distance)
    if (dx.abs() + dy.abs() > 6) return;

    int newX = fx;
    int newY = fy;
    if (dx.abs() > dy.abs()) {
      newX += dx.sign;
    } else if (dy != 0) {
      newY += dy.sign;
    }

    // Bounds check
    newX = newX.clamp(0, gridWidth - 1);
    newY = newY.clamp(0, gridHeight - 1);

    final newPos = Point(newX, newY);
    if (!snake.occupies(newPos)) {
      food.gridPosition = newPos;
    }
  }

  void _tick() {
    // Dequeue next buffered input
    if (_directionQueue.isNotEmpty) {
      currentDirection = _directionQueue.removeFirst();
    }

    final head = snake.segments.first;
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

    // Wall collision
    if (_wallsKill) {
      if (newHead.x < 0 ||
          newHead.x >= gridWidth ||
          newHead.y < 0 ||
          newHead.y >= gridHeight) {
        if (_tryShieldAbsorb()) return;
        _die();
        return;
      }
    } else {
      // Wrap around
      newHead = Point(
        (newHead.x + gridWidth) % gridWidth,
        (newHead.y + gridHeight) % gridHeight,
      );
    }

    // Self collision
    if (snake.occupies(newHead)) {
      if (_tryShieldAbsorb()) return;
      _die();
      return;
    }

    // Check food
    final ate = newHead.x == food.gridPosition.x &&
        newHead.y == food.gridPosition.y;

    snake.move(newHead, grow: ate);

    if (ate) {
      score += mode.pointsPerFood(score);
      onScoreChanged(score);
      remove(food);
      _spawnFood();
      HapticFeedback.selectionClick();
    }

    // Check power-up collection
    if (_currentPowerUp != null &&
        newHead.x == _currentPowerUp!.gridPosition.x &&
        newHead.y == _currentPowerUp!.gridPosition.y) {
      _collectPowerUp(_currentPowerUp!);
    }
  }

  bool _tryShieldAbsorb() {
    if (activeBuffs.containsKey(PowerUpType.shield)) {
      activeBuffs.remove(PowerUpType.shield);
      shieldFlashTimer = 0.5;
      return true;
    }
    return false;
  }

  void _die() {
    gameState = GameState.gameOver;
    HapticFeedback.heavyImpact();
    onGameOver();
  }

  void togglePause() {
    if (gameState == GameState.playing) {
      gameState = GameState.paused;
    } else if (gameState == GameState.paused) {
      gameState = GameState.playing;
    }
  }

  bool get isPaused => gameState == GameState.paused;

  void changeDirection(Direction dir) {
    // Check against the last queued direction (or current if queue empty)
    final lastDir = _directionQueue.isNotEmpty
        ? _directionQueue.last
        : currentDirection;

    // Prevent 180-degree turns
    if (dir == Direction.up && lastDir == Direction.down) return;
    if (dir == Direction.down && lastDir == Direction.up) return;
    if (dir == Direction.left && lastDir == Direction.right) return;
    if (dir == Direction.right && lastDir == Direction.left) return;

    // Don't queue duplicate directions
    if (dir == lastDir) return;

    // Buffer up to N inputs
    if (_directionQueue.length < _maxQueuedInputs) {
      _directionQueue.add(dir);
    }

    // If queue was empty, trigger early tick for responsiveness
    if (_directionQueue.length == 1) {
      final interval = _effectiveTickInterval();
      if (_tickTimer > interval * 0.3) {
        _tickTimer = interval;
      }
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
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        togglePause();
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw active buff indicators near top-left of board
    if (activeBuffs.isEmpty) return;

    double x = boardOffset.x + 4;
    final y = boardOffset.y - 18;

    for (final entry in activeBuffs.entries) {
      final color = _buffColor(entry.key);

      // Background pill
      final bgPaint = Paint()..color = color.withOpacity(0.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 40, 14),
          const Radius.circular(7),
        ),
        bgPaint,
      );

      // Icon dot
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(x + 8, y + 7), 4, dotPaint);

      // Time text
      final remaining = entry.value > 100 ? '∞' : '${entry.value.ceil()}s';
      final tp = TextPainter(
        text: TextSpan(
          text: remaining,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 16, y + 2));

      x += 46;
    }
  }

  Color _buffColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.speed:
        return Colors.yellow;
      case PowerUpType.shield:
        return Colors.blue;
      case PowerUpType.magnet:
        return Colors.purple;
      case PowerUpType.slow:
        return Colors.orange;
      case PowerUpType.shrink:
        return Colors.red;
    }
  }

}
