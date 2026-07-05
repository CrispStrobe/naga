import 'dart:collection';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/maze_mode.dart';
import '../components/maze.dart';
import '../components/ghost.dart';
import 'snake_game.dart' show Direction, GameState;

/// Maze Hunter game — Pac-Man inspired snake navigating a maze.
class MazeHunterGame extends FlameGame with KeyboardEvents {
  final MazeMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  late Maze maze;
  late List<Ghost> ghosts;

  // Snake state — fixed length, does NOT grow on dots
  List<Point<int>> snakeSegments = [];
  static const int _snakeLength = 4;
  Direction currentDirection = Direction.right;
  final Queue<Direction> _directionQueue = Queue<Direction>();
  static const int _maxQueuedInputs = 4;

  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;

  // Ghost movement at a slower tick
  double _ghostTickTimer = 0;
  static const double _ghostTickInterval = 0.3;

  // Power mode
  bool _powerMode = false;
  double _powerTimer = 0;
  static const double _powerDuration = 6.0;

  int _level = 1;

  static const int gridWidth = 20;
  static const int gridHeight = 28;
  late double cellSize;
  late Vector2 boardOffset;

  MazeHunterGame({
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
    removeAll(children);

    score = 0;
    _tickTimer = 0;
    _ghostTickTimer = 0;
    _powerMode = false;
    _powerTimer = 0;
    _level = 1;
    currentDirection = Direction.right;
    _directionQueue.clear();
    gameState = GameState.playing;

    _buildLevel();
  }

  void respawn() {
    // Reset snake position, keep score
    if (maze.ghostStarts.isNotEmpty) {
      snakeSegments = [maze.snakeStart];
      for (int i = 1; i < _snakeLength; i++) {
        snakeSegments.add(Point(maze.snakeStart.x - i, maze.snakeStart.y));
      }
    }
    currentDirection = Direction.right;
    _directionQueue.clear();
    _powerMode = false;
    gameState = GameState.playing;
  }

  void _buildLevel() {
    removeAll(children);

    maze = Maze(
      wallColor: mode.wallColor,
      dotColor: mode.foodColor,
      powerPelletColor: mode.powerPelletColor,
      getCellSize: () => cellSize,
      getBoardOffset: () => boardOffset,
    );
    maze.setLevel(_level - 1);
    add(maze);

    maze.onLoad().then((_) {
      // Snake starts at maze start, fixed length
      snakeSegments = [maze.snakeStart];
      for (int i = 1; i < _snakeLength; i++) {
        snakeSegments.add(Point(maze.snakeStart.x - i, maze.snakeStart.y));
      }

      currentDirection = Direction.right;
      _directionQueue.clear();

      // Create ghosts at their start positions (which are now in open corridors)
      ghosts = [];
      for (int i = 0; i < 4; i++) {
        final startPos = i < maze.ghostStarts.length
            ? maze.ghostStarts[i]
            : Point(8 + i, 10);
        final ghost = Ghost(
          normalColor: MazeMode.ghostColors[i],
          maze: maze,
          startPosition: startPos,
          getCellSize: () => cellSize,
          getBoardOffset: () => boardOffset,
        );
        ghosts.add(ghost);
        add(ghost);
      }
    });
  }

  void restart() {
    _startNewGame();
    onScoreChanged(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;
    if (snakeSegments.isEmpty) return;

    // Power mode timer
    if (_powerMode) {
      _powerTimer -= dt;
      if (_powerTimer <= 0) {
        _powerMode = false;
        for (final ghost in ghosts) {
          ghost.setVulnerable(false);
        }
      }
    }

    // Snake tick
    _tickTimer += dt;
    if (_tickTimer >= mode.tickInterval(score)) {
      _tickTimer = 0;
      _tick();
    }

    // Ghost tick
    _ghostTickTimer += dt;
    final ghostSpeed =
        _powerMode ? _ghostTickInterval * 1.8 : _ghostTickInterval;
    if (_ghostTickTimer >= ghostSpeed) {
      _ghostTickTimer = 0;
      _moveGhosts();
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

    // Wall — just block, don't die
    if (maze.isWall(newHead.x, newHead.y)) {
      return;
    }

    // Self collision
    if (_snakeOccupies(newHead)) {
      _die();
      return;
    }

    // Collect dot (score only, no growth)
    if (maze.collectDot(newHead)) {
      score += 10;
      onScoreChanged(score);
    }

    // Collect power pellet
    if (maze.collectPowerPellet(newHead)) {
      score += 10;
      onScoreChanged(score);
      _activatePowerMode();
    }

    // Move snake — always remove tail (fixed length)
    snakeSegments.insert(0, newHead);
    snakeSegments.removeLast();

    // Check ghost collision
    _checkGhostCollision();

    // All dots collected — next level
    if (maze.allDotsCollected) {
      _nextLevel();
    }
  }

  void _moveGhosts() {
    for (final ghost in ghosts) {
      ghost.move();
    }
    _checkGhostCollision();
  }

  void _checkGhostCollision() {
    if (snakeSegments.isEmpty) return;
    final head = snakeSegments.first;

    for (final ghost in ghosts) {
      if (ghost.isEaten) continue;
      if (ghost.gridPosition.x == head.x && ghost.gridPosition.y == head.y) {
        if (_powerMode && ghost.isVulnerable) {
          ghost.eat();
          score += 50;
          onScoreChanged(score);
        } else if (!ghost.isVulnerable) {
          _die();
          return;
        }
      }
    }
  }

  void _activatePowerMode() {
    _powerMode = true;
    _powerTimer = _powerDuration;
    for (final ghost in ghosts) {
      if (!ghost.isEaten) ghost.setVulnerable(true);
    }
  }

  void _nextLevel() {
    _level++;
    _buildLevel();
  }

  void _die() {
    gameState = GameState.gameOver;
    onGameOver();
  }

  bool _snakeOccupies(Point<int> pos) {
    return snakeSegments.any((s) => s.x == pos.x && s.y == pos.y);
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (snakeSegments.isEmpty) return;

    final paint = Paint()..color = mode.snakeColor;
    final cs = cellSize;
    final inset = cs * 0.05;

    for (final segment in snakeSegments) {
      final screenPos = gridToScreen(segment);
      final rect = Rect.fromLTWH(
        screenPos.x + inset,
        screenPos.y + inset,
        cs - inset * 2,
        cs - inset * 2,
      );
      canvas.drawRect(rect, paint);
    }

    // Eyes on head
    if (snakeSegments.isNotEmpty) {
      _drawSnakeEyes(canvas);
    }

    // Power mode indicator
    if (_powerMode) {
      _drawPowerIndicator(canvas);
    }

    // Level indicator
    _drawLevelIndicator(canvas);
  }

  void _drawSnakeEyes(Canvas canvas) {
    final head = snakeSegments.first;
    final screenPos = gridToScreen(head);
    final cs = cellSize;
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;
    final eyeRadius = cs * 0.12;
    final pupilRadius = cs * 0.06;

    final cx = screenPos.x + cs / 2;
    final cy = screenPos.y + cs / 2;

    double e1x, e1y, e2x, e2y;
    switch (currentDirection) {
      case Direction.right:
        e1x = cx + cs * 0.15;  e1y = cy - cs * 0.15;
        e2x = cx + cs * 0.15;  e2y = cy + cs * 0.15;
      case Direction.left:
        e1x = cx - cs * 0.15;  e1y = cy - cs * 0.15;
        e2x = cx - cs * 0.15;  e2y = cy + cs * 0.15;
      case Direction.up:
        e1x = cx - cs * 0.15;  e1y = cy - cs * 0.15;
        e2x = cx + cs * 0.15;  e2y = cy - cs * 0.15;
      case Direction.down:
        e1x = cx - cs * 0.15;  e1y = cy + cs * 0.15;
        e2x = cx + cs * 0.15;  e2y = cy + cs * 0.15;
    }

    canvas.drawCircle(Offset(e1x, e1y), eyeRadius, eyePaint);
    canvas.drawCircle(Offset(e2x, e2y), eyeRadius, eyePaint);
    canvas.drawCircle(Offset(e1x, e1y), pupilRadius, pupilPaint);
    canvas.drawCircle(Offset(e2x, e2y), pupilRadius, pupilPaint);
  }

  void _drawPowerIndicator(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'POWER: ${_powerTimer.ceil()}s',
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(boardOffset.x + 4, boardOffset.y - 18));
  }

  void _drawLevelIndicator(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'LVL $_level',
        style: TextStyle(
          color: Colors.blue.shade200,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        boardOffset.x + gridWidth * cellSize - textPainter.width - 4,
        boardOffset.y - 16,
      ),
    );
  }
}
