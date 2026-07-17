import 'dart:collection';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/venom_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Bomberman-inspired mode — drop venom bombs, destroy walls, clear enemies.
/// Destroyed walls drop food; eating grows the snake, and a longer snake
/// carries more venom bombs (but is a bigger target for blasts).
class VenomGame extends FlameGame with KeyboardEvents {
  final VenomMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  static const int gridWidth = 20;
  static const int gridHeight = 28;
  static const int bombExplosionRadius = 2; // circular cloud, ~13 cells
  static const double bombFuseTime = 3.0;
  static const int startLength = 3;
  static const double foodDropChance = 0.3;

  late double cellSize;
  late Vector2 boardOffset;

  // Snake
  List<Point<int>> snakeSegments = [];
  int targetLength = startLength;
  Direction currentDirection = Direction.right;
  final Queue<Direction> _directionQueue = Queue<Direction>();
  static const int _maxQueuedInputs = 4;
  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;
  int _bombsAvailable = 3;
  bool _dropBombRequested = false;

  /// Bomb capacity grows with the snake: +1 bomb per 3 segments, capped at 6.
  int get maxBombs => min(2 + targetLength ~/ 3, 6);

  int get bombsAvailable => _bombsAvailable;

  // Food dropped by destroyed walls
  final Set<int> _foods = {};

  // Walls: true = indestructible, false would not be stored
  Set<int> indestructibleWalls = {};
  Set<int> destructibleWalls = {};

  // Bombs
  final List<_Bomb> _bombs = [];

  // Explosions (visual)
  final List<_Explosion> _explosions = [];
  static const double _explosionDuration = 0.4;

  // Enemies
  final List<_Enemy> _enemies = [];
  double _enemyTickTimer = 0;
  static const double _enemyTickInterval = 0.35;

  // Level
  int _level = 1;

  final Random _random = Random();

  VenomGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
  });

  int _key(int x, int y) => y * gridWidth + x;
  Point<int> _fromKey(int k) => Point(k % gridWidth, k ~/ gridWidth);

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
    targetLength = startLength;
    gameState = GameState.playing;
    currentDirection = Direction.right;
    _directionQueue.clear();
    _bombs.clear();
    _explosions.clear();
    _bombsAvailable = maxBombs;
    _dropBombRequested = false;
    _buildLevel();
  }

  void _buildLevel() {
    indestructibleWalls.clear();
    destructibleWalls.clear();
    _bombs.clear();
    _explosions.clear();
    _enemies.clear();
    _foods.clear();
    _dropBombRequested = false;

    // Border walls (indestructible)
    for (int x = 0; x < gridWidth; x++) {
      indestructibleWalls.add(_key(x, 0));
      indestructibleWalls.add(_key(x, gridHeight - 1));
    }
    for (int y = 0; y < gridHeight; y++) {
      indestructibleWalls.add(_key(0, y));
      indestructibleWalls.add(_key(gridWidth - 1, y));
    }

    // Interior indestructible pillars — every 5th cell for wide corridors
    final pillarPositions = <int>{};
    for (int x = 5; x < gridWidth - 1; x += 5) {
      for (int y = 5; y < gridHeight - 1; y += 5) {
        final k = _key(x, y);
        indestructibleWalls.add(k);
        pillarPositions.add(k);
      }
    }

    // Keep a 1-cell clearance around each pillar so corridors are always 3+ wide
    final corridorCells = <int>{};
    for (final pk in pillarPositions) {
      final p = _fromKey(pk);
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          if (dx == 0 && dy == 0) continue;
          final nx = p.x + dx;
          final ny = p.y + dy;
          if (nx > 0 && nx < gridWidth - 1 && ny > 0 && ny < gridHeight - 1) {
            corridorCells.add(_key(nx, ny));
          }
        }
      }
    }

    // Snake starting position — bottom-left area
    final startX = 1;
    final startY = gridHeight - 2;
    snakeSegments = [
      Point(startX + 2, startY),
      Point(startX + 1, startY),
      Point(startX, startY),
    ];
    currentDirection = Direction.right;
    _directionQueue.clear();

    // Reserve space around snake spawn
    final reserved = <int>{};
    for (final seg in snakeSegments) {
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          reserved.add(_key(seg.x + dx, seg.y + dy));
        }
      }
    }

    // Place destructible walls — never in corridor cells or reserved area
    final openCells = <int>[];
    for (int x = 1; x < gridWidth - 1; x++) {
      for (int y = 1; y < gridHeight - 1; y++) {
        final k = _key(x, y);
        if (!indestructibleWalls.contains(k) &&
            !reserved.contains(k) &&
            !corridorCells.contains(k)) {
          openCells.add(k);
        }
      }
    }
    openCells.shuffle(_random);

    // Fill 25-40% of eligible cells with destructible walls
    final fillRatio = (0.25 + _level * 0.02).clamp(0.25, 0.40);
    final wallCount = (openCells.length * fillRatio).toInt();
    for (int i = 0; i < wallCount && i < openCells.length; i++) {
      destructibleWalls.add(openCells[i]);
    }

    // Spawn enemies in open cells away from snake
    final enemyCount = (1 + _level).clamp(2, 8);
    final enemyCandidates = <int>[];
    for (int x = 1; x < gridWidth - 1; x++) {
      for (int y = 1; y < gridHeight - 1; y++) {
        final k = _key(x, y);
        if (!indestructibleWalls.contains(k) &&
            !destructibleWalls.contains(k) &&
            !reserved.contains(k)) {
          // Ensure some distance from snake
          final dist = (x - startX).abs() + (y - startY).abs();
          if (dist > 8) {
            enemyCandidates.add(k);
          }
        }
      }
    }
    enemyCandidates.shuffle(_random);
    for (int i = 0; i < enemyCount && i < enemyCandidates.length; i++) {
      final p = _fromKey(enemyCandidates[i]);
      _enemies.add(_Enemy(position: p));
    }
  }

  bool _isWall(int x, int y) {
    final k = _key(x, y);
    return indestructibleWalls.contains(k) || destructibleWalls.contains(k);
  }

  bool _isBlocked(int x, int y) {
    if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) return true;
    return _isWall(x, y);
  }

  bool _isBombAt(int x, int y) {
    return _bombs.any((b) => b.position.x == x && b.position.y == y);
  }

  /// Freshly dropped bombs stay passable for the snake until it slides off
  /// them; then they harden and block like a wall.
  bool _isSolidBombAt(int x, int y) {
    return _bombs.any((b) => b.solid && b.position.x == x && b.position.y == y);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    // Update bomb timers; harden bombs the snake has slid off
    for (final bomb in _bombs) {
      bomb.timer -= dt;
      if (!bomb.solid &&
          !snakeSegments.any(
              (s) => s.x == bomb.position.x && s.y == bomb.position.y)) {
        bomb.solid = true;
      }
    }
    // Explode bombs whose timer expired
    final expired = _bombs.where((b) => b.timer <= 0).toList();
    for (final bomb in expired) {
      _bombs.remove(bomb);
      _explodeBomb(bomb);
    }

    // Update explosion visuals
    for (final exp in _explosions) {
      exp.timer -= dt;
    }
    _explosions.removeWhere((e) => e.timer <= 0);

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

  Point<int> _neighbor(Point<int> from, Direction dir) {
    switch (dir) {
      case Direction.up:
        return Point(from.x, from.y - 1);
      case Direction.down:
        return Point(from.x, from.y + 1);
      case Direction.left:
        return Point(from.x - 1, from.y);
      case Direction.right:
        return Point(from.x + 1, from.y);
    }
  }

  bool _cellFree(Point<int> p) =>
      !_isBlocked(p.x, p.y) && !_isSolidBombAt(p.x, p.y);

  void _tickSnake() {
    // Drop bomb on request at the tail cell — before movement, so bombing
    // the wall you're pressed against works. The bomb stays passable until
    // the snake slides off it.
    if (_dropBombRequested) {
      _dropBombRequested = false;
      final tail = snakeSegments.last;
      if (_bombsAvailable > 0 && !_isBombAt(tail.x, tail.y)) {
        _bombs.add(_Bomb(position: tail, timer: bombFuseTime));
        _bombsAvailable--;
      }
    }

    if (_directionQueue.isNotEmpty) {
      currentDirection = _directionQueue.removeFirst();
    }
    var newHead = _neighbor(snakeSegments.first, currentDirection);

    // Can't move into a wall or hardened bomb — stay put
    if (!_cellFree(newHead)) {
      return;
    }

    // Blocked by own body (e.g. wedged in a dead end after a blocked turn):
    // turn around — head becomes tail — so the snake can always back out
    if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
      final flipped = snakeSegments.reversed.toList();
      final flippedHead = _neighbor(flipped.first, currentDirection);
      if (!_cellFree(flippedHead) ||
          flipped.any((s) => s.x == flippedHead.x && s.y == flippedHead.y)) {
        return; // truly stuck this tick
      }
      snakeSegments = flipped;
      newHead = flippedHead;
    }

    // Check enemy collision — touching enemy = death
    if (_enemies.any((e) => e.position.x == newHead.x && e.position.y == newHead.y)) {
      _die();
      return;
    }

    // Move snake
    snakeSegments.insert(0, newHead);
    if (snakeSegments.length > targetLength) {
      snakeSegments.removeLast();
    }

    // Eat food dropped by destroyed walls — grow, and grow bomb capacity
    final headKey = _key(newHead.x, newHead.y);
    if (_foods.remove(headKey)) {
      final oldMax = maxBombs;
      targetLength++;
      if (maxBombs > oldMax) {
        _bombsAvailable++;
      }
      score += mode.pointsPerFood(score);
      onScoreChanged(score);
    }

    // Check if snake is in an active explosion
    if (_isInExplosion(newHead)) {
      _die();
      return;
    }
  }

  void _explodeBomb(_Bomb bomb) {
    // Replenish one bomb when it explodes
    if (_bombsAvailable < maxBombs) {
      _bombsAvailable++;
    }
    final cells = _getExplosionCells(bomb.position);

    // Create explosion visual
    _explosions.add(_Explosion(cells: cells, timer: _explosionDuration));

    // Destroy destructible walls — some drop food
    for (final cell in cells) {
      final k = _key(cell.x, cell.y);
      if (destructibleWalls.contains(k)) {
        destructibleWalls.remove(k);
        score += 5;
        onScoreChanged(score);
        if (_random.nextDouble() < foodDropChance) {
          _foods.add(k);
        }
      }
    }

    // Kill enemies in explosion
    final killedEnemies = _enemies.where((e) =>
      cells.any((c) => c.x == e.position.x && c.y == e.position.y)
    ).toList();
    for (final enemy in killedEnemies) {
      _enemies.remove(enemy);
      score += 10;
      onScoreChanged(score);
    }

    // Chain reaction: detonate other bombs caught in explosion
    final chainBombs = _bombs.where((b) =>
      cells.any((c) => c.x == b.position.x && c.y == b.position.y)
    ).toList();
    for (final cb in chainBombs) {
      _bombs.remove(cb);
      _explodeBomb(cb);
    }

    // Kill snake if caught in explosion
    if (snakeSegments.any((s) => cells.any((c) => c.x == s.x && c.y == s.y))) {
      _die();
      return;
    }

    // Check win condition
    if (_enemies.isEmpty && gameState == GameState.playing) {
      _level++;
      _buildLevel();
    }
  }

  /// Venom spreads as a circular cloud around the bomb: a breadth-first
  /// flood out to [bombExplosionRadius]. Indestructible walls block it;
  /// destructible walls are engulfed (and destroyed) but stop the spread.
  List<Point<int>> _getExplosionCells(Point<int> center) {
    final visited = <int>{_key(center.x, center.y)};
    final cells = <Point<int>>[center];
    var frontier = <Point<int>>[center];
    final dirs = [Point(0, -1), Point(0, 1), Point(-1, 0), Point(1, 0)];
    for (int ring = 1; ring <= bombExplosionRadius; ring++) {
      final next = <Point<int>>[];
      for (final cell in frontier) {
        for (final dir in dirs) {
          final x = cell.x + dir.x;
          final y = cell.y + dir.y;
          if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) continue;
          final k = _key(x, y);
          if (visited.contains(k)) continue;
          if (indestructibleWalls.contains(k)) continue;
          visited.add(k);
          cells.add(Point(x, y));
          if (!destructibleWalls.contains(k)) {
            next.add(Point(x, y)); // walls are engulfed but don't spread on
          }
        }
      }
      frontier = next;
    }
    return cells;
  }

  bool _isInExplosion(Point<int> pos) {
    return _explosions.any((exp) =>
      exp.cells.any((c) => c.x == pos.x && c.y == pos.y)
    );
  }

  void _tickEnemies() {
    final head = snakeSegments.first;
    for (final enemy in _enemies) {
      final dirs = <Point<int>>[];
      for (final d in [Point(0, -1), Point(0, 1), Point(-1, 0), Point(1, 0)]) {
        final nx = enemy.position.x + d.x;
        final ny = enemy.position.y + d.y;
        if (!_isBlocked(nx, ny) && !_isBombAt(nx, ny)) {
          dirs.add(d);
        }
      }
      if (dirs.isEmpty) continue;

      // Sometimes stalk the snake: step toward its head
      if (_random.nextDouble() < 0.4) {
        dirs.sort((a, b) {
          int dist(Point<int> d) =>
              (enemy.position.x + d.x - head.x).abs() +
              (enemy.position.y + d.y - head.y).abs();
          return dist(a).compareTo(dist(b));
        });
        final d = dirs.first;
        enemy.position = Point(enemy.position.x + d.x, enemy.position.y + d.y);
        enemy.lastDir = d;
      } else if (enemy.lastDir != null &&
          dirs.any((d) => d.x == enemy.lastDir!.x && d.y == enemy.lastDir!.y) &&
          _random.nextDouble() < 0.7) {
        // Prefer continuing in same direction if possible
        final d = enemy.lastDir!;
        enemy.position = Point(enemy.position.x + d.x, enemy.position.y + d.y);
      } else {
        final d = dirs[_random.nextInt(dirs.length)];
        enemy.position = Point(enemy.position.x + d.x, enemy.position.y + d.y);
        enemy.lastDir = d;
      }
    }

    // Check if enemy walked into snake — death
    for (final enemy in _enemies) {
      if (enemy.position.x == head.x && enemy.position.y == head.y) {
        _die();
        return;
      }
    }

    // Check if enemy walked into explosion
    final killedInExplosion = _enemies.where((e) => _isInExplosion(e.position)).toList();
    for (final enemy in killedInExplosion) {
      _enemies.remove(enemy);
      score += 10;
      onScoreChanged(score);
    }

    if (_enemies.isEmpty && gameState == GameState.playing) {
      _level++;
      _buildLevel();
    }
  }

  void _die() {
    gameState = GameState.gameOver;
    onGameOver();
  }

  /// Public method to drop a bomb (called from d-pad action button)
  void dropBomb() {
    _dropBombRequested = true;
  }

  void changeDirection(Direction dir) {
    final lastDir = _directionQueue.isNotEmpty
        ? _directionQueue.last
        : currentDirection;
    final isOpposite =
        (dir == Direction.up && lastDir == Direction.down) ||
        (dir == Direction.down && lastDir == Direction.up) ||
        (dir == Direction.left && lastDir == Direction.right) ||
        (dir == Direction.right && lastDir == Direction.left);
    if (isOpposite) {
      // Turn around: head becomes tail, so dead ends are always escapable
      snakeSegments = snakeSegments.reversed.toList();
      currentDirection = dir;
      _directionQueue.clear();
      return;
    }
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
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _dropBombRequested = true;
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

    // Draw grid lines
    final gridPaint = Paint()
      ..color = mode.gridColor
      ..strokeWidth = 0.5;
    for (int x = 0; x <= gridWidth; x++) {
      final sx = boardOffset.x + x * cs;
      canvas.drawLine(
        Offset(sx, boardOffset.y),
        Offset(sx, boardOffset.y + gridHeight * cs),
        gridPaint,
      );
    }
    for (int y = 0; y <= gridHeight; y++) {
      final sy = boardOffset.y + y * cs;
      canvas.drawLine(
        Offset(boardOffset.x, sy),
        Offset(boardOffset.x + gridWidth * cs, sy),
        gridPaint,
      );
    }

    // Draw indestructible walls
    final indestructPaint = Paint()..color = const Color(0xFF424242);
    for (final k in indestructibleWalls) {
      final p = _fromKey(k);
      final sp = _gridToScreen(p);
      canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), indestructPaint);
      // Inner highlight for 3D effect
      final highlightPaint = Paint()..color = const Color(0xFF616161);
      canvas.drawRect(
        Rect.fromLTWH(sp.x + cs * 0.1, sp.y + cs * 0.1, cs * 0.8, cs * 0.4),
        highlightPaint,
      );
    }

    // Draw destructible walls
    final destructPaint = Paint()..color = mode.destructibleWallColor;
    final destructBorderPaint = Paint()
      ..color = mode.destructibleWallColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final k in destructibleWalls) {
      final p = _fromKey(k);
      final sp = _gridToScreen(p);
      canvas.drawRect(Rect.fromLTWH(sp.x + 0.5, sp.y + 0.5, cs - 1, cs - 1), destructPaint);
      // Brick pattern
      canvas.drawLine(
        Offset(sp.x + cs * 0.5, sp.y),
        Offset(sp.x + cs * 0.5, sp.y + cs * 0.5),
        destructBorderPaint,
      );
      canvas.drawLine(
        Offset(sp.x, sp.y + cs * 0.5),
        Offset(sp.x + cs, sp.y + cs * 0.5),
        destructBorderPaint,
      );
      canvas.drawLine(
        Offset(sp.x + cs * 0.25, sp.y + cs * 0.5),
        Offset(sp.x + cs * 0.25, sp.y + cs),
        destructBorderPaint,
      );
      canvas.drawLine(
        Offset(sp.x + cs * 0.75, sp.y + cs * 0.5),
        Offset(sp.x + cs * 0.75, sp.y + cs),
        destructBorderPaint,
      );
    }

    // Draw food (dropped by destroyed walls)
    final foodPaint = Paint()..color = mode.foodColor;
    final foodShinePaint = Paint()..color = Colors.white.withOpacity(0.5);
    for (final k in _foods) {
      final p = _fromKey(k);
      final sp = _gridToScreen(p);
      final center = Offset(sp.x + cs / 2, sp.y + cs / 2);
      canvas.drawCircle(center, cs * 0.3, foodPaint);
      canvas.drawCircle(
        Offset(center.dx - cs * 0.1, center.dy - cs * 0.1),
        cs * 0.08,
        foodShinePaint,
      );
    }

    // Draw explosions
    for (final exp in _explosions) {
      final alpha = (exp.timer / _explosionDuration).clamp(0.0, 1.0);
      final expPaint = Paint()..color = mode.explosionColor.withOpacity(alpha * 0.8);
      final expCorePaint = Paint()..color = Colors.white.withOpacity(alpha * 0.6);
      for (final cell in exp.cells) {
        final sp = _gridToScreen(cell);
        canvas.drawRect(Rect.fromLTWH(sp.x, sp.y, cs, cs), expPaint);
        canvas.drawRect(
          Rect.fromLTWH(sp.x + cs * 0.2, sp.y + cs * 0.2, cs * 0.6, cs * 0.6),
          expCorePaint,
        );
      }
    }

    // Draw bombs
    for (final bomb in _bombs) {
      final sp = _gridToScreen(bomb.position);
      final center = Offset(sp.x + cs / 2, sp.y + cs / 2);
      // Pulsing effect based on remaining time
      final pulse = (sin(bomb.timer * 8) * 0.15 + 0.85).clamp(0.7, 1.0);
      final bombPaint = Paint()..color = mode.bombColor;
      canvas.drawCircle(center, cs * 0.35 * pulse, bombPaint);
      // Fuse spark
      final sparkPaint = Paint()..color = mode.explosionColor;
      canvas.drawCircle(
        Offset(center.dx + cs * 0.15, center.dy - cs * 0.25),
        cs * 0.08,
        sparkPaint,
      );
    }

    // Draw enemies
    final enemyPaint = Paint()..color = const Color(0xFFE040FB);
    final enemyEyePaint = Paint()..color = Colors.white;
    for (final enemy in _enemies) {
      final sp = _gridToScreen(enemy.position);
      // Ghost-like shape
      final bodyRect = Rect.fromLTWH(sp.x + cs * 0.1, sp.y + cs * 0.1, cs * 0.8, cs * 0.8);
      canvas.drawRRect(
        RRect.fromRectAndCorners(bodyRect,
          topLeft: Radius.circular(cs * 0.3),
          topRight: Radius.circular(cs * 0.3),
        ),
        enemyPaint,
      );
      // Eyes
      canvas.drawCircle(Offset(sp.x + cs * 0.35, sp.y + cs * 0.4), cs * 0.1, enemyEyePaint);
      canvas.drawCircle(Offset(sp.x + cs * 0.65, sp.y + cs * 0.4), cs * 0.1, enemyEyePaint);
      final pupilPaint = Paint()..color = const Color(0xFF1A1A0A);
      canvas.drawCircle(Offset(sp.x + cs * 0.35, sp.y + cs * 0.42), cs * 0.05, pupilPaint);
      canvas.drawCircle(Offset(sp.x + cs * 0.65, sp.y + cs * 0.42), cs * 0.05, pupilPaint);
    }

    // Draw snake
    final snakePaint = Paint()..color = mode.snakeColor;
    for (int i = 0; i < snakeSegments.length; i++) {
      final seg = snakeSegments[i];
      final sp = _gridToScreen(seg);
      final inset = i == 0 ? 0.02 : 0.05;
      canvas.drawRect(
        Rect.fromLTWH(sp.x + cs * inset, sp.y + cs * inset, cs * (1 - inset * 2), cs * (1 - inset * 2)),
        snakePaint,
      );
      // Head eyes
      if (i == 0) {
        final eyePaint = Paint()..color = const Color(0xFF1A1A0A);
        double ex1, ey1, ex2, ey2;
        switch (currentDirection) {
          case Direction.up:
            ex1 = sp.x + cs * 0.3; ey1 = sp.y + cs * 0.25;
            ex2 = sp.x + cs * 0.7; ey2 = sp.y + cs * 0.25;
          case Direction.down:
            ex1 = sp.x + cs * 0.3; ey1 = sp.y + cs * 0.75;
            ex2 = sp.x + cs * 0.7; ey2 = sp.y + cs * 0.75;
          case Direction.left:
            ex1 = sp.x + cs * 0.25; ey1 = sp.y + cs * 0.3;
            ex2 = sp.x + cs * 0.25; ey2 = sp.y + cs * 0.7;
          case Direction.right:
            ex1 = sp.x + cs * 0.75; ey1 = sp.y + cs * 0.3;
            ex2 = sp.x + cs * 0.75; ey2 = sp.y + cs * 0.7;
        }
        canvas.drawCircle(Offset(ex1, ey1), cs * 0.07, eyePaint);
        canvas.drawCircle(Offset(ex2, ey2), cs * 0.07, eyePaint);
      }
    }

    // HUD: painted inside the border wall row so it never overlaps the
    // score bar above the canvas
    final hudY = boardOffset.y + 2;
    final levelTp = TextPainter(
      text: TextSpan(
        text: 'LEVEL $_level',
        style: TextStyle(
          color: mode.snakeColor.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    levelTp.paint(canvas, Offset(boardOffset.x + 4, hudY));

    final bombTp = TextPainter(
      text: TextSpan(
        text: 'BOMBS: $_bombsAvailable/$maxBombs',
        style: TextStyle(
          color: mode.bombColor.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    bombTp.paint(
      canvas,
      Offset(boardOffset.x + (gridWidth * cs - bombTp.width) / 2, hudY),
    );

    final enemyTp = TextPainter(
      text: TextSpan(
        text: '${_enemies.length} ENEMIES',
        style: TextStyle(
          color: mode.snakeColor.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    enemyTp.paint(
      canvas,
      Offset(boardOffset.x + gridWidth * cs - enemyTp.width - 4, hudY),
    );
  }
}

class _Bomb {
  final Point<int> position;
  double timer;

  /// Passable for the snake until it slides off, then blocks like a wall.
  bool solid = false;

  _Bomb({required this.position, required this.timer});
}

class _Explosion {
  final List<Point<int>> cells;
  double timer;

  _Explosion({required this.cells, required this.timer});
}

class _Enemy {
  Point<int> position;
  Point<int>? lastDir;

  _Enemy({required this.position});
}
