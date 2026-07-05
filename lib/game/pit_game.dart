import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/pit_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Battle Royale — shrinking arena, multiple AI snakes, last one alive wins.
class PitGame extends FlameGame with KeyboardEvents {
  final PitMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  static const int gridWidth = 20;
  static const int gridHeight = 28;
  late double cellSize;
  late Vector2 boardOffset;

  // Player snake
  List<Point<int>> snakeSegments = [];
  Direction currentDirection = Direction.right;
  Direction _nextDirection = Direction.right;
  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;

  // AI snakes
  List<_AISnake> aiSnakes = [];

  // Danger zone — number of cells shrunk from each edge
  int _dangerInset = 0;
  double _shrinkTimer = 0;
  static const double _shrinkInterval = 15.0;

  // Food
  List<Point<int>> food = [];
  double _foodTimer = 0;
  static const double _foodInterval = 3.0;
  static const int _maxFood = 5;

  final Random _random = Random();

  PitGame({
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
    _dangerInset = 0;
    _shrinkTimer = 0;
    _foodTimer = 0;
    gameState = GameState.playing;
    currentDirection = Direction.right;
    _nextDirection = Direction.right;

    // Player starts at center
    final cx = gridWidth ~/ 2;
    final cy = gridHeight ~/ 2;
    snakeSegments = [
      Point(cx, cy),
      Point(cx - 1, cy),
      Point(cx - 2, cy),
    ];

    // Spawn AI snakes in corners / edges
    aiSnakes = [];
    final spawnPoints = [
      (Point(3, 3), Direction.right),
      (Point(gridWidth - 4, 3), Direction.left),
      (Point(3, gridHeight - 4), Direction.right),
      (Point(gridWidth - 4, gridHeight - 4), Direction.left),
      (Point(gridWidth ~/ 2, 3), Direction.down),
    ];
    for (int i = 0; i < spawnPoints.length; i++) {
      final (pos, dir) = spawnPoints[i];
      final dx = dir == Direction.left ? 1 : (dir == Direction.right ? -1 : 0);
      final dy = dir == Direction.up ? 1 : (dir == Direction.down ? -1 : 0);
      aiSnakes.add(_AISnake(
        segments: [
          pos,
          Point(pos.x + dx, pos.y + dy),
          Point(pos.x + dx * 2, pos.y + dy * 2),
        ],
        direction: dir,
        color: PitMode.enemyColors[i],
      ));
    }

    // Spawn initial food
    food.clear();
    for (int i = 0; i < 3; i++) {
      _spawnFood();
    }
  }

  bool _isInSafeZone(Point<int> p) {
    return p.x >= _dangerInset &&
        p.x < gridWidth - _dangerInset &&
        p.y >= _dangerInset &&
        p.y < gridHeight - _dangerInset;
  }

  bool _isOccupied(Point<int> p) {
    if (snakeSegments.any((s) => s.x == p.x && s.y == p.y)) return true;
    for (final ai in aiSnakes) {
      if (ai.segments.any((s) => s.x == p.x && s.y == p.y)) return true;
    }
    if (food.any((f) => f.x == p.x && f.y == p.y)) return true;
    return false;
  }

  void _spawnFood() {
    if (food.length >= _maxFood) return;
    final safeW = gridWidth - _dangerInset * 2;
    final safeH = gridHeight - _dangerInset * 2;
    if (safeW <= 0 || safeH <= 0) return;

    for (int attempt = 0; attempt < 50; attempt++) {
      final p = Point(
        _dangerInset + _random.nextInt(safeW),
        _dangerInset + _random.nextInt(safeH),
      );
      if (!_isOccupied(p)) {
        food.add(p);
        return;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    // Shrink timer
    _shrinkTimer += dt;
    if (_shrinkTimer >= _shrinkInterval) {
      _shrinkTimer = 0;
      final maxInset = min(gridWidth, gridHeight) ~/ 2 - 1;
      if (_dangerInset < maxInset) {
        _dangerInset++;
        // Kill any snake in the new danger zone
        _checkDangerZoneDeaths();
        // Remove food in danger zone
        food.removeWhere((f) => !_isInSafeZone(f));
      }
    }

    // Food spawn timer
    _foodTimer += dt;
    if (_foodTimer >= _foodInterval) {
      _foodTimer = 0;
      _spawnFood();
    }

    // Player tick
    _tickTimer += dt;
    if (_tickTimer >= mode.tickInterval(score)) {
      _tickTimer = 0;
      _tickPlayerSnake();
      _tickAISnakes();
    }
  }

  void _checkDangerZoneDeaths() {
    // Check player
    if (snakeSegments.isNotEmpty && !_isInSafeZone(snakeSegments.first)) {
      _die();
      return;
    }

    // Check AI snakes
    final deadAI = <_AISnake>[];
    for (final ai in aiSnakes) {
      if (ai.segments.isNotEmpty && !_isInSafeZone(ai.segments.first)) {
        deadAI.add(ai);
      }
    }
    for (final ai in deadAI) {
      aiSnakes.remove(ai);
      score += 50;
      onScoreChanged(score);
    }

    _checkWinCondition();
  }

  void _tickPlayerSnake() {
    if (gameState != GameState.playing) return;

    currentDirection = _nextDirection;
    final head = snakeSegments.first;
    final newHead = _movePoint(head, currentDirection);

    // Wall collision (danger zone boundary acts as wall)
    if (!_isInSafeZone(newHead)) {
      _die();
      return;
    }

    // Self collision
    if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
      _die();
      return;
    }

    // AI snake body collision
    for (final ai in aiSnakes) {
      if (ai.segments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
        _die();
        return;
      }
    }

    // Check food
    bool ate = false;
    food.removeWhere((f) {
      if (f.x == newHead.x && f.y == newHead.y) {
        score += 10;
        onScoreChanged(score);
        ate = true;
        return true;
      }
      return false;
    });

    snakeSegments.insert(0, newHead);
    if (!ate) {
      snakeSegments.removeLast();
    }
  }

  void _tickAISnakes() {
    if (gameState != GameState.playing) return;

    final deadAI = <_AISnake>[];

    for (final ai in aiSnakes) {
      // Decide direction
      ai.direction = _aiChooseDirection(ai);

      final head = ai.segments.first;
      final newHead = _movePoint(head, ai.direction);

      // Check death conditions
      if (!_isInSafeZone(newHead)) {
        deadAI.add(ai);
        continue;
      }

      // Self collision
      if (ai.segments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
        deadAI.add(ai);
        continue;
      }

      // Collision with player
      if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
        deadAI.add(ai);
        continue;
      }

      // Collision with other AI snakes
      bool hitOther = false;
      for (final other in aiSnakes) {
        if (other == ai) continue;
        if (other.segments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
          hitOther = true;
          break;
        }
      }
      if (hitOther) {
        deadAI.add(ai);
        continue;
      }

      // Check food
      bool ate = false;
      food.removeWhere((f) {
        if (f.x == newHead.x && f.y == newHead.y) {
          ate = true;
          return true;
        }
        return false;
      });

      ai.segments.insert(0, newHead);
      if (!ate) {
        ai.segments.removeLast();
      }
    }

    for (final ai in deadAI) {
      aiSnakes.remove(ai);
      score += 50;
      onScoreChanged(score);
    }

    _checkWinCondition();
  }

  Direction _aiChooseDirection(_AISnake ai) {
    final head = ai.segments.first;

    // Random direction change for unpredictability (20% chance)
    if (_random.nextDouble() < 0.2) {
      final dirs = _safeDirections(ai);
      if (dirs.isNotEmpty) {
        return dirs[_random.nextInt(dirs.length)];
      }
    }

    // Seek nearest food
    Point<int>? nearestFood;
    int nearestDist = 999999;
    for (final f in food) {
      final dist = (f.x - head.x).abs() + (f.y - head.y).abs();
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestFood = f;
      }
    }

    if (nearestFood != null) {
      // Determine preferred directions toward food
      final preferred = <Direction>[];
      if (nearestFood.x < head.x) preferred.add(Direction.left);
      if (nearestFood.x > head.x) preferred.add(Direction.right);
      if (nearestFood.y < head.y) preferred.add(Direction.up);
      if (nearestFood.y > head.y) preferred.add(Direction.down);

      // Filter to safe directions
      final safeDirs = _safeDirections(ai);
      for (final d in preferred) {
        if (safeDirs.contains(d)) return d;
      }
      if (safeDirs.isNotEmpty) return safeDirs[_random.nextInt(safeDirs.length)];
    }

    // Fallback: any safe direction
    final safeDirs = _safeDirections(ai);
    if (safeDirs.isNotEmpty) return safeDirs[_random.nextInt(safeDirs.length)];

    // No safe direction — keep going (will die)
    return ai.direction;
  }

  List<Direction> _safeDirections(_AISnake ai) {
    final head = ai.segments.first;
    final safe = <Direction>[];

    for (final dir in Direction.values) {
      // No reversing
      if (_isOpposite(dir, ai.direction)) continue;

      final next = _movePoint(head, dir);
      if (!_isInSafeZone(next)) continue;
      if (ai.segments.any((s) => s.x == next.x && s.y == next.y)) continue;
      if (snakeSegments.any((s) => s.x == next.x && s.y == next.y)) continue;

      bool hitsOtherAI = false;
      for (final other in aiSnakes) {
        if (other == ai) continue;
        if (other.segments.any((s) => s.x == next.x && s.y == next.y)) {
          hitsOtherAI = true;
          break;
        }
      }
      if (hitsOtherAI) continue;

      safe.add(dir);
    }

    return safe;
  }

  bool _isOpposite(Direction a, Direction b) {
    return (a == Direction.up && b == Direction.down) ||
        (a == Direction.down && b == Direction.up) ||
        (a == Direction.left && b == Direction.right) ||
        (a == Direction.right && b == Direction.left);
  }

  Point<int> _movePoint(Point<int> p, Direction dir) {
    switch (dir) {
      case Direction.up:
        return Point(p.x, p.y - 1);
      case Direction.down:
        return Point(p.x, p.y + 1);
      case Direction.left:
        return Point(p.x - 1, p.y);
      case Direction.right:
        return Point(p.x + 1, p.y);
    }
  }

  void _checkWinCondition() {
    if (gameState != GameState.playing) return;
    if (aiSnakes.isEmpty) {
      // Player wins — big bonus
      score += 500;
      onScoreChanged(score);
      gameState = GameState.gameOver;
      onGameOver();
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
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;

    // Draw grid
    final gridPaint = Paint()..color = mode.gridColor;
    for (int x = 0; x <= gridWidth; x++) {
      final px = boardOffset.x + x * cs;
      canvas.drawLine(
        Offset(px, boardOffset.y),
        Offset(px, boardOffset.y + gridHeight * cs),
        gridPaint,
      );
    }
    for (int y = 0; y <= gridHeight; y++) {
      final py = boardOffset.y + y * cs;
      canvas.drawLine(
        Offset(boardOffset.x, py),
        Offset(boardOffset.x + gridWidth * cs, py),
        gridPaint,
      );
    }

    // Draw danger zone overlay
    if (_dangerInset > 0) {
      final dangerPaint = Paint()..color = mode.dangerZoneColor;

      // Top strip
      canvas.drawRect(
        Rect.fromLTWH(
          boardOffset.x,
          boardOffset.y,
          gridWidth * cs,
          _dangerInset * cs,
        ),
        dangerPaint,
      );
      // Bottom strip
      canvas.drawRect(
        Rect.fromLTWH(
          boardOffset.x,
          boardOffset.y + (gridHeight - _dangerInset) * cs,
          gridWidth * cs,
          _dangerInset * cs,
        ),
        dangerPaint,
      );
      // Left strip (excluding corners already covered)
      canvas.drawRect(
        Rect.fromLTWH(
          boardOffset.x,
          boardOffset.y + _dangerInset * cs,
          _dangerInset * cs,
          (gridHeight - _dangerInset * 2) * cs,
        ),
        dangerPaint,
      );
      // Right strip
      canvas.drawRect(
        Rect.fromLTWH(
          boardOffset.x + (gridWidth - _dangerInset) * cs,
          boardOffset.y + _dangerInset * cs,
          _dangerInset * cs,
          (gridHeight - _dangerInset * 2) * cs,
        ),
        dangerPaint,
      );

      // Draw safe zone border
      final safeBorderPaint = Paint()
        ..color = const Color(0xFFFF1744).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromLTWH(
          boardOffset.x + _dangerInset * cs,
          boardOffset.y + _dangerInset * cs,
          (gridWidth - _dangerInset * 2) * cs,
          (gridHeight - _dangerInset * 2) * cs,
        ),
        safeBorderPaint,
      );
    }

    // Draw outer border
    final borderPaint = Paint()
      ..color = mode.snakeColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(
          boardOffset.x, boardOffset.y, cs * gridWidth, cs * gridHeight),
      borderPaint,
    );

    // Draw food
    final foodPaint = Paint()..color = mode.foodColor;
    for (final f in food) {
      final sp = _gridToScreen(f);
      canvas.drawCircle(
          Offset(sp.x + cs / 2, sp.y + cs / 2), cs * 0.3, foodPaint);
    }

    // Draw AI snakes
    for (final ai in aiSnakes) {
      final aiPaint = Paint()..color = ai.color;
      final aiHeadPaint = Paint()..color = ai.color.withOpacity(0.8);
      for (int i = 0; i < ai.segments.length; i++) {
        final seg = ai.segments[i];
        final sp = _gridToScreen(seg);
        canvas.drawRect(
          Rect.fromLTWH(
              sp.x + cs * 0.05, sp.y + cs * 0.05, cs * 0.9, cs * 0.9),
          i == 0 ? aiHeadPaint : aiPaint,
        );
        // Eyes on head
        if (i == 0) {
          final eyePaint = Paint()..color = Colors.white;
          canvas.drawCircle(
              Offset(sp.x + cs * 0.35, sp.y + cs * 0.35), cs * 0.08,
              eyePaint);
          canvas.drawCircle(
              Offset(sp.x + cs * 0.65, sp.y + cs * 0.35), cs * 0.08,
              eyePaint);
        }
      }
    }

    // Draw player snake
    final snakePaint = Paint()..color = mode.snakeColor;
    for (int i = 0; i < snakeSegments.length; i++) {
      final seg = snakeSegments[i];
      final sp = _gridToScreen(seg);
      canvas.drawRect(
        Rect.fromLTWH(
            sp.x + cs * 0.05, sp.y + cs * 0.05, cs * 0.9, cs * 0.9),
        snakePaint,
      );
      // Eyes on player head
      if (i == 0) {
        final eyePaint = Paint()..color = Colors.black;
        canvas.drawCircle(
            Offset(sp.x + cs * 0.35, sp.y + cs * 0.35), cs * 0.08, eyePaint);
        canvas.drawCircle(
            Offset(sp.x + cs * 0.65, sp.y + cs * 0.35), cs * 0.08, eyePaint);
      }
    }

    // HUD — alive count
    final aliveCount = aiSnakes.length + 1;
    final tp = TextPainter(
      text: TextSpan(
        text: 'ALIVE: $aliveCount',
        style: TextStyle(
          color: mode.snakeColor.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(boardOffset.x + gridWidth * cs - tp.width - 4,
          boardOffset.y - 16),
    );
  }
}

class _AISnake {
  List<Point<int>> segments;
  Direction direction;
  final Color color;

  _AISnake({
    required this.segments,
    required this.direction,
    required this.color,
  });
}
