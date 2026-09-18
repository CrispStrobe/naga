import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/components/snake.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/classic_mode.dart';

import 'package:naga/components/trail_snake.dart';
import 'package:naga/game/trail_game.dart' as trail;
import 'package:naga/modes/trail_mode.dart';
import 'package:naga/game/shared/grid_snake_body.dart';
import 'package:flutter/material.dart';

void main() {
  test('Trail uses a ring without removing permanent trail cells', () {
    final game = trail.TrailGame(mode: TrailMode(), onGameOver: () {}, onScoreChanged: (_) {});
    final snake = TrailSnake(game: game, initialSegments: [const Point(2, 0), const Point(1, 0), const Point(0, 0)], color: Colors.red, direction: trail.Direction.right);
    expect(snake.segments, isA<GridSnakeBody>());
    snake.advance(const Point(3, 0));
    expect(snake.segments.length, 3);
    expect(snake.segments.contains(const Point(0, 0)), isFalse);
    expect(snake.occupiesTrail(const Point(0, 0)), isTrue);
    snake.changeDirection(trail.Direction.left);
    expect(snake.peekNextHead(), const Point(4, 0));
    snake.changeDirection(trail.Direction.down);
    expect(snake.peekNextHead(), const Point(3, 1));
  });
  test('Snake edits, external replacement and shrink cannot stale occupancy', () {
    final game = SnakeGame(mode: ClassicMode(), onGameOver: () {}, onScoreChanged: (_) {});
    final snake = Snake(game, initialSegments: [const Point(2, 0), const Point(1, 0), const Point(1, 0)]);
    snake.removeTailSegments(1);
    expect(snake.occupies(const Point(1, 0)), isTrue);
    snake.segments[0] = const Point(9, 9);
    expect(snake.occupies(const Point(2, 0)), isFalse);
    final assigned = [const Point(8, 8)];
    snake.segments = assigned;
    assigned.add(const Point(7, 7));
    expect(snake.occupies(const Point(7, 7)), isTrue);
    expect(snake.occupies(const Point(9, 9)), isFalse);
    snake.removeTailSegments(99);
    expect(assigned, [const Point(8, 8)]);
    snake.segments.clear();
    snake.removeTailSegments(1);
    expect(snake.occupiedCells, isEmpty);
  });

  test('Snake retains occupancy when new head replaces departing tail', () {
    final game = SnakeGame(
      mode: ClassicMode(), onGameOver: () {}, onScoreChanged: (_) {},
    );
    final snake = Snake(game, initialSegments: [
      const Point(1, 0), const Point(0, 0),
    ]);
    snake.move(const Point(0, 0));
    expect(snake.segments, [const Point(0, 0), const Point(1, 0)]);
    expect(snake.occupies(const Point(0, 0)), isTrue);
    expect(snake.occupiedCells, contains(Snake.encodePos(const Point(0, 0))));
  });
}
