import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/components/power_up.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/game/snake2_game.dart';
import 'package:naga/game/multiplayer_game.dart';
import 'package:naga/modes/classic_mode.dart';
import 'package:naga/modes/arcade_mode.dart';
import 'package:naga/modes/zen_mode.dart';
import 'package:naga/modes/ascii_mode.dart';
import 'package:naga/modes/cga_mode.dart';
import 'package:naga/modes/nibbles_mode.dart';
import 'package:naga/modes/snake2_mode.dart';
import 'package:naga/modes/multiplayer_mode.dart';
import 'package:naga/services/settings_service.dart';

List<Point<int>> cells(int width, int height, {int left = 0, int top = 0}) => [
  for (var y = top; y < top + height; y++)
    for (var x = left; x < left + width; x++) Point(x, y),
];

// Deliberately set-like bodies isolate spawning from pathfinding/collision rules.
List<Point<int>> almostFull(
  List<Point<int>> arena,
  Point<int> head,
  Set<Point<int>> free,
) => [head, ...arena.where((p) => p != head && !free.contains(p))];

void renderSafely(FlameGame game) {
  final recorder = ui.PictureRecorder();
  game.render(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

Future<void> load(FlameGame game) async {
  game.onGameResize(Vector2(400, 560));
  await game.onLoad();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in [ClassicMode(), ArcadeMode(), ZenMode()]) {
    for (final nearly in [false, true]) {
      test(
        '${mode.name} ${nearly ? "nearly full" : "full"} board completion',
        () async {
          var wins = 0;
          var deaths = 0;
          final scores = <int>[];
          final session = GameRegistry.create(
            mode: mode,
            settings: const GameSettings(),
            onGameOver: () => deaths++,
            onVictory: () => wins++,
            onScoreChanged: scores.add,
          );
          final game = session.game as SnakeGame;
          await load(game);
          game.snake.segments = almostFull(
            cells(game.gridWidth, game.gridHeight),
            const Point(0, 0),
            {const Point(1, 0), if (nearly) const Point(2, 0)},
          );
          game.food.gridPosition = const Point(1, 0);
          game.update(1);
          if (nearly) {
            expect(wins, 0);
            expect(game.gameState, GameState.playing);
            expect(game.food.gridPosition, const Point(2, 0));
            game.update(1);
          }
          expect(session.result, SessionResult.victory);
          expect(game.gameState, GameState.gameOver);
          expect(wins, 1);
          expect(deaths, 0);
          expect(scores, hasLength(nearly ? 2 : 1));
          expect(scores.last, game.score);
          final body = game.snake.segments.toList();
          session.setPaused(false);
          game.togglePause();
          game.update(10);
          expect(game.snake.segments, body);
          expect(wins, 1);
          expect(deaths, 0);
          renderSafely(game);
          final score = game.score;
          game.respawn();
          expect(game.hasWon, false);
          expect(game.gameState, GameState.playing);
          expect(game.score, score);
          expect(game.snake.occupies(game.food.gridPosition), false);
          game.restart();
          expect(game.hasWon, false);
          expect(game.score, 0);
          expect(scores.last, 0);
        },
      );
    }
  }

  for (final mode in [AsciiMode(), CgaMode(), NibblesMode()]) {
    test('${mode.name} last playable cells route victory and reset', () async {
      var wins = 0;
      var deaths = 0;
      final scores = <int>[];
      final session = GameRegistry.create(
        mode: mode,
        settings: const GameSettings(),
        onGameOver: () => deaths++,
        onVictory: () => wins++,
        onScoreChanged: scores.add,
      );
      final dynamic game = session.game;
      await load(session.game);
      final inset = mode is NibblesMode;
      final head = inset ? const Point(1, 2) : const Point(0, 0);
      final food = Point(head.x + 1, head.y);
      final last = Point(head.x + 2, head.y);
      final arena = cells(
        game.gridWidth - (inset ? 2 : 0),
        game.gridHeight - (inset ? 3 : 0),
        left: inset ? 1 : 0,
        top: inset ? 2 : 0,
      );
      game.snakeSegments = almostFull(arena, head, {food, last});
      game.foodPosition = food;
      game.update(1.0);
      expect(game.foodPosition, last);
      expect(wins, 0);
      game.update(1.0);
      expect(session.result, SessionResult.victory);
      expect(wins, 1);
      expect(deaths, 0);
      expect(scores, hasLength(2));
      if (inset) expect(scores, [20, 50]); // Existing first digit is 2.
      renderSafely(session.game);
      session.setPaused(false);
      game.update(10.0);
      expect(wins, 1);
      expect(deaths, 0);
      final score = game.score;
      session.respawn!();
      expect(game.hasWon, false);
      expect(game.score, score);
      expect(game.snakeSegments.contains(game.foodPosition), false);
      game.restart();
      expect(game.hasWon, false);
      expect(game.score, 0);
    });
  }

  test(
    'Nibbles keeps numbered cycles rather than winning at level boundary',
    () async {
      final dynamic game = GameRegistry.create(
        mode: NibblesMode(),
        settings: const GameSettings(),
        onGameOver: () => fail('unexpected death'),
        onVictory: () => fail('ordinary level is not a win'),
        onScoreChanged: (_) {},
      ).game;
      await load(game);
      var total = 0;
      for (var i = 0; i < 10; i++) {
        game.snakeSegments = [
          const Point(1, 2),
          const Point(1, 3),
          const Point(1, 4),
        ];
        game.foodPosition = const Point(2, 2);
        game.update(1.0);
        total += ((i + 1) % 9 + 1) * 10;
        expect(game.score, total);
        expect(game.gameState, GameState.playing);
      }
    },
  );

  for (final bonus in [false, true]) {
    test(
      'Snake II full usable arena completes from ${bonus ? "bonus" : "food"}',
      () async {
        var wins = 0;
        var deaths = 0;
        final session = GameRegistry.create(
          mode: Snake2Mode(),
          settings: const GameSettings(),
          onGameOver: () => deaths++,
          onVictory: () => wins++,
          onScoreChanged: (_) {},
        );
        final game = session.game as Snake2Game;
        await load(game);
        game.mazeWalls = [const Point(3, 0), const Point(3, 0)];
        game.snakeSegments = almostFull(
          cells(game.gridWidth, game.gridHeight),
          const Point(0, 0),
          {const Point(1, 0), const Point(3, 0)},
        );
        game.foodPositions = [const Point(1, 0)];
        if (bonus) {
          // Spawn a real bonus to initialize its lifetime on the sole free cell.
          game.foodPositions.clear();
          game.update(12);
        } else {
          game.update(1);
        }
        expect(session.result, SessionResult.victory);
        expect(game.score, bonus ? 50 : 10);
        expect(wins, 1);
        expect(deaths, 0);
        expect(game.foodPositions, isEmpty);
        game.update(20);
        expect(wins, 1);
        renderSafely(game);
        game.respawn();
        expect(game.hasWon, false);
        expect(game.foodPositions, hasLength(game.mode.foodCount));
        game.restart();
        expect(game.score, 0);
        expect(game.hasWon, false);
      },
    );
  }

  test(
    'Snake II last free cell always gets food; reservations are not victory',
    () async {
      final game = Snake2Game(
        mode: Snake2Mode(),
        onGameOver: () => fail('death'),
        onVictory: () => fail('reserved cells are not snake'),
        onScoreChanged: (_) {},
      );
      await load(game);
      game.snakeSegments = almostFull(
        cells(game.gridWidth, game.gridHeight),
        const Point(0, 0),
        {const Point(1, 0), const Point(2, 0), const Point(3, 0)},
      );
      game.mazeWalls = [const Point(3, 0)];
      game.foodPositions = [const Point(1, 0)];
      game.update(1);
      expect(game.foodPositions, [const Point(2, 0)]);
      expect(game.hasWon, false);
    },
  );

  test(
    'Snake II normal score threshold changes maze without ending game',
    () async {
      final game = Snake2Game(
        mode: Snake2Mode(),
        onGameOver: () => fail('death'),
        onVictory: () => fail('ordinary level'),
        onScoreChanged: (_) {},
      );
      await load(game);
      game.score = 90;
      game.snakeSegments = [
        const Point(0, 0),
        const Point(0, 1),
        const Point(0, 2),
      ];
      game.foodPositions = [const Point(1, 0)];
      game.update(1);
      expect(game.score, 100);
      expect(game.mazeWalls, isNotEmpty);
      expect(game.gameState, GameState.playing);
    },
  );

  test(
    'Snake II maze transition keeps all food outside new obstacles',
    () async {
      final game = Snake2Game(
        mode: Snake2Mode(),
        onGameOver: () => fail('death'),
        onScoreChanged: (_) {},
      );
      await load(game);
      game.score = 90;
      game.snakeSegments = [
        const Point(0, 0),
        const Point(0, 1),
        const Point(0, 2),
      ];
      game.foodPositions = [
        const Point(1, 0),
        const Point(6, 14),
        const Point(7, 14),
      ];
      game.update(1);
      expect(game.mazeWalls, contains(const Point(6, 14)));
      expect(game.foodPositions.where(game.mazeWalls.contains), isEmpty);
      expect(game.foodPositions, hasLength(3));
    },
  );

  test(
    'Direct legacy SnakeGame callback still reports completion once',
    () async {
      var ends = 0;
      final game = SnakeGame(
        mode: ClassicMode(),
        onGameOver: () => ends++,
        onScoreChanged: (_) {},
      );
      await load(game);
      game.snake.segments = almostFull(
        cells(game.gridWidth, game.gridHeight),
        const Point(0, 0),
        {const Point(1, 0)},
      );
      game.food.gridPosition = const Point(1, 0);
      game.update(1);
      expect(game.hasWon, true);
      expect(ends, 1);
      game.update(1);
      expect(ends, 1);
    },
  );

  for (final scores in [(10, 0), (0, 10), (10, 10)]) {
    test(
      'Multiplayer full arena resolves scores $scores exactly once',
      () async {
        var ends = 0;
        final session = GameRegistry.create(
          mode: MultiplayerMode(),
          settings: const GameSettings(),
          onGameOver: () => ends++,
          onVictory: () => fail('match callback only'),
          onScoreChanged: (_) {},
        );
        final game = session.game as MultiplayerGame;
        await load(game);
        game.p1Score = scores.$1;
        game.p2Score = scores.$2;
        final arena = cells(game.gridWidth, game.gridHeight);
        game.debugSetBoard(
          player1: arena.take(arena.length ~/ 2).toList(),
          player2: arena.skip(arena.length ~/ 2).toList(),
        );
        expect(game.debugFoodPosition, null);
        expect(ends, 1);
        expect(
          session.result,
          scores.$1 == scores.$2
              ? SessionResult.draw
              : scores.$1 > scores.$2
              ? SessionResult.player1Wins
              : SessionResult.player2Wins,
        );
        game.update(10);
        expect(ends, 1);
        renderSafely(game);
        game.restart();
        expect(game.matchResult, null);
        expect(game.debugFoodPosition, isNotNull);
        game.debugSetBoard(
          player1: arena.where((p) => p != const Point(0, 0)).toList(),
          player2: [],
        );
        expect(game.debugFoodPosition, const Point(0, 0));
        expect(ends, 1);
      },
    );
  }

  testWidgets('Pending power-up yields last cell before it mounts', (
    tester,
  ) async {
    final game = SnakeGame(
      mode: ArcadeMode(),
      onGameOver: () => fail('death'),
      onScoreChanged: (_) {},
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget(game: game),
      ),
    );
    await tester.runAsync(() => game.loaded);
    await tester.pump();
    game.snake.segments = almostFull(
      cells(game.gridWidth, game.gridHeight),
      const Point(0, 0),
      {const Point(1, 0), const Point(2, 0)},
    );
    game.food.gridPosition = const Point(1, 0);
    game.update(31); // Spawn a power-up and replace it with food in one tick.
    game.update(0);
    await tester.pump();
    expect(game.food.gridPosition, const Point(2, 0));
    expect(game.children.whereType<PowerUp>(), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Arcade power-up on last free cell yields to food', (
    tester,
  ) async {
    var wins = 0;
    final game = SnakeGame(
      mode: ArcadeMode(),
      onGameOver: () => fail('death'),
      onVictory: () => wins++,
      onScoreChanged: (_) {},
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget(game: game),
      ),
    );
    await tester.runAsync(() => game.loaded);
    await tester.pump();
    game.snake.segments = almostFull(
      cells(game.gridWidth, game.gridHeight),
      const Point(0, 0),
      {const Point(2, 0), const Point(3, 0)},
    );
    game.food.gridPosition = const Point(2, 0);
    game.activeBuffs[PowerUpType.shield] = 999;
    game.update(
      31,
    ); // Shield absorbs the blocked move; sole free cell gets power-up.
    game.update(0); // Mount pending component without advancing the snake.
    await tester.pump();
    final power = game.children.whereType<PowerUp>().single;
    power.gridPosition = const Point(3, 0);
    game.snake.segments = almostFull(
      cells(game.gridWidth, game.gridHeight),
      const Point(1, 0),
      {const Point(2, 0), const Point(3, 0)},
    );
    game.update(1);
    game.update(0);
    await tester.pump();
    expect(game.food.gridPosition, const Point(3, 0));
    expect(game.children.whereType<PowerUp>(), isEmpty);
    expect(wins, 0);
    game.update(1);
    expect(wins, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
