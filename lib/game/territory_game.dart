import 'dart:collection';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modes/territory_mode.dart';
import 'shared/cached_text.dart';
import 'shared/direction_buffer.dart';
import 'shared/grid_motion.dart';
import 'snake_game.dart' show Direction, GameState;

/// One snake on the board: the player (id 1) or an AI rival (id 2+).
class TerritoryActor {
  final int id;
  final Color color;
  Point<int> head;
  Direction direction;
  bool alive = true;

  /// Cells walked outside the actor's own land since it last left it.
  final List<Point<int>> trail = [];
  final Set<Point<int>> trailCells = {};

  // AI plan: remaining (direction, steps) legs of the current loop.
  final Queue<(Direction, int)> legs = Queue();
  double respawnTimer = 0;

  TerritoryActor(this.id, this.color, this.head, this.direction);

  bool get isPlayer => id == TerritoryGame.playerId;

  void clearTrail() {
    trail.clear();
    trailCells.clear();
  }
}

/// Splix-style territory: leaving your land draws a trail, and returning
/// claims the trail plus every region it seals off. Crossing a rival's
/// trail kills them; a rival crossing yours kills you.
///
/// "Sealed off" means: after the trail becomes land, every connected
/// region of cells the actor does not own, except the largest, is
/// claimed. Walls therefore count as boundaries, as in Splix.
class TerritoryGame extends FlameGame with KeyboardEvents {
  final TerritoryMode mode;
  final VoidCallback onGameOver;
  final VoidCallback onVictory;
  final ValueChanged<int> onScoreChanged;
  final int rivalCount;
  final Random _random;

  static const int gridWidth = 24;
  static const int gridHeight = 32;
  static const int playerId = 1;
  static const double rivalRespawnSeconds = 4;

  TerritoryGame({
    required this.mode,
    required this.onGameOver,
    required this.onVictory,
    required this.onScoreChanged,
    this.rivalCount = 2,
    Random? random,
  }) : _random = random ?? Random();

  late double cellSize;
  late Vector2 boardOffset;

  GameState gameState = GameState.playing;
  bool hasWon = false;
  int score = 0;
  double _tickTimer = 0;
  final _inputs = DirectionBuffer(capacity: 3);

  /// Owner id per cell (row-major); 0 means unclaimed.
  final List<int> _owner = List.filled(gridWidth * gridHeight, 0);
  int _ownerVersion = 0;

  late TerritoryActor player;
  final List<TerritoryActor> rivals = [];

  int ownerAt(Point<int> p) => _owner[p.y * gridWidth + p.x];
  void _setOwner(Point<int> p, int id) => _owner[p.y * gridWidth + p.x] = id;

  int ownedBy(int id) => _owner.where((o) => o == id).length;
  double get playerShare => ownedBy(playerId) / (gridWidth * gridHeight);

  @override
  Color backgroundColor() => Color.lerp(mode.backgroundColor, Colors.black, 0.3)!;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _calculateGrid();
    _startNewGame();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _calculateGrid();
  }

  void _calculateGrid() {
    cellSize = min(size.x / gridWidth, size.y / gridHeight);
    boardOffset = Vector2(
      (size.x - cellSize * gridWidth) / 2,
      (size.y - cellSize * gridHeight) / 2,
    );
  }

  void _startNewGame() {
    _owner.fillRange(0, _owner.length, 0);
    _ownerVersion++;
    gameState = GameState.playing;
    hasWon = false;
    _tickTimer = 0;
    _inputs.clear();
    player = TerritoryActor(playerId, mode.snakeColor, const Point(5, 25), Direction.up);
    _grantHome(player);
    rivals.clear();
    const homes = [Point(18, 6), Point(5, 6), Point(18, 25)];
    for (var i = 0; i < rivalCount; i++) {
      final rival = TerritoryActor(
        playerId + 1 + i,
        mode.rivalColors[i % mode.rivalColors.length],
        homes[i % homes.length],
        Direction.down,
      );
      _grantHome(rival);
      rivals.add(rival);
    }
    _updateScore();
  }

  void restart() {
    _startNewGame();
  }

  /// A fresh 3x3 patch of land around the actor's head.
  void _grantHome(TerritoryActor actor) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        _setOwner(Point(actor.head.x + dx, actor.head.y + dy), actor.id);
      }
    }
    _ownerVersion++;
  }

  /// The score is the player's share of the board in whole percent, the
  /// same number the LAND HUD shows (a raw cell count read as nonsense next
  /// to it).
  void _updateScore() {
    final percent = (playerShare * 100).floor();
    if (percent != score) {
      score = percent;
      onScoreChanged(score);
    }
  }

  bool _inBounds(Point<int> p) =>
      p.x >= 0 && p.y >= 0 && p.x < gridWidth && p.y < gridHeight;

  // ─── Simulation ───────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;
    for (final rival in rivals) {
      if (!rival.alive) {
        rival.respawnTimer -= dt;
        if (rival.respawnTimer <= 0) _respawnRival(rival);
      }
    }
    _tickTimer += dt;
    if (_tickTimer >= mode.tickInterval(score)) {
      _tickTimer = 0;
      tick();
    }
  }

  /// One simultaneous move for every living snake.
  @visibleForTesting
  void tick() {
    player.direction = _inputs.consume(player.direction);
    final movers = [player, ...rivals.where((r) => r.alive)];
    for (final rival in movers.skip(1)) {
      rival.direction = _aiDirection(rival);
    }
    final next = {for (final a in movers) a: gridStep(a.head, a.direction)};

    final dead = <TerritoryActor>{};
    for (final a in movers) {
      final h = next[a]!;
      if (!_inBounds(h) || a.trailCells.contains(h)) dead.add(a);
    }
    for (final a in movers) {
      final h = next[a]!;
      for (final b in movers) {
        if (identical(a, b)) continue;
        // Crossing a rival's trail cuts it down; meeting head-on kills both.
        if (b.trailCells.contains(h)) dead.add(b);
        if (next[b] == h) dead.add(a);
      }
    }

    for (final a in movers) {
      if (dead.contains(a)) continue;
      a.head = next[a]!;
      if (ownerAt(a.head) != a.id) {
        a.trail.add(a.head);
        a.trailCells.add(a.head);
      } else if (a.trail.isNotEmpty) {
        claim(a);
      }
    }

    for (final a in dead) {
      _kill(a);
    }
    if (gameState != GameState.playing) return;
    _updateScore();
    if (playerShare >= mode.winShare) {
      hasWon = true;
      gameState = GameState.gameOver;
      HapticFeedback.mediumImpact();
      onVictory();
    }
  }

  /// Turns [actor]'s trail into land, then claims every region of cells it
  /// does not own except the largest.
  @visibleForTesting
  void claim(TerritoryActor actor) {
    for (final p in actor.trail) {
      _setOwner(p, actor.id);
    }
    actor.clearTrail();

    final seen = List<bool>.filled(_owner.length, false);
    final regions = <List<int>>[];
    for (var start = 0; start < _owner.length; start++) {
      if (seen[start] || _owner[start] == actor.id) continue;
      final region = <int>[];
      final queue = Queue<int>()..add(start);
      seen[start] = true;
      while (queue.isNotEmpty) {
        final i = queue.removeFirst();
        region.add(i);
        final x = i % gridWidth, y = i ~/ gridWidth;
        for (final n in [
          if (x > 0) i - 1,
          if (x < gridWidth - 1) i + 1,
          if (y > 0) i - gridWidth,
          if (y < gridHeight - 1) i + gridWidth,
        ]) {
          if (!seen[n] && _owner[n] != actor.id) {
            seen[n] = true;
            queue.add(n);
          }
        }
      }
      regions.add(region);
    }
    if (regions.length > 1) {
      regions.sort((a, b) => b.length.compareTo(a.length));
      for (final region in regions.skip(1)) {
        for (final i in region) {
          _owner[i] = actor.id;
        }
      }
    }
    _ownerVersion++;
  }

  void _kill(TerritoryActor actor) {
    actor.alive = false;
    actor.clearTrail();
    actor.legs.clear();
    if (actor.isPlayer) {
      gameState = GameState.gameOver;
      HapticFeedback.heavyImpact();
      onGameOver();
      return;
    }
    // A fallen rival's land returns to the jungle.
    for (var i = 0; i < _owner.length; i++) {
      if (_owner[i] == actor.id) _owner[i] = 0;
    }
    _ownerVersion++;
    actor.respawnTimer = rivalRespawnSeconds;
  }

  void _respawnRival(TerritoryActor rival) {
    for (var attempt = 0; attempt < 60; attempt++) {
      final p = Point(2 + _random.nextInt(gridWidth - 4), 2 + _random.nextInt(gridHeight - 4));
      if ((p.x - player.head.x).abs() + (p.y - player.head.y).abs() < 8) continue;
      var clear = true;
      for (var dy = -1; dy <= 1 && clear; dy++) {
        for (var dx = -1; dx <= 1 && clear; dx++) {
          final c = Point(p.x + dx, p.y + dy);
          if (ownerAt(c) != 0 || player.trailCells.contains(c)) clear = false;
        }
      }
      if (!clear) continue;
      rival
        ..head = p
        ..alive = true
        ..direction = Direction.values[_random.nextInt(4)];
      _grantHome(rival);
      return;
    }
    rival.respawnTimer = 1; // Board too crowded; try again shortly.
  }

  // ─── Rival AI ─────────────────────────────────────────────────────────
  // At home, a rival plans a loop: out, sideways, back. Outside with no
  // legs left, it heads for its nearest land. Every step is checked, and
  // the plan gives way to any safe move when it would be fatal.

  Direction _aiDirection(TerritoryActor ai) {
    final atHome = ownerAt(ai.head) == ai.id;
    if (atHome && ai.trail.isEmpty && ai.legs.isEmpty) _planLoop(ai);

    Direction? wanted;
    if (ai.legs.isNotEmpty) {
      final (dir, steps) = ai.legs.removeFirst();
      if (steps > 1) ai.legs.addFirst((dir, steps - 1));
      wanted = dir;
    } else if (ai.trail.isNotEmpty) {
      wanted = _towardHome(ai);
    }

    final options = [
      ?wanted,
      ai.direction,
      ...([...Direction.values]..shuffle(_random)),
    ];
    for (final dir in options) {
      if (areOpposite(dir, ai.direction)) continue;
      if (_safeFor(ai, gridStep(ai.head, dir))) {
        if (dir != wanted) ai.legs.clear(); // The plan broke; head home.
        return dir;
      }
    }
    return ai.direction; // Boxed in.
  }

  void _planLoop(TerritoryActor ai) {
    final out = Direction.values[_random.nextInt(4)];
    final turns = switch (out) {
      Direction.up || Direction.down => [Direction.left, Direction.right],
      Direction.left || Direction.right => [Direction.up, Direction.down],
    };
    final side = turns[_random.nextInt(2)];
    final back = switch (out) {
      Direction.up => Direction.down,
      Direction.down => Direction.up,
      Direction.left => Direction.right,
      Direction.right => Direction.left,
    };
    final reach = 2 + _random.nextInt(5);
    ai.legs
      ..add((out, reach))
      ..add((side, 2 + _random.nextInt(5)))
      ..add((back, reach));
  }

  Direction? _towardHome(TerritoryActor ai) {
    Point<int>? best;
    var bestDistance = 1 << 30;
    for (var i = 0; i < _owner.length; i++) {
      if (_owner[i] != ai.id) continue;
      final p = Point(i % gridWidth, i ~/ gridWidth);
      final d = (p.x - ai.head.x).abs() + (p.y - ai.head.y).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = p;
      }
    }
    if (best == null) return null;
    final dx = best.x - ai.head.x, dy = best.y - ai.head.y;
    if (dx.abs() >= dy.abs() && dx != 0) return dx > 0 ? Direction.right : Direction.left;
    if (dy != 0) return dy > 0 ? Direction.down : Direction.up;
    return null;
  }

  bool _safeFor(TerritoryActor ai, Point<int> p) =>
      _inBounds(p) && !ai.trailCells.contains(p) && p != player.head;

  // ─── Input ────────────────────────────────────────────────────────────

  void changeDirection(Direction dir) {
    _inputs.enqueue(dir, player.direction);
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
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      togglePause();
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      changeDirection(Direction.up);
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      changeDirection(Direction.down);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      changeDirection(Direction.left);
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      changeDirection(Direction.right);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ─── Rendering ────────────────────────────────────────────────────────
  // Land changes only on claims and deaths, so it is a cached picture
  // keyed by layout and an owner version; trails and heads draw per frame.

  ui.Picture? _landPicture;
  (double, double, double, int)? _landKey;
  final _hudText = CachedText();
  final Paint _trailPaint = Paint();
  final Paint _headPaint = Paint();
  final Paint _eyePaint = Paint()..color = Colors.black;

  @override
  void onRemove() {
    _landPicture?.dispose();
    _landPicture = null;
    _hudText.dispose();
    super.onRemove();
  }

  Color _landColor(int id) {
    if (id == playerId) return mode.snakeColor.withValues(alpha: 0.45);
    final rival = rivals.firstWhere((r) => r.id == id, orElse: () => player);
    return rival.color.withValues(alpha: 0.4);
  }

  ui.Picture _recordLand() {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final cs = cellSize;
    final board = Rect.fromLTWH(boardOffset.x, boardOffset.y, gridWidth * cs, gridHeight * cs);
    c.drawRect(board, Paint()..color = mode.backgroundColor);
    final grid = Paint()..color = mode.gridColor;
    final land = Paint();
    for (var y = 0; y < gridHeight; y++) {
      for (var x = 0; x < gridWidth; x++) {
        final rect = Rect.fromLTWH(board.left + x * cs, board.top + y * cs, cs, cs);
        final id = _owner[y * gridWidth + x];
        if (id != 0) {
          land.color = _landColor(id);
          c.drawRect(rect, land);
        } else if ((x + y).isOdd) {
          c.drawRect(rect, grid);
        }
      }
    }
    c.drawRect(
      board,
      Paint()
        ..color = mode.snakeColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    return recorder.endRecording();
  }

  Offset _cellOrigin(Point<int> p) =>
      Offset(boardOffset.x + p.x * cellSize, boardOffset.y + p.y * cellSize);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;
    final key = (cs, boardOffset.x, boardOffset.y, _ownerVersion);
    if (_landPicture == null || _landKey != key) {
      _landKey = key;
      _landPicture?.dispose();
      _landPicture = _recordLand();
    }
    canvas.drawPicture(_landPicture!);

    for (final actor in [player, ...rivals]) {
      if (!actor.alive) continue;
      _trailPaint.color = actor.color.withValues(alpha: 0.75);
      for (final t in actor.trail) {
        final o = _cellOrigin(t);
        canvas.drawRect(Rect.fromLTWH(o.dx + cs * 0.3, o.dy + cs * 0.3, cs * 0.4, cs * 0.4), _trailPaint);
      }
      _headPaint.color = actor.color;
      final o = _cellOrigin(actor.head);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(o.dx + cs * 0.06, o.dy + cs * 0.06, cs * 0.88, cs * 0.88),
          Radius.circular(cs * 0.25),
        ),
        _headPaint,
      );
      final center = o + Offset(cs / 2, cs / 2);
      final (dx, dy) = switch (actor.direction) {
        Direction.up => (0.0, -1.0),
        Direction.down => (0.0, 1.0),
        Direction.left => (-1.0, 0.0),
        Direction.right => (1.0, 0.0),
      };
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(
          center + Offset(dx * cs * 0.18 - dy * side * cs * 0.2, dy * cs * 0.18 + dx * side * cs * 0.2),
          cs * 0.08,
          _eyePaint,
        );
      }
    }

    final percent = (playerShare * 100).toStringAsFixed(1);
    final goal = (mode.winShare * 100).round();
    final hud = _hudText.painter(
      'LAND $percent% / $goal%',
      TextStyle(
        color: Colors.white.withValues(alpha: 0.75),
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
    hud.paint(canvas, Offset(boardOffset.x + 4, boardOffset.y + 2));
  }
}
