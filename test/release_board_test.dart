import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/arcade_mode.dart';
import 'package:naga/modes/classic_mode.dart';

import 'component_render_test.dart' show raster;

Future<void> _mount(WidgetTester tester, SnakeGame game, Size size) async {
  final initialLoad = !game.isLoaded;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.fromSize(
          size: size,
          child: GameWidget<SnakeGame>(game: game),
        ),
      ),
    ),
  );
  await tester.runAsync(() => game.loaded);
  await tester.pump();
  if (initialLoad) game.gameState = GameState.paused;
  await tester.pump();
  expect(game.board.isMounted, isTrue);
}

void main() {
  test('resize initializes custom grid layout before load', () {
    final game = SnakeGame(
      mode: ClassicMode(),
      gridWidth: 10,
      gridHeight: 16,
      onGameOver: () {},
      onScoreChanged: (_) {},
    );
    game.onGameResize(Vector2.zero());
    expect(game.isLoaded, isFalse);
    expect(game.cellSize, 0);
    expect(game.boardOffset, Vector2.zero());
    game.onGameResize(Vector2(120, 160));
    expect(game.isLoaded, isFalse);
    expect(game.cellSize, 10);
    expect(game.boardOffset, Vector2(10, 0));
    expect(game.gridToScreen(const Point(2, 3)), Vector2(30, 30));
  });

  for (final mode in [ClassicMode(), ArcadeMode()]) {
    for (final axis in ['x', 'y']) {
      testWidgets('${mode.name} resize changes only $axis board offset', (
        tester,
      ) async {
        final game = SnakeGame(
          mode: mode,
          onGameOver: () {},
          onScoreChanged: (_) {},
        );
        try {
          final initialSize = axis == 'x'
              ? const Size(220, 280)
              : const Size(200, 300);
          final resized = axis == 'x'
              ? const Size(260, 280)
              : const Size(200, 340);
          await _mount(tester, game, initialSize);
          final board = game.board;
          final original = await tester.runAsync(() => raster(board.render));
          await _mount(tester, game, resized);
          expect(game.cellSize, 10);
          expect(
            game.boardOffset,
            axis == 'x' ? Vector2(30, 0) : Vector2(0, 30),
          );
          final cached = await tester.runAsync(() => raster(board.render));
          expect(cached, isNot(orderedEquals(original!)));
          board.invalidateCache();
          final fresh = await tester.runAsync(() => raster(board.render));
          expect(cached, orderedEquals(fresh!));
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('${mode.name} same board can be removed and re-added', (
      tester,
    ) async {
      final game = SnakeGame(
        mode: mode,
        onGameOver: () {},
        onScoreChanged: (_) {},
      );
      try {
        await _mount(tester, game, const Size(200, 300));
        final board = game.board;
        final original = await tester.runAsync(() => raster(board.render));
        for (var cycle = 0; cycle < 2; cycle++) {
          board.removeFromParent();
          await tester.pump();
          expect(board.isMounted, isFalse);
          expect(board.isRemoved, isTrue);
          expect(game.children, isNot(contains(board)));
          game.add(board);
          await tester.pump();
          expect(board.isMounted, isTrue);
          expect(game.children, contains(board));
          // Same dimensions must not allow reuse of a disposed picture.
          expect(tester.takeException(), isNull);
          final readded = await tester.runAsync(() => raster(board.render));
          expect(readded, orderedEquals(original!));
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '${mode.name} mounted board follows portrait-landscape resize',
      (tester) async {
        final game = SnakeGame(
          mode: mode,
          onGameOver: () => fail('Resize must not end the game'),
          onScoreChanged: (_) => fail('Resize must not change score'),
        );
        try {
          await _mount(tester, game, const Size(200, 300));
          expect(game.cellSize, 10);
          expect(game.boardOffset, Vector2(0, 10));
          final board = game.board;
          final snake = game.snake;
          final segments = game.snake.segments.toList();
          final food = game.food;
          final foodPosition = food.gridPosition;
          final portrait = await tester.runAsync(() => raster(board.render));

          await _mount(tester, game, const Size(300, 200));
          expect(game.size, Vector2(300, 200));
          expect(game.cellSize, closeTo(200 / 28, 1e-9));
          // Flame's Vector2 stores float32 coordinates.
          expect(game.boardOffset.x, closeTo((300 - 200 / 28 * 20) / 2, 1e-5));
          expect(game.boardOffset.y, 0);
          expect(game.gridToScreen(const Point(0, 0)), game.boardOffset);
          expect(game.board, same(board));
          expect(game.snake, same(snake));
          expect(game.snake.segments, orderedEquals(segments));
          expect(game.food, same(food));
          expect(game.food.gridPosition, foodPosition);
          expect(game.gameState, GameState.paused);
          final landscape = await tester.runAsync(() => raster(board.render));
          expect(landscape, isNot(orderedEquals(portrait!)));
          board.invalidateCache();
          final fresh = await tester.runAsync(() => raster(board.render));
          expect(landscape, orderedEquals(fresh!));

          await _mount(tester, game, const Size(200, 300));
          expect(game.cellSize, 10);
          expect(game.boardOffset, Vector2(0, 10));
          expect(
            await tester.runAsync(() => raster(board.render)),
            orderedEquals(portrait),
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
