import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/components/snake_ai.dart';
import 'package:naga/game/snake_game.dart' show Direction;
import '../benchmark/ai_legacy_reference.dart';
import '../benchmark/ai_corrected_reference.dart';

void main() {
  for (final difficulty in [
    AiDifficulty.medium,
    AiDifficulty.hard,
    AiDifficulty.expert,
  ]) {
    test(
      '$difficulty seeded legal-move safety across random wrapping boards',
      () {
        final ai = SnakeAI(difficulty: difficulty, random: Random(91));
        final random = Random(119);
        for (var i = 0; i < 200; i++) {
          const w = 11;
          const h = 13;
          final head = Point(random.nextInt(w), random.nextInt(h));
          final body = [
            head,
            Point((head.x - 1) % w, head.y),
            Point((head.x - 2) % w, head.y),
          ];
          final obstacles = <Point<int>>[];
          for (var j = 0; j < 25; j++) {
            final point = Point(random.nextInt(w), random.nextInt(h));
            if (!body.contains(point)) obstacles.add(point);
          }
          Point<int> next(Direction d) => Point(
            (head.x +
                    (d == Direction.right
                        ? 1
                        : d == Direction.left
                        ? -1
                        : 0)) %
                w,
            (head.y +
                    (d == Direction.down
                        ? 1
                        : d == Direction.up
                        ? -1
                        : 0)) %
                h,
          );
          final safe = [Direction.up, Direction.down, Direction.right]
              .where(
                (d) => !body.contains(next(d)) && !obstacles.contains(next(d)),
              )
              .toList();
          final direction = ai.decideDirection(
            body,
            [obstacles],
            [Point(random.nextInt(w), random.nextInt(h))],
            w,
            h,
            false,
          );
          expect(direction, isNot(Direction.left));
          if (safe.isNotEmpty) {
            expect(safe, contains(direction), reason: 'fixture $i');
          }
        }
      },
    );
  }

  test('invalid board or empty snake is rejected explicitly', () {
    final ai = SnakeAI(difficulty: AiDifficulty.medium);
    expect(
      () => ai.decideDirection([], [], [], 7, 7, true),
      throwsArgumentError,
    );
    expect(
      () => ai.decideDirection([const Point(0, 0)], [], [], 0, 7, true),
      throwsArgumentError,
    );
  });

  test('expert accepts reachable food with a reachable simulated tail', () {
    expect(
      SnakeAI(difficulty: AiDifficulty.expert).decideDirection(
        [const Point(3, 3), const Point(2, 3), const Point(1, 3)],
        [],
        [const Point(3, 2)],
        9,
        9,
        true,
      ),
      Direction.up,
    );
  });

  test('expert tail-following fallback buys room without food', () {
    expect(
      SnakeAI(difficulty: AiDifficulty.expert).decideDirection(
        [
          const Point(3, 3),
          const Point(2, 3),
          const Point(2, 4),
          const Point(3, 4),
        ],
        [],
        [],
        9,
        9,
        true,
      ),
      Direction.right,
    );
  });

  test('expert searches do not mutate caller lists', () {
    const body = [Point(3, 3), Point(2, 3), Point(1, 3)];
    const others = [
      [Point(6, 6), Point(6, 5)],
    ];
    const food = [Point(5, 3)];
    final ai = SnakeAI(difficulty: AiDifficulty.expert);
    final first = ai.decideDirection(body, others, food, 9, 9, true);
    for (var i = 0; i < 10; i++) {
      expect(ai.decideDirection(body, others, food, 9, 9, true), first);
    }
    expect(body.length, 3);
    expect(others.single.length, 2);
    expect(food.single, const Point(5, 3));
  });

  test('medium BFS takes shortest route across wrapping edge', () {
    final ai = SnakeAI(difficulty: AiDifficulty.medium);
    expect(
      ai.decideDirection(
        [const Point(0, 2), const Point(0, 3)],
        [],
        [const Point(6, 2)],
        7,
        7,
        false,
      ),
      Direction.left,
    );
  });

  for (final difficulty in AiDifficulty.values) {
    test('$difficulty never reverses, including intentional easy mistakes', () {
      final ai = SnakeAI(difficulty: difficulty, random: Random(7));
      for (var i = 0; i < 100; i++) {
        expect(
          ai.decideDirection(
            [const Point(3, 3), const Point(2, 3), const Point(1, 3)],
            [],
            [const Point(0, 3)],
            7,
            7,
            true,
          ),
          isNot(Direction.left),
        );
      }
    });

    test('$difficulty infers heading across both wrapping seams', () {
      final ai = SnakeAI(difficulty: difficulty, random: Random(17));
      // No safe move: retain the actual heading instead of inferring up.
      expect(
        ai.decideDirection(
          [const Point(0, 3), const Point(6, 3)],
          [
            [const Point(0, 2), const Point(0, 4), const Point(1, 3)],
          ],
          [],
          7,
          7,
          false,
        ),
        Direction.right,
      );
      expect(
        ai.decideDirection(
          [const Point(3, 0), const Point(3, 6)],
          [
            [const Point(2, 0), const Point(4, 0), const Point(3, 1)],
          ],
          [],
          7,
          7,
          false,
        ),
        Direction.down,
      );
    });
  }

  for (final difficulty in [
    AiDifficulty.medium,
    AiDifficulty.hard,
    AiDifficulty.expert,
  ]) {
    test('$difficulty rejects wrapped body and opponent collisions', () {
      final ai = SnakeAI(difficulty: difficulty);
      final body = [const Point(0, 3), const Point(1, 3), const Point(2, 3)];
      expect(
        ai.decideDirection(
          body,
          [
            [const Point(6, 3), const Point(0, 2)],
          ],
          [const Point(6, 3)],
          7,
          7,
          false,
        ),
        Direction.down,
      );
    });
    test('$difficulty uses the only safe direction at a wall', () {
      expect(
        SnakeAI(difficulty: difficulty).decideDirection(
          [const Point(0, 0), const Point(0, 1)],
          [],
          [],
          7,
          7,
          true,
        ),
        Direction.right,
      );
    });
    test('$difficulty returns current heading when trapped', () {
      expect(
        SnakeAI(difficulty: difficulty).decideDirection(
          [const Point(2, 2), const Point(1, 2)],
          [
            [const Point(2, 1), const Point(2, 3), const Point(3, 2)],
          ],
          [],
          5,
          5,
          true,
        ),
        Direction.right,
      );
    });
  }

  test('expert handles a single segment when simulating a non-eating step', () {
    expect(
      SnakeAI(difficulty: AiDifficulty.expert).decideDirection(
        [const Point(3, 3)],
        [],
        [const Point(3, 0)],
        7,
        7,
        true,
      ),
      Direction.up,
    );
  });

  test('expert rejects food that grows the snake into a sealed pocket', () {
    final body = [const Point(2, 2), const Point(1, 2), const Point(1, 3)];
    final obstacles = [
      [
        const Point(6, 6),
        const Point(1, 1),
        const Point(3, 1),
        const Point(2, 0),
      ],
    ];
    expect(
      SnakeAI(
        difficulty: AiDifficulty.expert,
      ).decideDirection(body, obstacles, [const Point(2, 1)], 7, 7, true),
      isNot(Direction.up),
    );
  });

  test('all levels match corrected reference across reused/resized grids', () {
    for (final difficulty in AiDifficulty.values) {
      final ai = SnakeAI(difficulty: difficulty, random: Random(82));
      final reference = CorrectedSnakeAI(
        difficulty: difficulty,
        random: Random(82),
      );
      final random = Random(1234);
      for (var i = 0; i < 160; i++) {
        final w = 5 + random.nextInt(12);
        final h = 5 + random.nextInt(12);
        final x = 2 + random.nextInt(w - 2);
        final y = random.nextInt(h);
        final body = [Point(x, y), Point(x - 1, y), Point(x - 2, y)];
        final others = <List<Point<int>>>[];
        for (var j = 0; j < 3; j++) {
          final obstacle = <Point<int>>[];
          for (var k = 0; k < 8; k++) {
            final p = Point(random.nextInt(w), random.nextInt(h));
            if (!body.contains(p)) obstacle.add(p);
          }
          others.add(obstacle);
        }
        final food = i % 5 == 0
            ? <Point<int>>[]
            : [Point(random.nextInt(w), random.nextInt(h))];
        expect(
          ai.decideDirection(body, others, food, w, h, i.isEven),
          reference.decideDirection(body, others, food, w, h, i.isEven),
          reason: '$difficulty fixture $i ($w x $h)',
        );
      }
    }
  });

  test('seeded easy, medium and hard retain legacy walled decisions', () {
    final fixtures = Random(321);
    for (final difficulty in [
      AiDifficulty.easy,
      AiDifficulty.medium,
      AiDifficulty.hard,
    ]) {
      final ai = SnakeAI(difficulty: difficulty, random: Random(81));
      final old = LegacySnakeAI(difficulty: difficulty, random: Random(81));
      for (var i = 0; i < 100; i++) {
        final x = 2 + fixtures.nextInt(9);
        final y = 1 + fixtures.nextInt(9);
        final body = [Point(x, y), Point(x - 1, y), Point(x - 2, y)];
        final obstacles = <Point<int>>[];
        for (var n = 0; n < 15; n++) {
          final p = Point(fixtures.nextInt(12), fixtures.nextInt(12));
          if (!body.contains(p)) obstacles.add(p);
        }
        final foods = [Point(fixtures.nextInt(12), fixtures.nextInt(12))];
        final others = [obstacles];
        expect(
          ai.decideDirection(body, others, foods, 12, 12, true),
          old.decideDirection(body, others, foods, 12, 12, true),
          reason: '$difficulty fixture $i',
        );
      }
    }
  });
}
