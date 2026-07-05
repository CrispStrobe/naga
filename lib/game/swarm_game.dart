import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/swarm_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Centipede-inspired mode — enemies march down in formation, eat them.
class SwarmGame extends FlameGame with KeyboardEvents {
  final SwarmMode mode;
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

  // Enemies — rows of bugs marching down
  List<_Enemy> enemies = [];
  double _enemyTickTimer = 0;
  double _enemyTickInterval = 0.6;
  int _enemyDirection = 1; // 1 = right, -1 = left
  int _wave = 1;

  // Power-ups dropped by enemies
  List<Point<int>> powerUps = [];

  final Random _random = Random();

  SwarmGame({
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
    _wave = 1;
    gameState = GameState.playing;
    currentDirection = Direction.right;
    _nextDirection = Direction.right;

    // Snake starts at bottom center
    final startX = gridWidth ~/ 2;
    final startY = gridHeight - 3;
    snakeSegments = [
      Point(startX, startY),
      Point(startX - 1, startY),
      Point(startX - 2, startY),
    ];

    _spawnWave();
  }

  void _spawnWave() {
    enemies.clear();
    powerUps.clear();
    _enemyDirection = 1;
    _enemyTickInterval = max(0.2, 0.6 - _wave * 0.05);

    // Spawn rows of enemies
    final rows = min(3 + _wave ~/ 2, 6);
    final cols = min(8 + _wave, 16);
    final startX = (gridWidth - cols) ~/ 2;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        enemies.add(_Enemy(
          position: Point(startX + col, 2 + row * 2),
          color: _enemyColorForRow(row),
          points: (rows - row) * 10, // top rows worth more
        ));
      }
    }
  }

  Color _enemyColorForRow(int row) {
    const colors = [
      Color(0xFFFF1744),
      Color(0xFFFF9100),
      Color(0xFFFFEA00),
      Color(0xFF00E676),
      Color(0xFF00B0FF),
      Color(0xFFD500F9),
    ];
    return colors[row % colors.length];
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    // Snake tick
    _tickTimer += dt;
    if (_tickTimer >= mode.tickInterval(score)) {
      _tickTimer = 0;
      _tickSnake();
    }

    // Enemy tick
    _enemyTickTimer += dt;
    if (_enemyTickTimer >= _enemyTickInterval) {
      _enemyTickTimer = 0;
      _tickEnemies();
    }
  }

  void _tickSnake() {
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

    // Wrap horizontally, block at top/bottom
    newHead = Point(
      (newHead.x + gridWidth) % gridWidth,
      newHead.y.clamp(0, gridHeight - 1),
    );

    // Self collision
    if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
      return; // just don't move
    }

    // Head-first collision with enemies = eat them (score points)
    final hitEnemy = enemies.where(
      (e) => e.position.x == newHead.x && e.position.y == newHead.y,
    ).toList();

    bool ate = false;
    for (final enemy in hitEnemy) {
      enemies.remove(enemy);
      score += enemy.points;
      ate = true;
      onScoreChanged(score);
      // Sometimes drop power-up
      if (_random.nextDouble() < 0.2) {
        powerUps.add(enemy.position);
      }
    }

    // Check power-up collection
    powerUps.removeWhere((p) {
      if (p.x == newHead.x && p.y == newHead.y) {
        score += 25;
        onScoreChanged(score);
        ate = true; // grow
        return true;
      }
      return false;
    });

    // Move snake — fixed length unless ate something
    snakeSegments.insert(0, newHead);
    if (!ate) {
      snakeSegments.removeLast();
    }

    // All enemies killed — next wave
    if (enemies.isEmpty) {
      _wave++;
      _spawnWave();
    }
  }

  void _tickEnemies() {
    if (enemies.isEmpty) return;

    // Check if any enemy is at the edge
    bool hitEdge = false;
    for (final enemy in enemies) {
      if (_enemyDirection > 0 && enemy.position.x >= gridWidth - 1) {
        hitEdge = true;
        break;
      }
      if (_enemyDirection < 0 && enemy.position.x <= 0) {
        hitEdge = true;
        break;
      }
    }

    if (hitEdge) {
      // Move down one row and reverse direction
      for (final enemy in enemies) {
        enemy.position = Point(enemy.position.x, enemy.position.y + 1);
      }
      _enemyDirection *= -1;

      // Check if any enemy reached snake row — game over
      for (final enemy in enemies) {
        if (enemy.position.y >= gridHeight - 2) {
          _die();
          return;
        }
      }
    } else {
      // Move sideways
      for (final enemy in enemies) {
        enemy.position = Point(
          enemy.position.x + _enemyDirection,
          enemy.position.y,
        );
      }
    }

    // Check if enemy marched down onto snake body (side hit = death)
    // Enemies landing on the head are eaten; enemies on body segments kill.
    final head = snakeSegments.first;
    final eatenByHead = enemies.where(
      (e) => e.position.x == head.x && e.position.y == head.y,
    ).toList();
    for (final enemy in eatenByHead) {
      enemies.remove(enemy);
      score += enemy.points;
      onScoreChanged(score);
    }

    // Enemies landing on body (not head) = death
    for (final enemy in enemies) {
      for (int i = 1; i < snakeSegments.length; i++) {
        if (enemy.position.x == snakeSegments[i].x &&
            enemy.position.y == snakeSegments[i].y) {
          _die();
          return;
        }
      }
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
  }

  void togglePause() {
    if (gameState == GameState.playing) {
      gameState = GameState.paused;
    } else if (gameState == GameState.paused) {
      gameState = GameState.playing;
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        togglePause();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.keyW) {
        changeDirection(Direction.up);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.keyS) {
        changeDirection(Direction.down);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.keyA) {
        changeDirection(Direction.left);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.keyD) {
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;

    // Draw border
    final borderPaint = Paint()
      ..color = mode.snakeColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(boardOffset.x, boardOffset.y, cs * gridWidth, cs * gridHeight),
      borderPaint,
    );

    // Draw enemies
    for (final enemy in enemies) {
      final sp = _gridToScreen(enemy.position);
      final paint = Paint()..color = enemy.color;
      // Bug shape: rounded rect with antennae
      final bodyRect = Rect.fromLTWH(sp.x + cs * 0.1, sp.y + cs * 0.2, cs * 0.8, cs * 0.65);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, Radius.circular(cs * 0.15)),
        paint,
      );
      // Eyes
      final eyePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(sp.x + cs * 0.35, sp.y + cs * 0.35), cs * 0.08, eyePaint);
      canvas.drawCircle(Offset(sp.x + cs * 0.65, sp.y + cs * 0.35), cs * 0.08, eyePaint);
      // Antennae
      final antPaint = Paint()
        ..color = enemy.color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(sp.x + cs * 0.35, sp.y + cs * 0.2),
        Offset(sp.x + cs * 0.25, sp.y + cs * 0.05),
        antPaint,
      );
      canvas.drawLine(
        Offset(sp.x + cs * 0.65, sp.y + cs * 0.2),
        Offset(sp.x + cs * 0.75, sp.y + cs * 0.05),
        antPaint,
      );
    }

    // Draw power-ups
    final puPaint = Paint()..color = mode.foodColor;
    for (final pu in powerUps) {
      final sp = _gridToScreen(pu);
      canvas.drawCircle(Offset(sp.x + cs / 2, sp.y + cs / 2), cs * 0.25, puPaint);
    }

    // Draw snake
    final snakePaint = Paint()..color = mode.snakeColor;
    for (final seg in snakeSegments) {
      final sp = _gridToScreen(seg);
      canvas.drawRect(
        Rect.fromLTWH(sp.x + cs * 0.05, sp.y + cs * 0.05, cs * 0.9, cs * 0.9),
        snakePaint,
      );
    }

    // Wave indicator
    final tp = TextPainter(
      text: TextSpan(
        text: 'WAVE $_wave',
        style: TextStyle(color: mode.snakeColor.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(boardOffset.x + gridWidth * cs - tp.width - 4, boardOffset.y - 16));
  }
}

class _Enemy {
  Point<int> position;
  final Color color;
  final int points;

  _Enemy({required this.position, required this.color, required this.points});
}
