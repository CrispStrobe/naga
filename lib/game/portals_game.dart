import 'dart:math';

import 'package:flutter/material.dart';

import '../modes/portals_mode.dart';
import 'shared/free_cell.dart';
import 'snake_game.dart';

/// Classic rules plus one linked pair of portals.
///
/// Stepping onto a portal puts the head on its partner, still heading the
/// same way; the body follows through cell by cell. The pair moves to new
/// free cells after every meal, so the shortcut keeps changing.
class PortalsGame extends SnakeGame {
  final Random _portalRandom;

  PortalsGame({
    required PortalsMode super.mode,
    required super.onGameOver,
    required super.onScoreChanged,
    super.onVictory,
    super.gridWidth,
    super.gridHeight,
    super.wallsKillOverride,
    super.speedOverride,
    super.random,
  }) : _portalRandom = random ?? Random();

  PortalsMode get _portalsMode => mode as PortalsMode;

  /// The linked pair; null only before the first layout.
  (Point<int>, Point<int>)? portals;

  double _time = 0;
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _corePaint = Paint();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    relocatePortals();
  }

  @override
  void restart() {
    super.restart();
    relocatePortals();
  }

  @override
  void respawn() {
    super.respawn();
    relocatePortals();
  }

  /// Places the pair on free cells, away from the walls, the head and each
  /// other. Falls back to any two free cells on a crowded board.
  @visibleForTesting
  void relocatePortals() {
    final blocked = <Point<int>>{
      ...snake.segments,
      food.gridPosition,
      ...rocks,
    };
    final head = snake.segments.first;
    final minApart = (gridWidth + gridHeight) ~/ 3;
    for (var attempt = 0; attempt < 200; attempt++) {
      final a = _randomInner();
      final b = _randomInner();
      if (blocked.contains(a) || blocked.contains(b)) continue;
      if (_manhattan(a, b) < minApart) continue;
      if (_manhattan(a, head) < 3 || _manhattan(b, head) < 3) continue;
      portals = (a, b);
      return;
    }
    final a = randomFreeCell(width: gridWidth, height: gridHeight, occupied: blocked, random: _portalRandom);
    final b = a == null
        ? null
        : randomFreeCell(width: gridWidth, height: gridHeight, occupied: {...blocked, a}, random: _portalRandom);
    portals = (a != null && b != null) ? (a, b) : null;
  }

  Point<int> _randomInner() => Point(
    1 + _portalRandom.nextInt(max(1, gridWidth - 2)),
    1 + _portalRandom.nextInt(max(1, gridHeight - 2)),
  );

  static int _manhattan(Point<int> a, Point<int> b) =>
      (a.x - b.x).abs() + (a.y - b.y).abs();

  @override
  @protected
  Point<int> routeHead(Point<int> next) {
    final pair = portals;
    if (pair == null) return next;
    if (next == pair.$1) return pair.$2;
    if (next == pair.$2) return pair.$1;
    return next;
  }

  @override
  @protected
  void onFoodEaten() {
    // Move after this meal; the new food then avoids the new portals.
    relocatePortals();
  }

  @override
  @protected
  Point<int>? nextFoodCell() {
    final pair = portals;
    return randomFreeCell(
      width: gridWidth,
      height: gridHeight,
      occupied: [
        ...snake.segments,
        ...rocks,
        if (pair != null) ...[pair.$1, pair.$2],
      ],
      random: _portalRandom,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final pair = portals;
    if (pair == null) return;
    _renderPortal(canvas, pair.$1, _portalsMode.portalA, 1);
    _renderPortal(canvas, pair.$2, _portalsMode.portalB, -1);
  }

  /// A hollow swirl, so a head sitting in the portal stays visible.
  void _renderPortal(Canvas canvas, Point<int> cell, Color color, double spin) {
    final cs = cellSize;
    final p = gridToScreen(cell);
    final c = Offset(p.x + cs / 2, p.y + cs / 2);
    _corePaint.color = color.withValues(alpha: 0.18);
    canvas.drawCircle(c, cs * 0.45, _corePaint);
    _ringPaint
      ..color = color
      ..strokeWidth = max(1.5, cs * 0.09);
    final start = _time * 3 * spin;
    for (var i = 0; i < 3; i++) {
      final r = cs * (0.42 - i * 0.11);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start + i * 1.3,
        pi * 1.1,
        false,
        _ringPaint,
      );
    }
  }
}
