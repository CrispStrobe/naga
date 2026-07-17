import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/dungeon_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Roguelike dungeon crawler — explore procedurally generated rooms,
/// fight monsters, collect loot, and descend deeper.
class DungeonGame extends FlameGame with KeyboardEvents {
  final DungeonMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  static const int gridWidth = 20;
  static const int gridHeight = 28;
  late double cellSize;
  late Vector2 boardOffset;

  // Snake — TURN-BASED: one move per keypress
  List<Point<int>> snakeSegments = [];
  Direction currentDirection = Direction.right;
  GameState gameState = GameState.playing;
  int score = 0;

  // Dungeon state
  int _roomNumber = 1;
  late List<List<_CellType>> _grid;
  Point<int> _exitPos = const Point(0, 0);
  bool _exitOpen = false;

  // Monsters — move after player moves
  List<_Monster> _monsters = [];

  // Collectibles
  List<_Collectible> _collectibles = [];

  // Traps
  List<_Trap> _traps = [];

  // Weapon inventory
  int swordHits = 0; // bump-kills that cost no HP
  int arrows = 0; // ranged shots (Space / action button)
  int hammerCharges = 0; // break walls by walking into them
  int shieldBlocks = 0; // absorb hits that would cost a segment
  static const int _inventoryCap = 9;

  // Arrow shot visual (fades in real time)
  List<Point<int>> _arrowTrace = [];
  double _arrowTraceTimer = 0;
  static const double _arrowTraceDuration = 0.35;

  final Random _random = Random();

  DungeonGame({
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
    _roomNumber = 1;
    gameState = GameState.playing;
    currentDirection = Direction.right;
    swordHits = 2; // small starting loadout so room 1 is survivable
    arrows = 0;
    hammerCharges = 0;
    shieldBlocks = 0;
    _arrowTrace = [];
    _arrowTraceTimer = 0;
    _generateRoom();
  }

  // ---------------------------------------------------------------------------
  // Room generation
  // ---------------------------------------------------------------------------

  void _generateRoom() {
    // Initialize solid grid
    _grid = List.generate(
      gridHeight,
      (_) => List.filled(gridWidth, _CellType.wall),
    );

    _monsters = [];
    _collectibles = [];
    _traps = [];
    _exitOpen = false;

    // Carve rectangular rooms
    final roomCount = min(3 + _roomNumber ~/ 2, 5);
    final List<Rect> rooms = [];

    for (int i = 0; i < roomCount; i++) {
      for (int attempt = 0; attempt < 20; attempt++) {
        final rw = 4 + _random.nextInt(5); // 4-8
        final rh = 4 + _random.nextInt(5); // 4-8
        final rx = 1 + _random.nextInt(gridWidth - rw - 2);
        final ry = 3 + _random.nextInt(gridHeight - rh - 5); // leave HUD space
        final candidate = Rect.fromLTWH(
          rx.toDouble(),
          ry.toDouble(),
          rw.toDouble(),
          rh.toDouble(),
        );

        // Check overlap (with 1-cell padding)
        final padded = candidate.inflate(1);
        bool overlaps = rooms.any((r) => r.overlaps(padded));
        if (!overlaps) {
          rooms.add(candidate);
          _carveRect(rx, ry, rw, rh);
          break;
        }
      }
    }

    // If we ended up with fewer than 2 rooms, force a second one
    if (rooms.length < 2) {
      final rx = 2;
      final ry = 4;
      rooms.add(Rect.fromLTWH(rx.toDouble(), ry.toDouble(), 5, 5));
      _carveRect(rx, ry, 5, 5);
      if (rooms.length < 2) {
        rooms.add(Rect.fromLTWH(12, 16, 5, 5));
        _carveRect(12, 16, 5, 5);
      }
    }

    // Connect rooms with corridors
    for (int i = 0; i < rooms.length - 1; i++) {
      _carveCorridor(
        rooms[i].center.dx.toInt(),
        rooms[i].center.dy.toInt(),
        rooms[i + 1].center.dx.toInt(),
        rooms[i + 1].center.dy.toInt(),
      );
    }

    // Place snake in first room
    final firstRoom = rooms.first;
    final startX = firstRoom.center.dx.toInt();
    final startY = firstRoom.center.dy.toInt();
    snakeSegments = [
      Point(startX, startY),
      Point(startX - 1, startY),
      Point(startX - 2, startY),
    ];
    // Ensure snake cells are carved
    for (final seg in snakeSegments) {
      if (_inBounds(seg.x, seg.y)) {
        _grid[seg.y][seg.x] = _CellType.floor;
      }
    }

    currentDirection = Direction.right;

    // Place exit in last room
    final lastRoom = rooms.last;
    _exitPos = Point(
      lastRoom.center.dx.toInt(),
      lastRoom.center.dy.toInt(),
    );
    // Make sure exit is on floor
    if (_inBounds(_exitPos.x, _exitPos.y)) {
      _grid[_exitPos.y][_exitPos.x] = _CellType.floor;
    }

    // Spawn monsters in corridors and rooms (not first room)
    final monsterCount = min(2 + _roomNumber, 5);
    _spawnMonsters(monsterCount, rooms);

    // Scatter collectibles
    _spawnCollectibles(rooms);

    // Place traps (more in later rooms)
    final trapCount = min(1 + _roomNumber, 6);
    _spawnTraps(trapCount);
  }

  void _carveRect(int x, int y, int w, int h) {
    for (int dy = 0; dy < h; dy++) {
      for (int dx = 0; dx < w; dx++) {
        final cx = x + dx;
        final cy = y + dy;
        if (_inBounds(cx, cy)) {
          _grid[cy][cx] = _CellType.floor;
        }
      }
    }
  }

  void _carveCorridor(int x1, int y1, int x2, int y2) {
    // L-shaped corridor, 2 cells wide so snake can turn
    int cx = x1;
    int cy = y1;
    final dx = x2 > x1 ? 1 : -1;
    while (cx != x2) {
      if (_inBounds(cx, cy)) _grid[cy][cx] = _CellType.floor;
      if (_inBounds(cx, cy + 1)) _grid[cy + 1][cx] = _CellType.floor;
      cx += dx;
    }
    final dy = y2 > y1 ? 1 : -1;
    while (cy != y2) {
      if (_inBounds(cx, cy)) _grid[cy][cx] = _CellType.floor;
      if (_inBounds(cx + 1, cy)) _grid[cy][cx + 1] = _CellType.floor;
      cy += dy;
    }
    if (_inBounds(cx, cy)) _grid[cy][cx] = _CellType.floor;
  }

  bool _inBounds(int x, int y) =>
      x >= 0 && x < gridWidth && y >= 0 && y < gridHeight;

  bool _isFloor(int x, int y) =>
      _inBounds(x, y) && _grid[y][x] == _CellType.floor;

  List<Point<int>> _getFloorCells() {
    final cells = <Point<int>>[];
    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        if (_grid[y][x] == _CellType.floor) {
          cells.add(Point(x, y));
        }
      }
    }
    return cells;
  }

  bool _isCellOccupied(Point<int> pos) {
    // Check snake
    if (snakeSegments.any((s) => s.x == pos.x && s.y == pos.y)) return true;
    // Check exit
    if (pos.x == _exitPos.x && pos.y == _exitPos.y) return true;
    // Check monsters
    if (_monsters.any((m) => m.position.x == pos.x && m.position.y == pos.y)) {
      return true;
    }
    // Check collectibles
    if (_collectibles
        .any((c) => c.position.x == pos.x && c.position.y == pos.y)) {
      return true;
    }
    // Check traps
    if (_traps.any((t) => t.position.x == pos.x && t.position.y == pos.y)) {
      return true;
    }
    return false;
  }

  Point<int>? _findFreeFloorCell() {
    final floors = _getFloorCells();
    floors.shuffle(_random);
    for (final cell in floors) {
      if (!_isCellOccupied(cell)) return cell;
    }
    return null;
  }

  _MonsterType _rollMonsterType() {
    final roll = _random.nextDouble();
    if (_roomNumber >= 3 && roll < 0.25) return _MonsterType.brute;
    if (_roomNumber >= 2 && roll < 0.55) return _MonsterType.runner;
    return _MonsterType.grunt;
  }

  void _spawnMonsters(int count, List<Rect> rooms) {
    for (int i = 0; i < count; i++) {
      final pos = _findFreeFloorCell();
      if (pos != null) {
        final type = _rollMonsterType();
        // Avoid spawning in the first room (give player breathing room)
        final firstRoom = rooms.first;
        if (firstRoom.contains(Offset(pos.x.toDouble(), pos.y.toDouble()))) {
          // Try again but accept if no alternative
          final alt = _findFreeFloorCell();
          if (alt != null &&
              !firstRoom
                  .contains(Offset(alt.x.toDouble(), alt.y.toDouble()))) {
            _monsters.add(_Monster(position: alt, type: type));
            continue;
          }
        }
        _monsters.add(_Monster(position: pos, type: type));
      }
    }
  }

  void _spawnCollectibles(List<Rect> rooms) {
    // Coins: 4-8
    final coinCount = 4 + _random.nextInt(5);
    for (int i = 0; i < coinCount; i++) {
      final pos = _findFreeFloorCell();
      if (pos != null) {
        _collectibles.add(_Collectible(
          position: pos,
          type: _CollectibleType.coin,
        ));
      }
    }

    // Health potions: 1-2
    final potionCount = 1 + _random.nextInt(2);
    for (int i = 0; i < potionCount; i++) {
      final pos = _findFreeFloorCell();
      if (pos != null) {
        _collectibles.add(_Collectible(
          position: pos,
          type: _CollectibleType.potion,
        ));
      }
    }

    // Weapon pickups: 1-2 per room, random type
    final weaponCount = 1 + _random.nextInt(2);
    for (int i = 0; i < weaponCount; i++) {
      final pos = _findFreeFloorCell();
      if (pos != null) {
        final roll = _random.nextDouble();
        final _CollectibleType type;
        if (roll < 0.35) {
          type = _CollectibleType.sword;
        } else if (roll < 0.65) {
          type = _CollectibleType.bow;
        } else if (roll < 0.80) {
          type = _CollectibleType.hammer;
        } else {
          type = _CollectibleType.shield;
        }
        _collectibles.add(_Collectible(position: pos, type: type));
      }
    }
  }

  void _spawnTraps(int count) {
    for (int i = 0; i < count; i++) {
      final pos = _findFreeFloorCell();
      if (pos != null) {
        _traps.add(_Trap(position: pos));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Update loop
  // ---------------------------------------------------------------------------

  int _turnCount = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (_arrowTraceTimer > 0) {
      _arrowTraceTimer -= dt;
      if (_arrowTraceTimer <= 0) _arrowTrace = [];
    }
  }

  /// Called on each keypress — one turn of the game.
  void _doTurn(Direction dir) {
    if (gameState != GameState.playing) return;
    if (snakeSegments.isEmpty) return;

    currentDirection = dir;
    final head = snakeSegments.first;
    late Point<int> newHead;

    switch (dir) {
      case Direction.up:
        newHead = Point(head.x, head.y - 1);
      case Direction.down:
        newHead = Point(head.x, head.y + 1);
      case Direction.left:
        newHead = Point(head.x - 1, head.y);
      case Direction.right:
        newHead = Point(head.x + 1, head.y);
    }

    // Wall collision — hammer smashes through, otherwise blocked (no turn)
    if (!_inBounds(newHead.x, newHead.y) ||
        _grid[newHead.y][newHead.x] == _CellType.wall) {
      if (_inBounds(newHead.x, newHead.y) && hammerCharges > 0) {
        hammerCharges--;
        _grid[newHead.y][newHead.x] = _CellType.floor;
        _endTurn(); // smashing costs the turn; snake moves in next turn
      }
      return;
    }

    // Self collision
    if (snakeSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
      _die();
      return;
    }

    // Monster in the way — bump attack. Sword absorbs the counter-hit.
    final bumped = _monsters
        .where((m) => m.position.x == newHead.x && m.position.y == newHead.y)
        .toList();
    if (bumped.isNotEmpty) {
      _attackMonster(bumped.first);
      if (gameState != GameState.playing) return;
      // Survivors (brutes) hold the cell: the attack costs the turn instead
      if (_monsters.any(
          (m) => m.position.x == newHead.x && m.position.y == newHead.y)) {
        _endTurn();
        return;
      }
    }

    bool grew = false;

    // Check collectibles
    _collectibles.removeWhere((c) {
      if (c.position.x == newHead.x && c.position.y == newHead.y) {
        switch (c.type) {
          case _CollectibleType.coin:
            score += 10;
          case _CollectibleType.potion:
            grew = true; // +1 segment
          case _CollectibleType.sword:
            swordHits = min(swordHits + 3, _inventoryCap);
          case _CollectibleType.bow:
            arrows = min(arrows + 3, _inventoryCap);
          case _CollectibleType.hammer:
            hammerCharges = min(hammerCharges + 2, _inventoryCap);
          case _CollectibleType.shield:
            shieldBlocks = min(shieldBlocks + 2, _inventoryCap);
        }
        onScoreChanged(score);
        return true;
      }
      return false;
    });

    // Check trap collision
    if (_isTrapsActive()) {
      for (final trap in _traps) {
        if (trap.position.x == newHead.x && trap.position.y == newHead.y) {
          _takeDamage();
          break;
        }
      }
    }
    if (gameState != GameState.playing) return;

    // Check exit
    if (_exitOpen &&
        newHead.x == _exitPos.x &&
        newHead.y == _exitPos.y) {
      score += 100; // room bonus
      onScoreChanged(score);
      _roomNumber++;
      _generateRoom();
      return;
    }

    // Move snake
    snakeSegments.insert(0, newHead);
    if (!grew) {
      snakeSegments.removeLast();
    }

    _endTurn();
  }

  /// One melee hit on a monster. The sword absorbs the counter-hit;
  /// without it, striking costs a segment (shield blocks first).
  void _attackMonster(_Monster monster) {
    monster.hp--;
    if (swordHits > 0) {
      swordHits--;
    } else {
      _takeDamage();
    }
    if (monster.hp <= 0) {
      _monsters.remove(monster);
      score += monster.type.scoreValue;
      onScoreChanged(score);
    }
  }

  /// Fired from Space / the action button. Costs a turn and one arrow;
  /// hits the first monster in a straight line from the head.
  void fireArrow() {
    if (gameState != GameState.playing) return;
    if (arrows <= 0 || snakeSegments.isEmpty) return;
    arrows--;

    final trace = <Point<int>>[];
    var pos = snakeSegments.first;
    while (true) {
      switch (currentDirection) {
        case Direction.up:
          pos = Point(pos.x, pos.y - 1);
        case Direction.down:
          pos = Point(pos.x, pos.y + 1);
        case Direction.left:
          pos = Point(pos.x - 1, pos.y);
        case Direction.right:
          pos = Point(pos.x + 1, pos.y);
      }
      if (!_isFloor(pos.x, pos.y)) break;
      trace.add(pos);
      final hit = _monsters
          .where((m) => m.position.x == pos.x && m.position.y == pos.y)
          .toList();
      if (hit.isNotEmpty) {
        final monster = hit.first;
        monster.hp--;
        if (monster.hp <= 0) {
          _monsters.remove(monster);
          score += monster.type.scoreValue;
          onScoreChanged(score);
        }
        break;
      }
    }
    _arrowTrace = trace;
    _arrowTraceTimer = _arrowTraceDuration;

    _endTurn();
  }

  /// After the player's action, monsters take their turn.
  void _endTurn() {
    // Open exit if all monsters dead
    if (_monsters.isEmpty && !_exitOpen) {
      _exitOpen = true;
    }
    if (snakeSegments.isEmpty) {
      _die();
      return;
    }
    _turnCount++;
    _tickMonsters();
  }

  void _takeDamage() {
    if (shieldBlocks > 0) {
      shieldBlocks--;
      return;
    }
    if (snakeSegments.length > 1) {
      snakeSegments.removeLast();
    } else {
      _die();
    }
  }

  bool _isTrapsActive() {
    // Traps active every 6th turn for 1 turn
    return _turnCount % 6 == 5;
  }

  void _tickMonsters() {
    if (snakeSegments.isEmpty) return;
    final head = snakeSegments.first;

    for (final monster in _monsters) {
      // Brutes are slow: they only move every other turn
      if (monster.type == _MonsterType.brute && _turnCount.isOdd) continue;

      // Runners sprint 2 cells when chasing from a distance
      final dx = head.x - monster.position.x;
      final dy = head.y - monster.position.y;
      final dist = dx.abs() + dy.abs();
      final chasing = dist <= monster.type.chaseRadius;
      final steps =
          (monster.type == _MonsterType.runner && chasing && dist > 3) ? 2 : 1;

      for (int s = 0; s < steps; s++) {
        final nextPos = chasing
            ? _monsterChaseStep(monster.position, head)
            : _monsterWanderStep(monster.position);

        // Only move if floor and not occupied by another monster
        if (_isFloor(nextPos.x, nextPos.y) &&
            !_monsters.any((m) =>
                m != monster &&
                m.position.x == nextPos.x &&
                m.position.y == nextPos.y)) {
          monster.position = nextPos;
        }
        // Stop sprinting the moment the snake is reached
        if (monster.position.x == head.x && monster.position.y == head.y) {
          break;
        }
      }
    }

    // Check if any monster is on a snake body segment (not head) = damage
    for (final monster in _monsters.toList()) {
      for (int i = 1; i < snakeSegments.length; i++) {
        if (monster.position.x == snakeSegments[i].x &&
            monster.position.y == snakeSegments[i].y) {
          _takeDamage();
          break;
        }
      }
      if (gameState != GameState.playing) return;
      // Monster walks onto snake head = it attacks; sword counters
      if (monster.position.x == head.x && monster.position.y == head.y) {
        _attackMonster(monster);
        if (gameState != GameState.playing) return;
      }
    }

    if (_monsters.isEmpty && !_exitOpen) {
      _exitOpen = true;
    }
  }

  Point<int> _monsterChaseStep(Point<int> from, Point<int> target) {
    final dx = target.x - from.x;
    final dy = target.y - from.y;

    // Prefer the axis with larger distance
    final candidates = <Point<int>>[];
    if (dx.abs() >= dy.abs()) {
      candidates.add(Point(from.x + dx.sign, from.y));
      candidates.add(Point(from.x, from.y + dy.sign));
    } else {
      candidates.add(Point(from.x, from.y + dy.sign));
      candidates.add(Point(from.x + dx.sign, from.y));
    }

    for (final c in candidates) {
      if (_isFloor(c.x, c.y)) return c;
    }
    return from;
  }

  Point<int> _monsterWanderStep(Point<int> from) {
    final dirs = [
      Point(from.x + 1, from.y),
      Point(from.x - 1, from.y),
      Point(from.x, from.y + 1),
      Point(from.x, from.y - 1),
    ];
    dirs.shuffle(_random);
    for (final d in dirs) {
      if (_isFloor(d.x, d.y)) return d;
    }
    return from;
  }

  void _die() {
    gameState = GameState.gameOver;
    onGameOver();
  }

  /// In turn-based mode, each call = one step in the given direction.
  void changeDirection(Direction dir) {
    _doTurn(dir);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        if (gameState == GameState.playing) {
          gameState = GameState.paused;
        } else if (gameState == GameState.paused) {
          gameState = GameState.playing;
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.space) {
        fireArrow();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW) {
        _doTurn(Direction.up);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.keyS) {
        _doTurn(Direction.down);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        _doTurn(Direction.left);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        _doTurn(Direction.right);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

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

    _renderWallsAndFloor(canvas, cs);
    _renderTraps(canvas, cs);
    _renderCollectibles(canvas, cs);
    _renderExit(canvas, cs);
    _renderMonsters(canvas, cs);
    _renderArrowTrace(canvas, cs);
    _renderSnake(canvas, cs);
    _renderHUD(canvas, cs);
    _renderLegend(canvas, cs);
  }

  void _renderArrowTrace(Canvas canvas, double cs) {
    if (_arrowTrace.isEmpty || _arrowTraceTimer <= 0) return;
    final alpha = (_arrowTraceTimer / _arrowTraceDuration).clamp(0.0, 1.0);
    final paint = Paint()..color = mode.bowColor.withOpacity(alpha * 0.8);
    for (final cell in _arrowTrace) {
      final sp = _gridToScreen(cell);
      canvas.drawRect(
        Rect.fromLTWH(
            sp.x + cs * 0.35, sp.y + cs * 0.35, cs * 0.3, cs * 0.3),
        paint,
      );
    }
  }

  void _renderWallsAndFloor(Canvas canvas, double cs) {
    final wallPaint = Paint()..color = mode.wallColor;
    final wallHighlight = Paint()..color = mode.wallColor.withOpacity(0.7);
    final floorPaint = Paint()..color = mode.floorColor;

    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        final sp = _gridToScreen(Point(x, y));
        final rect = Rect.fromLTWH(sp.x, sp.y, cs, cs);

        if (_grid[y][x] == _CellType.wall) {
          canvas.drawRect(rect, wallPaint);
          // Stone texture: subtle lighter edge on top-left
          final edgeRect = Rect.fromLTWH(sp.x, sp.y, cs, cs * 0.15);
          canvas.drawRect(edgeRect, wallHighlight);
        } else {
          canvas.drawRect(rect, floorPaint);
          // Subtle floor tile lines
          final linePaint = Paint()
            ..color = const Color(0xFF333333)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5;
          canvas.drawRect(rect, linePaint);
        }
      }
    }
  }

  void _renderTraps(Canvas canvas, double cs) {
    final active = _isTrapsActive();
    for (final trap in _traps) {
      final sp = _gridToScreen(trap.position);
      final center = Offset(sp.x + cs / 2, sp.y + cs / 2);

      if (active) {
        // Active: bright orange spikes
        final paint = Paint()..color = mode.trapColor;
        // Draw X-shaped spikes
        final halfSize = cs * 0.35;
        final path = Path()
          ..moveTo(center.dx, center.dy - halfSize)
          ..lineTo(center.dx + halfSize * 0.3, center.dy - halfSize * 0.3)
          ..lineTo(center.dx + halfSize, center.dy)
          ..lineTo(center.dx + halfSize * 0.3, center.dy + halfSize * 0.3)
          ..lineTo(center.dx, center.dy + halfSize)
          ..lineTo(center.dx - halfSize * 0.3, center.dy + halfSize * 0.3)
          ..lineTo(center.dx - halfSize, center.dy)
          ..lineTo(center.dx - halfSize * 0.3, center.dy - halfSize * 0.3)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        // Inactive: dim indicator
        final paint = Paint()..color = mode.trapColor.withOpacity(0.25);
        canvas.drawCircle(center, cs * 0.15, paint);
      }
    }
  }

  void _renderCollectibles(Canvas canvas, double cs) {
    for (final c in _collectibles) {
      final sp = _gridToScreen(c.position);
      final center = Offset(sp.x + cs / 2, sp.y + cs / 2);

      switch (c.type) {
        case _CollectibleType.coin:
          // Yellow circle with glow
          final glowPaint = Paint()
            ..color = mode.coinColor.withOpacity(0.3);
          canvas.drawCircle(center, cs * 0.35, glowPaint);
          final paint = Paint()..color = mode.coinColor;
          canvas.drawCircle(center, cs * 0.22, paint);

        case _CollectibleType.potion:
          // Red circle (health)
          final glowPaint = Paint()
            ..color = mode.potionColor.withOpacity(0.3);
          canvas.drawCircle(center, cs * 0.35, glowPaint);
          final paint = Paint()..color = mode.potionColor;
          canvas.drawCircle(center, cs * 0.22, paint);
          // Cross symbol
          final crossPaint = Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(center.dx - cs * 0.1, center.dy),
            Offset(center.dx + cs * 0.1, center.dy),
            crossPaint,
          );
          canvas.drawLine(
            Offset(center.dx, center.dy - cs * 0.1),
            Offset(center.dx, center.dy + cs * 0.1),
            crossPaint,
          );

        case _CollectibleType.sword:
          // Diamond shape (blue)
          final glowPaint = Paint()
            ..color = mode.weaponColor.withOpacity(0.3);
          canvas.drawCircle(center, cs * 0.35, glowPaint);
          final paint = Paint()..color = mode.weaponColor;
          final halfSize = cs * 0.25;
          final path = Path()
            ..moveTo(center.dx, center.dy - halfSize)
            ..lineTo(center.dx + halfSize, center.dy)
            ..lineTo(center.dx, center.dy + halfSize)
            ..lineTo(center.dx - halfSize, center.dy)
            ..close();
          canvas.drawPath(path, paint);

        case _CollectibleType.bow:
          // Upward triangle (purple)
          final glowPaint = Paint()..color = mode.bowColor.withOpacity(0.3);
          canvas.drawCircle(center, cs * 0.35, glowPaint);
          final paint = Paint()..color = mode.bowColor;
          final halfSize = cs * 0.25;
          final path = Path()
            ..moveTo(center.dx, center.dy - halfSize)
            ..lineTo(center.dx + halfSize, center.dy + halfSize)
            ..lineTo(center.dx - halfSize, center.dy + halfSize)
            ..close();
          canvas.drawPath(path, paint);

        case _CollectibleType.hammer:
          // T-shape (steel grey)
          final glowPaint = Paint()..color = mode.hammerColor.withOpacity(0.3);
          canvas.drawCircle(center, cs * 0.35, glowPaint);
          final paint = Paint()..color = mode.hammerColor;
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset(center.dx, center.dy - cs * 0.12),
                width: cs * 0.44,
                height: cs * 0.2),
            paint,
          );
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset(center.dx, center.dy + cs * 0.08),
                width: cs * 0.12,
                height: cs * 0.36),
            paint,
          );

        case _CollectibleType.shield:
          // Ringed circle (silver)
          final glowPaint = Paint()..color = mode.shieldColor.withOpacity(0.3);
          canvas.drawCircle(center, cs * 0.35, glowPaint);
          final paint = Paint()..color = mode.shieldColor;
          canvas.drawCircle(center, cs * 0.2, paint);
          final ringPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawCircle(center, cs * 0.26, ringPaint);
      }
    }
  }

  void _renderExit(Canvas canvas, double cs) {
    final sp = _gridToScreen(_exitPos);
    final center = Offset(sp.x + cs / 2, sp.y + cs / 2);

    if (_exitOpen) {
      // Glowing green cell
      final glowPaint = Paint()..color = mode.exitColor.withOpacity(0.4);
      canvas.drawCircle(center, cs * 0.6, glowPaint);
      final paint = Paint()..color = mode.exitColor;
      canvas.drawRect(
        Rect.fromLTWH(sp.x + cs * 0.1, sp.y + cs * 0.1, cs * 0.8, cs * 0.8),
        paint,
      );
      // Door icon: arch
      final archPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCenter(center: center, width: cs * 0.4, height: cs * 0.4),
        3.14,
        3.14,
        false,
        archPaint,
      );
    } else {
      // Locked door: gray
      final paint = Paint()..color = const Color(0xFF555555);
      canvas.drawRect(
        Rect.fromLTWH(sp.x + cs * 0.15, sp.y + cs * 0.15, cs * 0.7, cs * 0.7),
        paint,
      );
      // Lock symbol
      final lockPaint = Paint()
        ..color = const Color(0xFF888888)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(
        Offset(center.dx, center.dy - cs * 0.05),
        cs * 0.1,
        lockPaint,
      );
    }
  }

  Color _monsterBodyColor(_MonsterType type) {
    switch (type) {
      case _MonsterType.grunt:
        return mode.monsterColor;
      case _MonsterType.runner:
        return mode.runnerColor;
      case _MonsterType.brute:
        return mode.bruteColor;
    }
  }

  void _renderMonsters(Canvas canvas, double cs) {
    for (final monster in _monsters) {
      final sp = _gridToScreen(monster.position);

      // Body: rounded rectangle, color by type
      final bodyPaint = Paint()..color = _monsterBodyColor(monster.type);
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            sp.x + cs * 0.1, sp.y + cs * 0.15, cs * 0.8, cs * 0.7),
        Radius.circular(cs * 0.15),
      );
      canvas.drawRRect(bodyRect, bodyPaint);

      // Red glowing eyes
      final eyePaint = Paint()..color = mode.monsterEyeColor;
      canvas.drawCircle(
        Offset(sp.x + cs * 0.35, sp.y + cs * 0.35),
        cs * 0.07,
        eyePaint,
      );
      canvas.drawCircle(
        Offset(sp.x + cs * 0.65, sp.y + cs * 0.35),
        cs * 0.07,
        eyePaint,
      );

      // Eye glow
      final eyeGlow = Paint()..color = mode.monsterEyeColor.withOpacity(0.3);
      canvas.drawCircle(
        Offset(sp.x + cs * 0.35, sp.y + cs * 0.35),
        cs * 0.12,
        eyeGlow,
      );
      canvas.drawCircle(
        Offset(sp.x + cs * 0.65, sp.y + cs * 0.35),
        cs * 0.12,
        eyeGlow,
      );

      // Brute HP pips
      if (monster.type == _MonsterType.brute && monster.hp > 1) {
        final pipPaint = Paint()..color = Colors.white;
        canvas.drawCircle(
          Offset(sp.x + cs * 0.5, sp.y + cs * 0.62),
          cs * 0.06,
          pipPaint,
        );
      }

      // Jagged bottom (monster feet/tentacles)
      final jaggedPaint = Paint()..color = _monsterBodyColor(monster.type);
      final jaggedPath = Path();
      final bottom = sp.y + cs * 0.85;
      jaggedPath.moveTo(sp.x + cs * 0.1, bottom);
      for (double fx = 0.1; fx <= 0.9; fx += 0.2) {
        jaggedPath.lineTo(sp.x + cs * (fx + 0.1), bottom + cs * 0.1);
        jaggedPath.lineTo(sp.x + cs * (fx + 0.2), bottom);
      }
      jaggedPath.close();
      canvas.drawPath(jaggedPath, jaggedPaint);
    }
  }

  void _renderSnake(Canvas canvas, double cs) {
    if (snakeSegments.isEmpty) return;

    final snakePaint = Paint()..color = mode.snakeColor;
    final headPaint = Paint()..color = mode.snakeColor;

    for (int i = 0; i < snakeSegments.length; i++) {
      final seg = snakeSegments[i];
      final sp = _gridToScreen(seg);
      final paint = i == 0 ? headPaint : snakePaint;
      final inset = cs * 0.05;
      canvas.drawRect(
        Rect.fromLTWH(sp.x + inset, sp.y + inset, cs - inset * 2, cs - inset * 2),
        paint,
      );
    }

    // Eyes on head
    final head = snakeSegments.first;
    final hsp = _gridToScreen(head);
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;
    final cx = hsp.x + cs / 2;
    final cy = hsp.y + cs / 2;

    double e1x, e1y, e2x, e2y;
    switch (currentDirection) {
      case Direction.right:
        e1x = cx + cs * 0.15; e1y = cy - cs * 0.15;
        e2x = cx + cs * 0.15; e2y = cy + cs * 0.15;
      case Direction.left:
        e1x = cx - cs * 0.15; e1y = cy - cs * 0.15;
        e2x = cx - cs * 0.15; e2y = cy + cs * 0.15;
      case Direction.up:
        e1x = cx - cs * 0.15; e1y = cy - cs * 0.15;
        e2x = cx + cs * 0.15; e2y = cy - cs * 0.15;
      case Direction.down:
        e1x = cx - cs * 0.15; e1y = cy + cs * 0.15;
        e2x = cx + cs * 0.15; e2y = cy + cs * 0.15;
    }

    canvas.drawCircle(Offset(e1x, e1y), cs * 0.1, eyePaint);
    canvas.drawCircle(Offset(e2x, e2y), cs * 0.1, eyePaint);
    canvas.drawCircle(Offset(e1x, e1y), cs * 0.05, pupilPaint);
    canvas.drawCircle(Offset(e2x, e2y), cs * 0.05, pupilPaint);

    // Sword indicator on snake — bump-kills are currently free
    if (swordHits > 0) {
      final buffPaint = Paint()
        ..color = mode.weaponColor.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(
        Offset(hsp.x + cs / 2, hsp.y + cs / 2),
        cs * 0.5,
        buffPaint,
      );
    }
  }

  void _renderHUD(Canvas canvas, double cs) {
    // Paint inside the board's top wall rows (rooms start at y >= 3), so the
    // HUD never overlaps the score bar above the canvas. Score itself is
    // shown by the score bar, not here.
    final hudY = boardOffset.y + 4;

    // Room number
    final roomTp = TextPainter(
      text: TextSpan(
        text: 'ROOM $_roomNumber',
        style: TextStyle(
          color: mode.exitColor.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    roomTp.paint(canvas, Offset(boardOffset.x + 4, hudY));

    // HP (segment count)
    final hpTp = TextPainter(
      text: TextSpan(
        text: 'HP ${snakeSegments.length}',
        style: TextStyle(
          color: mode.potionColor.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final centerX = boardOffset.x + (gridWidth * cs) / 2 - hpTp.width / 2;
    hpTp.paint(canvas, Offset(centerX, hudY));

    // Weapon inventory (right-aligned, only what you carry)
    final parts = <TextSpan>[];
    void addPart(String label, int count, Color color) {
      if (count <= 0) return;
      parts.add(TextSpan(
        text: '${parts.isEmpty ? '' : '  '}$label $count',
        style: TextStyle(
          color: color.withOpacity(0.9),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ));
    }

    addPart('SWD', swordHits, mode.weaponColor);
    addPart('ARW', arrows, mode.bowColor);
    addPart('HAM', hammerCharges, mode.hammerColor);
    addPart('SHD', shieldBlocks, mode.shieldColor);
    if (parts.isNotEmpty) {
      final invTp = TextPainter(
        text: TextSpan(children: parts),
        textDirection: TextDirection.ltr,
      )..layout();
      // Second line, so a full inventory never collides with the HP text
      invTp.paint(canvas, Offset(boardOffset.x + 4, hudY + 16));
    }
  }

  void _renderLegend(Canvas canvas, double cs) {
    final legendX = boardOffset.x + gridWidth * cs + 6;
    final availableWidth = size.x - legendX;
    // Only show legend if there's room to the right of the board
    if (availableWidth < 60) return;

    final iconSize = cs * 0.7;
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.7),
      fontSize: 10,
    );
    final items = <(Color, String, _LegendShape)>[
      (mode.coinColor, 'Coin', _LegendShape.circle),
      (mode.potionColor, '+HP', _LegendShape.circle),
      (mode.weaponColor, 'Sword', _LegendShape.diamond),
      (mode.bowColor, 'Bow', _LegendShape.triangle),
      (mode.hammerColor, 'Hammer', _LegendShape.square),
      (mode.shieldColor, 'Shield', _LegendShape.circle),
      (mode.monsterColor, 'Grunt', _LegendShape.square),
      (mode.runnerColor, 'Runner', _LegendShape.square),
      (mode.bruteColor, 'Brute', _LegendShape.square),
      (mode.trapColor, 'Trap', _LegendShape.star),
      (mode.exitColor, 'Exit', _LegendShape.square),
      (const Color(0xFF555555), 'Locked', _LegendShape.square),
    ];

    var y = boardOffset.y + 2;
    for (final (color, label, shape) in items) {
      final center = Offset(legendX + iconSize / 2, y + iconSize / 2);
      final paint = Paint()..color = color;
      switch (shape) {
        case _LegendShape.circle:
          canvas.drawCircle(center, iconSize * 0.35, paint);
        case _LegendShape.square:
          canvas.drawRect(
            Rect.fromCenter(center: center, width: iconSize * 0.7, height: iconSize * 0.7),
            paint,
          );
        case _LegendShape.diamond:
          final half = iconSize * 0.35;
          final path = Path()
            ..moveTo(center.dx, center.dy - half)
            ..lineTo(center.dx + half, center.dy)
            ..lineTo(center.dx, center.dy + half)
            ..lineTo(center.dx - half, center.dy)
            ..close();
          canvas.drawPath(path, paint);
        case _LegendShape.triangle:
          final half = iconSize * 0.35;
          final path = Path()
            ..moveTo(center.dx, center.dy - half)
            ..lineTo(center.dx + half, center.dy + half)
            ..lineTo(center.dx - half, center.dy + half)
            ..close();
          canvas.drawPath(path, paint);
        case _LegendShape.star:
          final half = iconSize * 0.35;
          final path = Path()
            ..moveTo(center.dx, center.dy - half)
            ..lineTo(center.dx + half * 0.3, center.dy - half * 0.3)
            ..lineTo(center.dx + half, center.dy)
            ..lineTo(center.dx + half * 0.3, center.dy + half * 0.3)
            ..lineTo(center.dx, center.dy + half)
            ..lineTo(center.dx - half * 0.3, center.dy + half * 0.3)
            ..lineTo(center.dx - half, center.dy)
            ..lineTo(center.dx - half * 0.3, center.dy - half * 0.3)
            ..close();
          canvas.drawPath(path, paint);
      }

      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(legendX + iconSize + 4, y + (iconSize - tp.height) / 2));
      y += iconSize + 4;
    }
  }
}

enum _LegendShape { circle, square, diamond, triangle, star }

// ---------------------------------------------------------------------------
// Internal data classes
// ---------------------------------------------------------------------------

enum _CellType { wall, floor }

enum _CollectibleType { coin, potion, sword, bow, hammer, shield }

enum _MonsterType {
  grunt(maxHp: 1, chaseRadius: 5, scoreValue: 50),
  runner(maxHp: 1, chaseRadius: 9, scoreValue: 75),
  brute(maxHp: 2, chaseRadius: 4, scoreValue: 100);

  const _MonsterType({
    required this.maxHp,
    required this.chaseRadius,
    required this.scoreValue,
  });

  final int maxHp;
  final int chaseRadius;
  final int scoreValue;
}

class _Monster {
  Point<int> position;
  final _MonsterType type;
  int hp;

  _Monster({required this.position, this.type = _MonsterType.grunt})
      : hp = type.maxHp;
}

class _Collectible {
  final Point<int> position;
  final _CollectibleType type;
  _Collectible({required this.position, required this.type});
}

class _Trap {
  final Point<int> position;
  _Trap({required this.position});
}
