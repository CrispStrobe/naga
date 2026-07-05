import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/venom_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Bomberman-inspired mode — drop venom bombs, destroy walls, clear enemies.
class VenomGame extends FlameGame with KeyboardEvents {
  final VenomMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  static const int gridWidth = 20;
  static const int gridHeight = 28;
  static const int bombExplosionRadius = 3;
  static const double bombFuseTime = 3.0;
  static const int snakeLength = 3;

  late double cellSize;
  late Vector2 boardOffset;

  // Snake
  List<Point<int>> snakeSegments = [];
  Direction currentDirection = Direction.right;
  Direction _nextDirection = Direction.right;
  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;
  int _bombsAvailable = 3;
  static const int _maxBombs = 3;
  bool _dropBombRequested = false;

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
    gameState = GameState.playing;
    currentDirection = Direction.right;
    _nextDirection = Direction.right;
    _bombs.clear();
    _explosions.clear();
    _bombsAvailable = _maxBombs;
    _dropBombRequested = false;
    _buildLevel();
  }

  void _buildLevel() {
    indestructibleWalls.clear();
    destructibleWalls.clear();
    _bombs.clear();
    _explosions.clear();
    _enemies.clear();
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

    // Interior indestructible walls in grid pattern (every 3rd cell for wider corridors)
    for (int x = 3; x < gridWidth - 1; x += 3) {
      for (int y = 3; y < gridHeight - 1; y += 3) {
        indestructibleWalls.add(_key(x, y));
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
    _nextDirection = Direction.right;

    // Reserve space around snake spawn
    final reserved = <int>{};
    for (final seg in snakeSegments) {
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          reserved.add(_key(seg.x + dx, seg.y + dy));
        }
      }
    }

    // Place destructible walls randomly
    final openCells = <int>[];
    for (int x = 1; x < gridWidth - 1; x++) {
      for (int y = 1; y < gridHeight - 1; y++) {
        final k = _key(x, y);
        if (!indestructibleWalls.contains(k) && !reserved.contains(k)) {
          openCells.add(k);
        }
      }
    }
    openCells.shuffle(_random);

    // Fill ~40-50% of open cells with destructible walls, more at higher levels
    final fillRatio = (0.45 + _level * 0.02).clamp(0.45, 0.65);
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

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    // Replenish bombs over time (1 every 5 seconds if below max)
    // (handled in _explodeBomb — bombs replenish on detonation)

    // Update bomb timers
    for (final bomb in _bombs) {
      bomb.timer -= dt;
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

    // Check wall collision
    if (_isBlocked(newHead.x, newHead.y)) {
      return; // Can't move into wall, stay put
    }

    // Check bomb collision — can't walk through bombs
    if (_isBombAt(newHead.x, newHead.y)) {
      return;
    }

    // Check self collision
    if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
      return;
    }

    // Check enemy collision — touching enemy = death
    if (_enemies.any((e) => e.position.x == newHead.x && e.position.y == newHead.y)) {
      _die();
      return;
    }

    // Move snake (fixed length)
    snakeSegments.insert(0, newHead);
    final tail = snakeSegments.last;
    if (snakeSegments.length > snakeLength) {
      snakeSegments.removeLast();
    }

    // Drop bomb on request (Space key) at tail position
    if (_dropBombRequested) {
      _dropBombRequested = false;
      if (_bombsAvailable > 0 &&
          !_isWall(tail.x, tail.y) &&
          !_isBombAt(tail.x, tail.y) &&
          !snakeSegments.any((s) => s.x == tail.x && s.y == tail.y)) {
        _bombs.add(_Bomb(position: tail, timer: bombFuseTime));
        _bombsAvailable--;
      }
    }

    // Check if snake is in an active explosion
    if (_isInExplosion(newHead)) {
      _die();
      return;
    }
  }

  void _explodeBomb(_Bomb bomb) {
    // Replenish one bomb when it explodes
    if (_bombsAvailable < _maxBombs) {
      _bombsAvailable++;
    }
    final cells = _getExplosionCells(bomb.position);

    // Create explosion visual
    _explosions.add(_Explosion(cells: cells, timer: _explosionDuration));

    // Destroy destructible walls
    for (final cell in cells) {
      final k = _key(cell.x, cell.y);
      if (destructibleWalls.contains(k)) {
        destructibleWalls.remove(k);
        score += 5;
        onScoreChanged(score);
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

  List<Point<int>> _getExplosionCells(Point<int> center) {
    final cells = <Point<int>>[center];
    // Four directions
    final dirs = [Point(0, -1), Point(0, 1), Point(-1, 0), Point(1, 0)];
    for (final dir in dirs) {
      for (int i = 1; i <= bombExplosionRadius; i++) {
        final x = center.x + dir.x * i;
        final y = center.y + dir.y * i;
        if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) break;
        final k = _key(x, y);
        if (indestructibleWalls.contains(k)) break; // Blocked by indestructible
        cells.add(Point(x, y));
        if (destructibleWalls.contains(k)) break; // Destroys wall but stops
      }
    }
    return cells;
  }

  bool _isInExplosion(Point<int> pos) {
    return _explosions.any((exp) =>
      exp.cells.any((c) => c.x == pos.x && c.y == pos.y)
    );
  }

  void _tickEnemies() {
    for (final enemy in _enemies) {
      // Simple random wandering AI
      final dirs = <Point<int>>[];
      for (final d in [Point(0, -1), Point(0, 1), Point(-1, 0), Point(1, 0)]) {
        final nx = enemy.position.x + d.x;
        final ny = enemy.position.y + d.y;
        if (!_isBlocked(nx, ny) && !_isBombAt(nx, ny)) {
          dirs.add(d);
        }
      }
      if (dirs.isEmpty) continue;

      // Prefer continuing in same direction if possible
      if (enemy.lastDir != null && dirs.any((d) => d.x == enemy.lastDir!.x && d.y == enemy.lastDir!.y) && _random.nextDouble() < 0.7) {
        final d = enemy.lastDir!;
        enemy.position = Point(enemy.position.x + d.x, enemy.position.y + d.y);
      } else {
        final d = dirs[_random.nextInt(dirs.length)];
        enemy.position = Point(enemy.position.x + d.x, enemy.position.y + d.y);
        enemy.lastDir = d;
      }
    }

    // Check if enemy walked into snake — death
    final head = snakeSegments.first;
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

    // HUD: Level and enemies remaining
    final levelTp = TextPainter(
      text: TextSpan(
        text: 'LEVEL $_level',
        style: TextStyle(
          color: mode.snakeColor.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    levelTp.paint(canvas, Offset(boardOffset.x + 4, boardOffset.y - 16));

    final bombTp = TextPainter(
      text: TextSpan(
        text: 'BOMBS: $_bombsAvailable/$_maxBombs',
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
      Offset(boardOffset.x + (gridWidth * cs - bombTp.width) / 2, boardOffset.y - 16),
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
      Offset(boardOffset.x + gridWidth * cs - enemyTp.width - 4, boardOffset.y - 16),
    );
  }
}

class _Bomb {
  final Point<int> position;
  double timer;

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
