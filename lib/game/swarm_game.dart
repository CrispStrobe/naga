import 'dart:collection';
import 'dart:math';
import 'dart:ui' as ui;
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
  final Queue<Direction> _directionQueue = Queue<Direction>();
  static const int _maxQueuedInputs = 4;
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

  // Grace period after wave spawn — snake is invincible briefly
  double _graceTimer = 0;
  static const double _graceDuration = 2.0;
  bool get _isInGrace => _graceTimer > 0;

  final Random _random = Random();

  // Cached habitat decoration layer (board fill + canopy foliage).
  ui.Picture? _decorPicture;
  double _decorCellSize = -1;

  SwarmGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
  });

  @override
  Color backgroundColor() =>
      Color.lerp(mode.backgroundColor, Colors.black, 0.18)!;

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
    _resetSnakeToBottom();
    _spawnWave();
  }

  void _resetSnakeToBottom() {
    currentDirection = Direction.right;
    _directionQueue.clear();
    final startX = gridWidth ~/ 2;
    final startY = gridHeight - 3;
    snakeSegments = [
      Point(startX, startY),
      Point(startX - 1, startY),
      Point(startX - 2, startY),
    ];
    _graceTimer = _graceDuration;
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

    // Grace period countdown
    if (_graceTimer > 0) {
      _graceTimer -= dt;
    }

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

    // Wrap horizontally, block at top/bottom
    newHead = Point(
      (newHead.x + gridWidth) % gridWidth,
      newHead.y.clamp(0, gridHeight - 1),
    );

    // Self collision
    if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
      return; // just don't move
    }

    // Collision with enemies — horizontal approach = eat, vertical = death
    // (enemies have spikes on top/bottom)
    final hitEnemy = enemies.where(
      (e) => e.position.x == newHead.x && e.position.y == newHead.y,
    ).toList();

    bool ate = false;
    for (final enemy in hitEnemy) {
      final isHorizontal = currentDirection == Direction.left ||
          currentDirection == Direction.right;
      if (isHorizontal || _isInGrace) {
        // Eat from the side (or during grace period)
        enemies.remove(enemy);
        score += enemy.points;
        ate = true;
        onScoreChanged(score);
        if (_random.nextDouble() < 0.2) {
          powerUps.add(enemy.position);
        }
      } else {
        // Vertical collision — hit spikes, die
        if (!_isInGrace) {
          _die();
          return;
        }
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
      _resetSnakeToBottom();
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

      // Enemies stepped down onto snake — deadly (spikes from above)
      if (!_isInGrace) {
        for (final enemy in enemies) {
          if (snakeSegments.any((s) => s.x == enemy.position.x && s.y == enemy.position.y)) {
            _die();
            return;
          }
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

      // Sideways movement onto snake head = eaten (snake eats from sides)
      final head = snakeSegments.first;
      final eatenByHead = enemies.where(
        (e) => e.position.x == head.x && e.position.y == head.y,
      ).toList();
      for (final enemy in eatenByHead) {
        enemies.remove(enemy);
        score += enemy.points;
        onScoreChanged(score);
      }
      // Sideways movement onto snake body — just push through, not lethal
      // (only vertical descent is dangerous due to spikes)
    }

    // During grace period, eat any enemy on head
    if (_isInGrace) {
      final head = snakeSegments.first;
      final eatenByHead = enemies.where(
        (e) => e.position.x == head.x && e.position.y == head.y,
      ).toList();
      for (final enemy in eatenByHead) {
        enemies.remove(enemy);
        score += enemy.points;
        onScoreChanged(score);
      }
    }
  }

  void _die() {
    gameState = GameState.gameOver;
    onGameOver();
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

  /// Builds the cached habitat layer: bright canopy board on the darker
  /// surround, scattered leaves and vine strands along the top edge.
  /// Deterministic (fixed seed) and cached so render stays cheap.
  ui.Picture _buildDecorPicture() {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final cs = cellSize;
    final bg = mode.backgroundColor;
    final boardRect = Rect.fromLTWH(
        boardOffset.x, boardOffset.y, gridWidth * cs, gridHeight * cs);

    // Bright play field on the darker surround
    c.drawRect(boardRect, Paint()..color = bg);

    c.save();
    c.clipRect(boardRect);
    final rng = Random(9182); // fixed seed: same pattern every rebuild

    // Scattered leaf shapes — low contrast against the canopy green
    final leafLight = Paint()..color = Color.lerp(bg, Colors.white, 0.09)!;
    final leafDark = Paint()..color = Color.lerp(bg, Colors.black, 0.08)!;
    final count = (gridWidth * gridHeight * 0.06).round();
    for (int i = 0; i < count; i++) {
      final cx = boardRect.left + rng.nextDouble() * boardRect.width;
      final cy = boardRect.top + rng.nextDouble() * boardRect.height;
      final angle = rng.nextDouble() * 2 * pi;
      final len = cs * (0.8 + rng.nextDouble() * 1.2);
      final paint = rng.nextBool() ? leafLight : leafDark;

      c.save();
      c.translate(cx, cy);
      c.rotate(angle);
      // Leaf: pointed oval
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -len * 0.22, len, 0)
        ..quadraticBezierTo(len * 0.5, len * 0.22, 0, 0)
        ..close();
      c.drawPath(leaf, paint);
      c.restore();
    }

    // Vine strands hanging from the top edge
    final vinePaint = Paint()
      ..color = Color.lerp(bg, Colors.black, 0.12)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = cs * 0.08;
    final vineLeaf = Paint()..color = Color.lerp(bg, Colors.black, 0.10)!;
    const vineCount = 4;
    for (int i = 0; i < vineCount; i++) {
      final x = boardRect.left +
          boardRect.width * (0.12 + 0.76 * i / (vineCount - 1)) +
          (rng.nextDouble() - 0.5) * cs * 2;
      final length = cs * (2.0 + rng.nextDouble() * 2.0);
      final sway = (rng.nextDouble() - 0.5) * cs * 1.6;
      final path = Path()
        ..moveTo(x, boardRect.top)
        ..quadraticBezierTo(
            x + sway, boardRect.top + length * 0.5, x, boardRect.top + length)
        ..quadraticBezierTo(x - sway * 0.6, boardRect.top + length * 1.25,
            x + sway * 0.4, boardRect.top + length * 1.5);
      c.drawPath(path, vinePaint);
      // Small leaves along the vine
      for (final t in [0.35, 0.7, 1.0]) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(x + sway * 0.3, boardRect.top + length * t),
            width: cs * 0.4,
            height: cs * 0.22,
          ),
          vineLeaf,
        );
      }
    }

    c.restore();
    return recorder.endRecording();
  }

  @override
  void onRemove() {
    _decorPicture?.dispose();
    _decorPicture = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;

    // Habitat layer — bright board on darker surround (cached)
    if (_decorPicture == null || _decorCellSize != cs) {
      _decorCellSize = cs;
      _decorPicture?.dispose();
      _decorPicture = _buildDecorPicture();
    }
    canvas.drawPicture(_decorPicture!);

    // Draw border
    final borderPaint = Paint()
      ..color = mode.snakeColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(boardOffset.x, boardOffset.y, cs * gridWidth, cs * gridHeight),
      borderPaint,
    );

    // Draw enemies — with spikes top/bottom to show vertical danger
    final spikePaint = Paint()..color = Colors.white.withOpacity(0.9);
    for (final enemy in enemies) {
      final sp = _gridToScreen(enemy.position);
      final paint = Paint()..color = enemy.color;
      final cx = sp.x + cs * 0.5;

      // Top spikes (3 triangles pointing up)
      for (final sx in [0.25, 0.5, 0.75]) {
        final tipX = sp.x + cs * sx;
        final path = Path()
          ..moveTo(tipX, sp.y + cs * 0.02)
          ..lineTo(tipX - cs * 0.08, sp.y + cs * 0.18)
          ..lineTo(tipX + cs * 0.08, sp.y + cs * 0.18)
          ..close();
        canvas.drawPath(path, spikePaint);
      }

      // Body — rounded rect in the middle
      final bodyRect = Rect.fromLTWH(sp.x + cs * 0.1, sp.y + cs * 0.18, cs * 0.8, cs * 0.64);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, Radius.circular(cs * 0.1)),
        paint,
      );

      // Bottom spikes (3 triangles pointing down)
      for (final sx in [0.25, 0.5, 0.75]) {
        final tipX = sp.x + cs * sx;
        final path = Path()
          ..moveTo(tipX, sp.y + cs * 0.98)
          ..lineTo(tipX - cs * 0.08, sp.y + cs * 0.82)
          ..lineTo(tipX + cs * 0.08, sp.y + cs * 0.82)
          ..close();
        canvas.drawPath(path, spikePaint);
      }

      // Eyes
      final eyePaint = Paint()..color = Colors.white;
      final pupilPaint = Paint()..color = const Color(0xFF1A1A1A);
      canvas.drawCircle(Offset(cx - cs * 0.15, sp.y + cs * 0.4), cs * 0.1, eyePaint);
      canvas.drawCircle(Offset(cx + cs * 0.15, sp.y + cs * 0.4), cs * 0.1, eyePaint);
      canvas.drawCircle(Offset(cx - cs * 0.15, sp.y + cs * 0.42), cs * 0.05, pupilPaint);
      canvas.drawCircle(Offset(cx + cs * 0.15, sp.y + cs * 0.42), cs * 0.05, pupilPaint);
    }

    // Draw power-ups
    final puPaint = Paint()..color = mode.foodColor;
    for (final pu in powerUps) {
      final sp = _gridToScreen(pu);
      canvas.drawCircle(Offset(sp.x + cs / 2, sp.y + cs / 2), cs * 0.25, puPaint);
    }

    // Draw snake (flashes during grace period)
    final graceFlash = _isInGrace && ((_graceTimer * 8).toInt() % 2 == 0);
    final snakeAlpha = graceFlash ? 0.4 : 1.0;
    final snakePaint = Paint()..color = mode.snakeColor.withOpacity(snakeAlpha);
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
        // Sits on the darker surround outside the board — keep it light.
        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.bold),
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
