import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/game_mode.dart';
import '../components/snake.dart';
import '../components/food.dart';
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
  Direction _nextDirection = Direction.right;
  Direction currentDirection = Direction.right;
  final Random _random = Random();

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
    _nextDirection = Direction.right;
    gameState = GameState.playing;

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
    removeAll(children.where((c) => c is Snake || c is Food));
    _tickTimer = 0;
    currentDirection = Direction.right;
    _nextDirection = Direction.right;
    gameState = GameState.playing;
    _spawnSnake();
    _spawnFood();
  }

  void restart() {
    removeAll(children.where((c) => c is Snake || c is Food));
    _startNewGame();
    onScoreChanged(0);
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
    }
  }

  void _die() {
    gameState = GameState.gameOver;
    onGameOver();
  }

  void changeDirection(Direction dir) {
    // Prevent 180-degree turns
    if (dir == Direction.up && currentDirection == Direction.down) return;
    if (dir == Direction.down && currentDirection == Direction.up) return;
    if (dir == Direction.left && currentDirection == Direction.right) return;
    if (dir == Direction.right && currentDirection == Direction.left) return;
    _nextDirection = dir;
    // Reduce input lag: if we're past half the tick interval, trigger early
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

  Vector2 gridToScreen(Point<int> pos) {
    return Vector2(
      boardOffset.x + pos.x * cellSize,
      boardOffset.y + pos.y * cellSize,
    );
  }
}
