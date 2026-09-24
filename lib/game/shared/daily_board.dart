import 'dart:collection';
import 'dart:math';

import 'seeded_random.dart';

/// Deterministic rock layout for a daily seed.
///
/// Rocks are short straight runs. The start lane (the row the snake spawns
/// on, from its tail to several cells ahead) is always clear, and a layout
/// is only accepted when every free cell is still reachable, so no food can
/// spawn in a sealed pocket.
Set<Point<int>> dailyRocks({
  required int seed,
  required int width,
  required int height,
}) {
  final random = SeededRandom(seed);
  final startY = height ~/ 2;
  final startX = width ~/ 2;
  bool inStartLane(Point<int> p) =>
      (p.y - startY).abs() <= 1 && p.x >= startX - 3 && p.x <= startX + 6;

  for (var attempt = 0; attempt < 50; attempt++) {
    final rocks = <Point<int>>{};
    final runs = 7 + random.nextInt(4);
    for (var r = 0; r < runs; r++) {
      final horizontal = random.nextBool();
      final length = 2 + random.nextInt(3);
      final x0 = 1 + random.nextInt(width - 2);
      final y0 = 1 + random.nextInt(height - 2);
      for (var i = 0; i < length; i++) {
        final p = horizontal ? Point(x0 + i, y0) : Point(x0, y0 + i);
        // Keep a one-cell margin so the border never gets sealed off.
        if (p.x < 1 || p.x >= width - 1 || p.y < 1 || p.y >= height - 1) break;
        if (inStartLane(p)) break;
        rocks.add(p);
      }
    }
    if (_allFreeCellsConnected(rocks, width, height)) return rocks;
  }
  return {};
}

bool _allFreeCellsConnected(Set<Point<int>> rocks, int width, int height) {
  final start = Point(width ~/ 2, height ~/ 2);
  final seen = <Point<int>>{start};
  final queue = Queue<Point<int>>()..add(start);
  while (queue.isNotEmpty) {
    final p = queue.removeFirst();
    for (final n in [
      Point(p.x + 1, p.y),
      Point(p.x - 1, p.y),
      Point(p.x, p.y + 1),
      Point(p.x, p.y - 1),
    ]) {
      if (n.x < 0 || n.y < 0 || n.x >= width || n.y >= height) continue;
      if (rocks.contains(n) || !seen.add(n)) continue;
      queue.add(n);
    }
  }
  return seen.length == width * height - rocks.length;
}
