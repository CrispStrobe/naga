import 'dart:math';

/// Uniformly selects a free cell, or null if the rectangle is full.
///
/// Snapshot occupancy once so even callers backed by a plain List remain O(n).
Point<int>? randomFreeCell({
  required int width,
  required int height,
  required Iterable<Point<int>> occupied,
  required Random random,
  int left = 0,
  int top = 0,
}) {
  final blocked = occupied.toSet();
  final free = <Point<int>>[];
  for (var y = top; y < top + height; y++) {
    for (var x = left; x < left + width; x++) {
      final cell = Point(x, y);
      if (!blocked.contains(cell)) free.add(cell);
    }
  }
  return free.isEmpty ? null : free[random.nextInt(free.length)];
}
