import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../modes/ouroboros_mode.dart';
import 'shared/free_cell.dart';
import 'snake_game.dart';

/// Classic rules plus wandering fireflies ("motes") that can only be
/// caught by enclosing them in a loop of your own body.
///
/// After every move a flood fill from the board edge marks every cell the
/// body does not seal off; any mote left outside that fill is enclosed and
/// caught. The walls never help: only the body can close a loop.
class OuroborosGame extends SnakeGame {
  final Random _moteRandom;

  OuroborosGame({
    required OuroborosMode super.mode,
    required super.onGameOver,
    required super.onScoreChanged,
    super.onVictory,
    super.gridWidth,
    super.gridHeight,
    super.wallsKillOverride,
    super.speedOverride,
    super.random,
  }) : _moteRandom = random ?? Random();

  static const int moteCount = 4;

  /// Motes wander one step every this many moves.
  static const int wanderEvery = 3;

  /// Extra body segments per caught mote.
  static const int growthPerMote = 2;

  final List<Point<int>> motes = [];
  int moteCatches = 0;
  int _pendingGrowth = 0;
  int _moves = 0;

  // Cells of the most recent catch, flashed briefly.
  Set<Point<int>> _flashCells = const {};
  double _flashTimer = 0;
  double _time = 0;

  OuroborosMode get _ouroborosMode => mode as OuroborosMode;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _refillMotes();
  }

  @override
  void restart() {
    super.restart();
    _reset();
  }

  @override
  void respawn() {
    super.respawn();
    _reset();
  }

  void _reset() {
    motes.clear();
    _pendingGrowth = 0;
    _moves = 0;
    moteCatches = 0;
    _flashCells = const {};
    _refillMotes();
  }

  @override
  @protected
  bool takeExtraGrowth() {
    if (_pendingGrowth == 0) return false;
    _pendingGrowth--;
    return true;
  }

  @override
  @protected
  Point<int>? nextFoodCell() => randomFreeCell(
    width: gridWidth,
    height: gridHeight,
    occupied: [...snake.segments, ...rocks, ...motes],
    random: _moteRandom,
  );

  @override
  @protected
  void afterMove() {
    _moves++;
    _scareFromHead();
    if (!catchEnclosed() && _moves % wanderEvery == 0) _wander();
    _refillMotes();
  }

  /// Cells sealed off from the board edge by the body (body cells excluded).
  @visibleForTesting
  Set<Point<int>> enclosedCells() {
    final body = snake.segments.toSet();
    final outside = <Point<int>>{};
    final queue = Queue<Point<int>>();
    void visit(Point<int> p) {
      if (body.contains(p) || !outside.add(p)) return;
      queue.add(p);
    }

    for (var x = 0; x < gridWidth; x++) {
      visit(Point(x, 0));
      visit(Point(x, gridHeight - 1));
    }
    for (var y = 0; y < gridHeight; y++) {
      visit(Point(0, y));
      visit(Point(gridWidth - 1, y));
    }
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      if (p.x > 0) visit(Point(p.x - 1, p.y));
      if (p.x < gridWidth - 1) visit(Point(p.x + 1, p.y));
      if (p.y > 0) visit(Point(p.x, p.y - 1));
      if (p.y < gridHeight - 1) visit(Point(p.x, p.y + 1));
    }
    return {
      for (var y = 0; y < gridHeight; y++)
        for (var x = 0; x < gridWidth; x++)
          if (!outside.contains(Point(x, y)) && !body.contains(Point(x, y)))
            Point(x, y),
    };
  }

  /// Catches every enclosed mote. Returns whether anything was caught.
  @visibleForTesting
  bool catchEnclosed() {
    final enclosed = enclosedCells();
    if (enclosed.isEmpty) return false;
    final caught = motes.where(enclosed.contains).toList();
    if (caught.isEmpty) return false;
    motes.removeWhere(caught.contains);
    final n = caught.length;
    // One mote is 10, two in one loop 40, three 90: loops reward patience.
    score += 10 * n * n;
    moteCatches += n;
    _pendingGrowth += growthPerMote * n;
    onScoreChanged(score);
    _flashCells = enclosed;
    _flashTimer = 0.5;
    return true;
  }

  /// A mote the head touches hops away instead of being eaten.
  void _scareFromHead() {
    final head = snake.segments.first;
    final i = motes.indexOf(head);
    if (i < 0) return;
    final hop = _freeNeighbours(head, avoidHead: true);
    motes[i] = hop.isNotEmpty ? hop[_moteRandom.nextInt(hop.length)] : _spawnCell() ?? head;
  }

  void _wander() {
    for (var i = 0; i < motes.length; i++) {
      if (_moteRandom.nextDouble() < 0.4) continue;
      final options = _freeNeighbours(motes[i], avoidHead: true);
      if (options.isNotEmpty) motes[i] = options[_moteRandom.nextInt(options.length)];
    }
  }

  List<Point<int>> _freeNeighbours(Point<int> p, {required bool avoidHead}) {
    final head = snake.segments.first;
    return [
      for (final n in [Point(p.x + 1, p.y), Point(p.x - 1, p.y), Point(p.x, p.y + 1), Point(p.x, p.y - 1)])
        if (_inner(n) &&
            !snake.occupies(n) &&
            n != food.gridPosition &&
            !motes.contains(n) &&
            !(avoidHead && n == head))
          n,
    ];
  }

  /// Fireflies keep off the outermost ring: a loop has to pass on every
  /// side of a firefly and the walls never count, so one on the edge could
  /// never be caught.
  bool _inner(Point<int> p) =>
      p.x >= 1 && p.y >= 1 && p.x < gridWidth - 1 && p.y < gridHeight - 1;

  Point<int>? _spawnCell() {
    final head = snake.segments.first;
    for (var attempt = 0; attempt < 100; attempt++) {
      final p = Point(1 + _moteRandom.nextInt(gridWidth - 2), 1 + _moteRandom.nextInt(gridHeight - 2));
      if ((p.x - head.x).abs() + (p.y - head.y).abs() < 4) continue;
      if (snake.occupies(p) || p == food.gridPosition || motes.contains(p)) continue;
      return p;
    }
    return null;
  }

  void _refillMotes() {
    while (motes.length < moteCount) {
      final p = _spawnCell();
      if (p == null) return;
      motes.add(p);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_flashTimer > 0) _flashTimer = max(0, _flashTimer - dt);
  }

  final Paint _flashPaint = Paint();
  final Paint _haloPaint = Paint();
  final Paint _corePaint = Paint();

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;
    if (_flashTimer > 0) {
      _flashPaint.color = _ouroborosMode.snakeColor.withValues(alpha: _flashTimer * 0.6);
      for (final c in _flashCells) {
        final p = gridToScreen(c);
        canvas.drawRect(Rect.fromLTWH(p.x, p.y, cs, cs), _flashPaint);
      }
    }
    final moteColor = _ouroborosMode.moteColor;
    for (var i = 0; i < motes.length; i++) {
      final p = gridToScreen(motes[i]);
      final c = Offset(p.x + cs / 2, p.y + cs / 2);
      final pulse = 0.5 + 0.5 * sin(_time * 5 + i * 1.7);
      // A soft halo without a blur filter: two translucent discs.
      _haloPaint.color = moteColor.withValues(alpha: 0.12 + 0.12 * pulse);
      canvas.drawCircle(c, cs * (0.42 + 0.08 * pulse), _haloPaint);
      _corePaint.color = moteColor;
      canvas.drawCircle(c, cs * 0.16, _corePaint);
    }
  }
}
