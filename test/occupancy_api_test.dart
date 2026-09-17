import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:naga/components/snake.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/classic_mode.dart';

void main() {
  test(
    'occupancy Set lookup follows numeric equality without losing counts',
    () {
      final game = SnakeGame(
        mode: ClassicMode(),
        onGameOver: () {},
        onScoreChanged: (_) {},
      );
      final snake = Snake(
        game,
        initialSegments: [const Point(1, 0), const Point(1, 0)],
      );
      final occupied = snake.occupiedCells;
      expect(occupied.lookup(1.0), 1);
      expect(occupied.lookup(99), isNull);
      expect(() => occupied.add(99), throwsUnsupportedError);
      expect(() => occupied.remove(1), throwsUnsupportedError);
      expect(() => occupied.clear(), throwsUnsupportedError);
      snake.removeTailSegments(1);
      expect(occupied, {1});
      expect(snake.occupies(const Point(1, 0)), isTrue);
      snake.move(const Point(1, 0));
      expect(occupied, {1});
      snake.segments.add(const Point(10001, -1)); // Same legacy encoding.
      expect(occupied.length, 1);
      expect(snake.occupies(const Point(10001, -1)), isTrue);
      snake.segments.removeLast();
      expect(snake.occupies(const Point(10001, -1)), isFalse);
      expect(occupied, {1});
    },
  );
  test(
    'retained occupancy reference follows movement and replacement aliases',
    () {
      final game = SnakeGame(
        mode: ClassicMode(),
        onGameOver: () {},
        onScoreChanged: (_) {},
      );
      final snake = Snake(
        game,
        initialSegments: [
          const Point(2, 0),
          const Point(1, 0),
          const Point(0, 0),
        ],
      );
      final occupied = snake.occupiedCells;
      expect(identical(occupied, snake.occupiedCells), isTrue);
      snake.move(const Point(3, 0));
      expect(occupied, {1, 2, 3});
      final assigned = [const Point(8, 0)];
      snake.segments = assigned;
      assigned.add(const Point(9, 0));
      expect(occupied, {8, 9});
      assigned[0] = const Point(7, 0);
      expect(occupied, {7, 9});
      snake.removeTailSegments(99);
      expect(occupied, {7});
      assigned.clear();
      expect(occupied, isEmpty);
    },
  );
}
