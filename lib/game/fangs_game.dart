import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/fangs_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Breakout/Arkanoid-inspired mode — the snake moves freely in the bottom
/// 5 rows and bounces the ball to destroy blocks.
class FangsGame extends FlameGame with KeyboardEvents {
  final FangsMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  static const int gridWidth = 20;
  static const int gridHeight = 28;
  /// The snake is confined to the bottom 5 rows.
  static const int _snakeZoneMinY = gridHeight - 5; // y >= 23
  late double cellSize;
  late Vector2 boardOffset;

  // Snake — moves freely in 4 directions within the bottom zone
  List<Point<int>> snakeSegments = [];
  Direction currentDirection = Direction.right;
  Direction _nextDirection = Direction.right;
  GameState gameState = GameState.playing;
  int score = 0;
  double _snakeTickTimer = 0;

  // Ball
  late Point<int> _ballPos;
  int _ballDx = 1;
  int _ballDy = -1;
  double _ballTickTimer = 0;

  // Blocks
  List<_Block> blocks = [];
  int _level = 1;
  int _lives = 3;

  final Random _random = Random();

  FangsGame({
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
    _level = 1;
    _lives = 3;
    gameState = GameState.playing;
    currentDirection = Direction.right;
    _nextDirection = Direction.right;
    _resetSnake();
    _resetBall();
    _spawnBlocks();
  }

  void _resetSnake() {
    final startX = gridWidth ~/ 2 - 1;
    const startY = gridHeight - 3; // middle of the 5-row zone
    snakeSegments = [
      Point(startX, startY),
      Point(startX - 1, startY),
      Point(startX - 2, startY),
    ];
  }

  void _resetBall() {
    // Place ball just above the snake zone
    final head = snakeSegments.first;
    _ballPos = Point(head.x, _snakeZoneMinY - 2);
    _ballDx = _random.nextBool() ? 1 : -1;
    _ballDy = -1;
  }

  void _spawnBlocks() {
    blocks.clear();
    final rows = min(2 + _level, 7); // rows 2..8 max
    for (int row = 0; row < rows; row++) {
      final color = _blockColorForRow(row);
      for (int col = 1; col < gridWidth - 1; col++) {
        blocks.add(_Block(
          position: Point(col, 2 + row),
          color: color,
        ));
      }
    }
  }

  Color _blockColorForRow(int row) {
    const colors = [
      Color(0xFFFF1744),
      Color(0xFFFF9100),
      Color(0xFFFFEA00),
      Color(0xFF00E676),
      Color(0xFF00B0FF),
      Color(0xFFD500F9),
      Color(0xFFE040FB),
    ];
    return colors[row % colors.length];
  }

  // Ball moves faster than the snake to create tension
  double get _ballInterval {
    const base = 0.10;
    const fastest = 0.04;
    final speedUp = (_level - 1) * 0.008;
    return (base - speedUp).clamp(fastest, base);
  }

  double get _snakeInterval => mode.tickInterval(score);

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    // Snake tick
    _snakeTickTimer += dt;
    if (_snakeTickTimer >= _snakeInterval) {
      _snakeTickTimer = 0;
      _tickSnake();
    }

    // Ball tick
    _ballTickTimer += dt;
    if (_ballTickTimer >= _ballInterval) {
      _ballTickTimer = 0;
      _tickBall();
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

    // Clamp to play area horizontally and to the bottom 5 rows vertically
    if (newHead.x < 0 || newHead.x >= gridWidth) return;
    if (newHead.y < _snakeZoneMinY || newHead.y >= gridHeight) return;

    // No self-collision (optional: could add, but breakout paddle shouldn't die)
    if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) return;

    // Move: insert new head, remove tail (snake doesn't grow from movement)
    snakeSegments.insert(0, newHead);
    snakeSegments.removeLast();
  }

  void _growSnake() {
    // Add a segment at the tail
    final tail = snakeSegments.last;
    // Duplicate the tail position — next move will separate them
    snakeSegments.add(Point(tail.x, tail.y));
  }

  void _tickBall() {
    final nextX = _ballPos.x + _ballDx;
    final nextY = _ballPos.y + _ballDy;

    // Reflect off left/right walls
    if (nextX <= 0 || nextX >= gridWidth - 1) {
      _ballDx = -_ballDx;
    }

    // Reflect off top wall
    if (nextY <= 0) {
      _ballDy = -_ballDy;
    }

    // Ball passes below the play area — lose life
    if (nextY >= gridHeight - 1) {
      _lives--;
      if (_lives <= 0) {
        gameState = GameState.gameOver;
        onGameOver();
        return;
      }
      _resetBall();
      return;
    }

    // Check block collision at next position
    final nextPos = Point(_ballPos.x + _ballDx, _ballPos.y + _ballDy);
    final hitBlock = blocks.where(
      (b) => b.position.x == nextPos.x && b.position.y == nextPos.y,
    ).toList();

    if (hitBlock.isNotEmpty) {
      final int blocksBeforeCount = blocks.length;
      for (final block in hitBlock) {
        blocks.remove(block);
        score += 5;
        onScoreChanged(score);
      }

      // Determine reflection axis
      final sameRowBlock = blocks.any(
        (b) => b.position.x == _ballPos.x + _ballDx && b.position.y == _ballPos.y,
      );
      final sameColBlock = blocks.any(
        (b) => b.position.x == _ballPos.x && b.position.y == _ballPos.y + _ballDy,
      );

      if (sameRowBlock && !sameColBlock) {
        _ballDx = -_ballDx;
      } else if (sameColBlock && !sameRowBlock) {
        _ballDy = -_ballDy;
      } else {
        _ballDy = -_ballDy;
      }

      // Check if an entire row was cleared — grow the snake
      // A row is cleared when blocks were removed and fewer remain
      if (blocks.length < blocksBeforeCount) {
        // Check each row that had blocks removed — if the row is now empty, grow
        final clearedRows = <int>{};
        for (final block in hitBlock) {
          final rowY = block.position.y;
          final remaining = blocks.where((b) => b.position.y == rowY).length;
          if (remaining == 0) {
            clearedRows.add(rowY);
          }
        }
        for (final _ in clearedRows) {
          _growSnake();
        }
      }

      // All blocks cleared — next level
      if (blocks.isEmpty) {
        _level++;
        score += 50; // level clear bonus
        onScoreChanged(score);
        _growSnake(); // grow on level clear too
        _spawnBlocks();
        _resetBall();
        return;
      }
    }

    // Check snake body collision (ball bounces off any segment)
    final snakeHit = snakeSegments.any(
      (s) => s.x == nextPos.x && s.y == nextPos.y,
    );

    if (snakeHit) {
      _ballDy = -_ballDy;
      // Adjust horizontal direction based on which segment was hit relative to head
      final headX = snakeSegments.first.x;
      if (nextPos.x < headX - 1) {
        _ballDx = -1;
      } else if (nextPos.x > headX + 1) {
        _ballDx = 1;
      }
      // Otherwise keep current dx
    }

    // Apply movement
    _ballPos = Point(_ballPos.x + _ballDx, _ballPos.y + _ballDy);
  }

  void changeDirection(Direction dir) {
    // Prevent reversing direction
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
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        togglePause();
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
      Rect.fromLTWH(
          boardOffset.x, boardOffset.y, cs * gridWidth, cs * gridHeight),
      borderPaint,
    );

    // Draw snake zone divider line
    final zonePaint = Paint()
      ..color = mode.snakeColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final zoneY = boardOffset.y + _snakeZoneMinY * cs;
    canvas.drawLine(
      Offset(boardOffset.x, zoneY),
      Offset(boardOffset.x + gridWidth * cs, zoneY),
      zonePaint,
    );

    // Draw blocks
    for (final block in blocks) {
      final sp = _gridToScreen(block.position);
      final paint = Paint()..color = block.color;
      final blockRect = Rect.fromLTWH(
          sp.x + cs * 0.05, sp.y + cs * 0.05, cs * 0.9, cs * 0.9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(blockRect, Radius.circular(cs * 0.1)),
        paint,
      );
      // Highlight on top edge for 3D effect
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(blockRect.left + cs * 0.1, blockRect.top),
        Offset(blockRect.right - cs * 0.1, blockRect.top),
        highlightPaint,
      );
    }

    // Draw ball
    final ballScreen = _gridToScreen(_ballPos);
    final ballPaint = Paint()..color = mode.ballColor;
    canvas.drawCircle(
      Offset(ballScreen.x + cs / 2, ballScreen.y + cs / 2),
      cs * 0.35,
      ballPaint,
    );
    // Ball glow
    final glowPaint = Paint()
      ..color = mode.ballColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      Offset(ballScreen.x + cs / 2, ballScreen.y + cs / 2),
      cs * 0.45,
      glowPaint,
    );

    // Draw snake — head is distinct, body segments are connected
    for (int i = 0; i < snakeSegments.length; i++) {
      final seg = snakeSegments[i];
      final sp = _gridToScreen(seg);
      final isHead = i == 0;

      final snakePaint = Paint()
        ..color = isHead
            ? mode.snakeColor
            : mode.snakeColor.withOpacity(0.8);

      // Draw each segment as a solid rounded rect
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              sp.x + cs * 0.05, sp.y + cs * 0.05, cs * 0.9, cs * 0.9),
          Radius.circular(cs * 0.2),
        ),
        snakePaint,
      );

      // Head eyes
      if (isHead) {
        final eyePaint = Paint()..color = Colors.white;
        final eyeR = cs * 0.08;
        canvas.drawCircle(
          Offset(sp.x + cs * 0.35, sp.y + cs * 0.35),
          eyeR,
          eyePaint,
        );
        canvas.drawCircle(
          Offset(sp.x + cs * 0.65, sp.y + cs * 0.35),
          eyeR,
          eyePaint,
        );
      }
    }

    // HUD — level and lives
    final levelTp = TextPainter(
      text: TextSpan(
        text: 'LVL $_level',
        style: TextStyle(
          color: mode.snakeColor.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    levelTp.paint(
      canvas,
      Offset(boardOffset.x + gridWidth * cs - levelTp.width - 4,
          boardOffset.y - 16),
    );

    final livesTp = TextPainter(
      text: TextSpan(
        text: '\u2665 ' * _lives, // heart symbols for lives
        style: TextStyle(
          color: const Color(0xFFFF1744).withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    livesTp.paint(
      canvas,
      Offset(boardOffset.x + 4, boardOffset.y - 16),
    );
  }
}

class _Block {
  final Point<int> position;
  final Color color;

  _Block({required this.position, required this.color});
}
