import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/ascii_game.dart';
import 'package:naga/game/cga_game.dart';
import 'package:naga/game/nibbles_game.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/ascii_mode.dart';
import 'package:naga/modes/cga_mode.dart';
import 'package:naga/modes/nibbles_mode.dart';
import 'package:naga/modes/classic_mode.dart';
import 'package:naga/game/shared/direction_buffer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final factories = <String, dynamic Function()>{
    'ASCII': () => AsciiGame(
      mode: AsciiMode(),
      onGameOver: () {},
      onScoreChanged: (_) {},
      startSpeed: 0.1,
    ),
    'CGA': () => CgaGame(
      mode: CgaMode(),
      onGameOver: () {},
      onScoreChanged: (_) {},
      startSpeed: 0.1,
    ),
    'Nibbles': () => NibblesGame(
      mode: NibblesMode(),
      onGameOver: () {},
      onScoreChanged: (_) {},
      startSpeed: 0.1,
    ),
  };
  for (final entry in factories.entries) {
    test(
      '${entry.key} consumes one fast turn per tick and resets queue',
      () async {
        final dynamic game = entry.value();
        game.onGameResize(Vector2(400, 560));
        await game.onLoad();
        game.snakeSegments = [const Point(8, 8)];
        game.foodPosition = const Point(1, 1);
        game.changeDirection(Direction.left); // Reversal rejected.
        game.changeDirection(Direction.right); // Duplicate rejected.
        for (final dir in [
          Direction.up,
          Direction.left,
          Direction.down,
          Direction.right,
          Direction.up,
        ]) {
          game.changeDirection(dir); // Fifth valid input must be dropped.
        }
        game.update(0.01);
        expect(game.snakeSegments.first, const Point(8, 8));
        for (final head in [
          const Point(8, 7),
          const Point(7, 7),
          const Point(7, 8),
          const Point(8, 8),
          const Point(9, 8),
        ]) {
          game.update(0.1);
          expect(game.snakeSegments.first, head);
        }
        game.changeDirection(Direction.up);
        game.respawn();
        game.snakeSegments = [const Point(8, 8)];
        game.foodPosition = const Point(1, 1);
        game.update(0.1);
        expect(game.snakeSegments.first, const Point(9, 8));
        game.changeDirection(Direction.up);
        game.restart();
        game.snakeSegments = [const Point(8, 8)];
        game.foodPosition = const Point(1, 1);
        game.update(0.1);
        expect(game.snakeSegments.first, const Point(9, 8));
      },
    );
  }
  test(
    'Classic preserves early tick threshold, pause and edge wrapping',
    () async {
      final game = SnakeGame(
        mode: ClassicMode(),
        onGameOver: () {},
        onScoreChanged: (_) {},
        speedOverride: 1,
        wallsKillOverride: false,
      );
      game.onGameResize(Vector2(400, 560));
      await game.onLoad();
      game.snake.segments = [const Point(0, 0)];
      game.food.gridPosition = const Point(5, 5);
      game.update(0.31);
      game.changeDirection(Direction.up);
      game.togglePause();
      game.update(1);
      expect(game.snake.segments.first, const Point(0, 0));
      game.togglePause();
      game.update(0);
      expect(game.snake.segments.first, Point(0, game.gridHeight - 1));
      game.changeDirection(Direction.left);
      game.update(10); // Large dt still consumes exactly one turn/tick.
      expect(
        game.snake.segments.first,
        Point(game.gridWidth - 1, game.gridHeight - 1),
      );
    },
  );

  test(
    'CGA full but legal input still accelerates; reversal does not',
    () async {
      final game = CgaGame(
        mode: CgaMode(),
        onGameOver: () {},
        onScoreChanged: (_) {},
        startSpeed: 1,
      );
      game.onGameResize(Vector2(400, 560));
      await game.onLoad();
      game.snakeSegments = [const Point(8, 8)];
      game.foodPosition = const Point(1, 1);
      for (final dir in [
        Direction.up,
        Direction.left,
        Direction.down,
        Direction.right,
      ]) {
        game.changeDirection(dir);
      }
      game.update(0.1); // Past mode early-tick threshold, below startSpeed.
      game.changeDirection(Direction.left);
      game.update(0);
      expect(game.snakeSegments.first, const Point(8, 8));
      game.changeDirection(Direction.up); // Full, but not a forbidden turn.
      // Acceleration uses mode interval rather than startSpeed (legacy rule).
      // Accumulate the remainder needed for the configured movement interval.
      game.update(1 - game.mode.tickInterval(game.score));
      expect(game.snakeSegments.first, const Point(8, 7));
    },
  );

  test('reset discards pending inputs and supports smaller capacities', () {
    final buffer = DirectionBuffer(capacity: 2);
    buffer.enqueue(Direction.up, Direction.right);
    buffer.enqueue(Direction.left, Direction.right);
    expect(
      buffer.enqueue(Direction.down, Direction.right),
      DirectionInput.full,
    );
    buffer.clear();
    expect(buffer.consume(Direction.down), Direction.down);
    expect(
      buffer.enqueue(Direction.up, Direction.down),
      DirectionInput.rejected,
    );
    for (var i = 0; i < 50; i++) {
      buffer.enqueue(Direction.right, Direction.down);
      buffer.enqueue(Direction.up, Direction.down);
      expect(buffer.consume(Direction.down), Direction.right);
      expect(buffer.consume(Direction.right), Direction.up);
    }
    expect(() => DirectionBuffer(capacity: 0), throwsArgumentError);
  });

  test('bounded FIFO validates fast turns against last accepted input', () {
    final buffer = DirectionBuffer(capacity: 4);
    var current = Direction.right;
    expect(buffer.enqueue(Direction.right, current), DirectionInput.rejected);
    expect(buffer.enqueue(Direction.left, current), DirectionInput.rejected);
    for (final dir in [
      Direction.up,
      Direction.left,
      Direction.down,
      Direction.right,
    ]) {
      expect(buffer.enqueue(dir, current), DirectionInput.queued);
    }
    expect(buffer.length, 4);
    expect(buffer.enqueue(Direction.up, current), DirectionInput.full);
    expect(buffer.enqueue(Direction.left, current), DirectionInput.rejected);
    for (final dir in [
      Direction.up,
      Direction.left,
      Direction.down,
      Direction.right,
    ]) {
      current = buffer.consume(current);
      expect(current, dir);
    }
    expect(buffer.consume(current), Direction.right);
    expect(buffer.length, 0);
  });
}
