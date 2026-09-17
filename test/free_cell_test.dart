import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/shared/free_cell.dart';

class IndexRandom implements Random {
  final int index;
  int calls = 0;
  int? bound;
  IndexRandom(this.index);
  @override
  int nextInt(int max) {
    calls++;
    bound = max;
    return index;
  }

  @override
  bool nextBool() => throw UnimplementedError();
  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  test('full and empty rectangles do not draw random numbers', () {
    for (final size in [(2, 2), (0, 2), (2, 0)]) {
      final random = IndexRandom(0);
      expect(
        randomFreeCell(
          width: size.$1,
          height: size.$2,
          occupied: [
            const Point(0, 0),
            const Point(1, 0),
            const Point(0, 1),
            const Point(1, 1),
          ],
          random: random,
        ),
        null,
      );
      expect(random.calls, 0);
    }
  });

  test('one free cell survives duplicates and out-of-bounds occupancy', () {
    final random = IndexRandom(0);
    expect(
      randomFreeCell(
        width: 2,
        height: 2,
        left: 4,
        top: 5,
        occupied: [
          const Point(4, 5),
          const Point(4, 5),
          const Point(5, 5),
          const Point(4, 6),
          const Point(100, 100),
        ],
        random: random,
      ),
      const Point(5, 6),
    );
    expect(random.calls, 1);
    expect(random.bound, 1);
  });

  test('each free cell has exactly one equally likely random index', () {
    final selected = <Point<int>>{};
    for (var i = 0; i < 4; i++) {
      final random = IndexRandom(i);
      selected.add(
        randomFreeCell(
          width: 3,
          height: 2,
          occupied: [const Point(1, 0), const Point(2, 1)],
          random: random,
        )!,
      );
      expect(random.calls, 1);
      expect(random.bound, 4);
    }
    expect(selected, {
      const Point(0, 0),
      const Point(2, 0),
      const Point(0, 1),
      const Point(1, 1),
    });
  });

  test('does not mutate or repeatedly traverse caller occupancy', () {
    var traversals = 0;
    Iterable<Point<int>> occupied() sync* {
      traversals++;
      yield const Point(0, 0);
    }

    expect(
      randomFreeCell(
        width: 2,
        height: 1,
        occupied: occupied(),
        random: IndexRandom(0),
      ),
      const Point(1, 0),
    );
    expect(traversals, 1);
  });
}
