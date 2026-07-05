import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/trail_mode.dart';
import '../components/trail_snake.dart';
import '../components/ai_snake.dart';

/// Re-export Direction so other files can import it from here.
enum Direction { up, down, left, right }

enum TrailGameState { playing, paused, gameOver }

class TrailGame extends FlameGame with KeyboardEvents {
  final TrailMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  TrailGameState gameState = TrailGameState.playing;
  int score = 0;
  double _tickTimer = 0;
  double _survivalTime = 0;
  final Random _random = Random();

  // Grid dimensions
  int gridWidth = 20;
  int gridHeight = 28;
  late double cellSize;
  late Vector2 boardOffset;

  late TrailSnake player;
  final List<TrailSnake> aiSnakes = [];
  final List<AiSnake> aiBrains = [];

  // Arena shrinking
  int _shrinkMargin = 0;
  double _shrinkTimer = 0;
  static const double _shrinkInterval = 15.0; // Shrink every 15 seconds
  static const int _maxShrink = 4; // Max cells to shrink from each side

  TrailGame({
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
    score = 0;
    _tickTimer = 0;
    _survivalTime = 0;
    _shrinkMargin = 0;
    _shrinkTimer = 0;
    gameState = TrailGameState.playing;
    aiSnakes.clear();
    aiBrains.clear();

    // Player starts bottom-left area, heading right
    player = TrailSnake(
      game: this,
      initialSegments: [
        Point(5, gridHeight - 6),
        Point(4, gridHeight - 6),
        Point(3, gridHeight - 6),
      ],
      color: mode.snakeColor,
      trailColor: mode.snakeColor.withAlpha(80),
      direction: Direction.right,
    );
    add(player);

    // Spawn first AI opponent at top-right, heading left
    _spawnAi();
  }

  void _spawnAi() {
    // Find a safe spawn position
    Point<int> spawnHead;
    Direction spawnDir;

    // Try several random positions
    int attempts = 0;
    while (true) {
      attempts++;
      final margin = _shrinkMargin + 3;
      final x = margin + _random.nextInt(max(1, gridWidth - margin * 2));
      final y = margin + _random.nextInt(max(1, gridHeight - margin * 2));
      spawnHead = Point(x, y);

      // Check that the spawn area is clear
      if (!isTrailAt(spawnHead) &&
          !isTrailAt(Point(x - 1, y)) &&
          !isTrailAt(Point(x - 2, y))) {
        spawnDir = Direction.right;
        break;
      }
      if (!isTrailAt(spawnHead) &&
          !isTrailAt(Point(x + 1, y)) &&
          !isTrailAt(Point(x + 2, y))) {
        spawnDir = Direction.left;
        break;
      }

      if (attempts > 100) {
        // Can't find safe spot, try a fixed position
        spawnHead = Point(gridWidth - 5, 5);
        spawnDir = Direction.left;
        break;
      }
    }

    final aiTrailSnake = TrailSnake(
      game: this,
      initialSegments: spawnDir == Direction.right
          ? [spawnHead, Point(spawnHead.x - 1, spawnHead.y), Point(spawnHead.x - 2, spawnHead.y)]
          : [spawnHead, Point(spawnHead.x + 1, spawnHead.y), Point(spawnHead.x + 2, spawnHead.y)],
      color: mode.enemyColor,
      trailColor: mode.enemyColor.withAlpha(80),
      direction: spawnDir,
    );

    final aiBrain = AiSnake(game: this, snake: aiTrailSnake);

    aiSnakes.add(aiTrailSnake);
    aiBrains.add(aiBrain);
    add(aiTrailSnake);
  }

  void restart() {
    removeAll(children.whereType<TrailSnake>());
    _startNewGame();
    onScoreChanged(0);
  }

  /// Check if any trail (player or AI) occupies this position.
  bool isTrailAt(Point<int> pos) {
    if (player.occupiesTrail(pos)) return true;
    for (final ai in aiSnakes) {
      if (ai.occupiesTrail(pos)) return true;
    }
    return false;
  }

  /// Check if position is inside the (possibly shrunken) arena.
  bool isInBounds(Point<int> pos) {
    return pos.x >= _shrinkMargin &&
        pos.x < gridWidth - _shrinkMargin &&
        pos.y >= _shrinkMargin &&
        pos.y < gridHeight - _shrinkMargin;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != TrailGameState.playing) return;

    _survivalTime += dt;

    // Update score based on survival time
    final newScore = (_survivalTime * 10).toInt();
    if (newScore != score) {
      score = newScore;
      onScoreChanged(score);
    }

    // Arena shrinking
    _shrinkTimer += dt;
    if (_shrinkTimer >= _shrinkInterval && _shrinkMargin < _maxShrink) {
      _shrinkTimer = 0;
      _shrinkMargin++;

      // Kill anything now outside bounds
      _checkBoundsAfterShrink();
    }

    _tickTimer += dt;
    if (_tickTimer >= mode.tickInterval(score)) {
      _tickTimer = 0;
      _tick();
    }
  }

  void _checkBoundsAfterShrink() {
    // Check player
    if (!isInBounds(player.segments.first)) {
      _playerDies();
      return;
    }

    // Check AIs
    for (int i = aiSnakes.length - 1; i >= 0; i--) {
      if (!isInBounds(aiSnakes[i].segments.first)) {
        _killAi(i);
      }
    }
  }

  void _tick() {
    // AI thinks before anyone moves
    for (final brain in aiBrains) {
      if (brain.snake.alive) {
        brain.think();
      }
    }

    // Peek where everyone wants to go (before any moves)
    final playerNewHead = player.peekNextHead();

    // Check player collision with walls
    if (!isInBounds(playerNewHead)) {
      _playerDies();
      return;
    }

    // Check player collision with any existing trail (own or AI)
    if (isTrailAt(playerNewHead)) {
      _playerDies();
      return;
    }

    // Player move is safe — commit it
    player.advance(playerNewHead);

    // Move AIs
    for (int i = aiSnakes.length - 1; i >= 0; i--) {
      final ai = aiSnakes[i];
      if (!ai.alive) continue;

      final aiNewHead = ai.peekNextHead();

      // Wall check
      if (!isInBounds(aiNewHead)) {
        _killAi(i);
        continue;
      }

      // Trail collision (any trail including own, player's, other AIs')
      if (isTrailAt(aiNewHead)) {
        _killAi(i);
        continue;
      }

      // Head-on collision with player
      if (playerNewHead.x == aiNewHead.x && playerNewHead.y == aiNewHead.y) {
        _killAi(i);
        _playerDies();
        return;
      }

      // Safe — commit move
      ai.advance(aiNewHead);
    }

    // Spawn new AI if all are dead
    if (aiSnakes.where((s) => s.alive).isEmpty) {
      _spawnAi();
      // After enough survival, spawn two
      if (_survivalTime > 30) {
        _spawnAi();
      }
    }
  }

  void _killAi(int index) {
    aiSnakes[index].alive = false;
    // Trail remains — the snake body stops moving but its trail persists
  }

  void _playerDies() {
    player.alive = false;
    gameState = TrailGameState.gameOver;
    onGameOver();
  }

  void changeDirection(Direction dir) {
    player.changeDirection(dir);
  }

  void togglePause() {
    if (gameState == TrailGameState.playing) {
      gameState = TrailGameState.paused;
    } else if (gameState == TrailGameState.paused) {
      gameState = TrailGameState.playing;
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
    _renderArena(canvas);
  }

  void _renderArena(Canvas canvas) {
    final cs = cellSize;

    // Draw grid lines (dark)
    if (mode.showGrid) {
      final gridPaint = Paint()
        ..color = mode.gridColor
        ..strokeWidth = 0.5;

      final left = boardOffset.x + _shrinkMargin * cs;
      final top = boardOffset.y + _shrinkMargin * cs;
      final right = boardOffset.x + (gridWidth - _shrinkMargin) * cs;
      final bottom = boardOffset.y + (gridHeight - _shrinkMargin) * cs;

      for (int x = _shrinkMargin; x <= gridWidth - _shrinkMargin; x++) {
        canvas.drawLine(
          Offset(boardOffset.x + x * cs, top),
          Offset(boardOffset.x + x * cs, bottom),
          gridPaint,
        );
      }
      for (int y = _shrinkMargin; y <= gridHeight - _shrinkMargin; y++) {
        canvas.drawLine(
          Offset(left, boardOffset.y + y * cs),
          Offset(right, boardOffset.y + y * cs),
          gridPaint,
        );
      }
    }

    // Draw arena border with glow
    final borderRect = Rect.fromLTWH(
      boardOffset.x + _shrinkMargin * cs,
      boardOffset.y + _shrinkMargin * cs,
      (gridWidth - _shrinkMargin * 2) * cs,
      (gridHeight - _shrinkMargin * 2) * cs,
    );

    final borderPaint = Paint()
      ..color = mode.borderGlowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(borderRect, borderPaint);

    // Glow effect on border
    final glowPaint = Paint()
      ..color = mode.borderGlowColor.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    canvas.drawRect(borderRect, glowPaint);

    // Draw "dead zone" outside the shrunken arena
    if (_shrinkMargin > 0) {
      final deadPaint = Paint()..color = const Color(0xFF1A0000);
      // Top strip
      canvas.drawRect(
        Rect.fromLTWH(boardOffset.x, boardOffset.y, gridWidth * cs, _shrinkMargin * cs),
        deadPaint,
      );
      // Bottom strip
      canvas.drawRect(
        Rect.fromLTWH(
          boardOffset.x,
          boardOffset.y + (gridHeight - _shrinkMargin) * cs,
          gridWidth * cs,
          _shrinkMargin * cs,
        ),
        deadPaint,
      );
      // Left strip
      canvas.drawRect(
        Rect.fromLTWH(
          boardOffset.x,
          boardOffset.y + _shrinkMargin * cs,
          _shrinkMargin * cs,
          (gridHeight - _shrinkMargin * 2) * cs,
        ),
        deadPaint,
      );
      // Right strip
      canvas.drawRect(
        Rect.fromLTWH(
          boardOffset.x + (gridWidth - _shrinkMargin) * cs,
          boardOffset.y + _shrinkMargin * cs,
          _shrinkMargin * cs,
          (gridHeight - _shrinkMargin * 2) * cs,
        ),
        deadPaint,
      );
    }
  }
}
