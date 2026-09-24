import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/portals_game.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/portals_mode.dart';
import 'package:naga/services/settings_service.dart';

Future<PortalsGame> start({void Function()? onGameOver}) async {
  final game = PortalsGame(
    mode: PortalsMode(),
    onGameOver: onGameOver ?? () {},
    onScoreChanged: (_) {},
    random: Random(3),
  );
  game.onGameResize(Vector2(400, 560));
  await game.onLoad();
  return game;
}

/// Puts the snake heading right with its head just left of [target].
void aimAt(PortalsGame game, Point<int> target) {
  game.snake.segments
    ..clear()
    ..addAll([
      Point(target.x - 1, target.y),
      Point(target.x - 2, target.y),
      Point(target.x - 3, target.y),
    ]);
  game.currentDirection = Direction.right;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stepping into either portal comes out of the other', () async {
    const a = Point(5, 5), b = Point(15, 20);
    for (final (entry, exit) in [(a, b), (b, a)]) {
      final game = await start();
      game.portals = (a, b);
      aimAt(game, entry);
      game.food.gridPosition = const Point(0, 0);
      game.update(1);
      expect(game.snake.segments.first, exit);
      // Still heading right: the next step leaves the exit to the right.
      game.update(1);
      expect(game.snake.segments.first, Point(exit.x + 1, exit.y));
      expect(game.gameState, GameState.playing);
    }
  });

  test('portals move after a meal and never share a cell with food', () async {
    final game = await start();
    final before = game.portals!;
    final head = game.snake.segments.first;
    game.food.gridPosition = Point(head.x + 1, head.y);
    game.update(1);
    expect(game.score, 10);
    final after = game.portals!;
    expect(after, isNot(before));
    final cells = {after.$1, after.$2};
    expect(cells.contains(game.food.gridPosition), isFalse);
    expect(cells.any(game.snake.segments.contains), isFalse);
  });

  test('coming out onto your own body kills', () async {
    var deaths = 0;
    final game = await start(onGameOver: () => deaths++);
    // The exit cell is part of the body.
    aimAt(game, const Point(8, 10));
    game.snake.segments.add(const Point(12, 12));
    game.portals = (const Point(8, 10), const Point(12, 12));
    game.food.gridPosition = const Point(0, 0);
    game.update(1);
    expect(deaths, 1);
  });

  test('registry session renders with portals', () async {
    final session = GameRegistry.create(
      mode: PortalsMode(),
      settings: const GameSettings(),
      onGameOver: () {},
      onVictory: () {},
      onScoreChanged: (_) {},
    );
    final game = session.game as PortalsGame;
    game.onGameResize(Vector2(400, 560));
    await game.onLoad();
    expect(game.portals, isNotNull);
    expect(session.canRespawn, isTrue);
    final recorder = ui.PictureRecorder();
    game.render(ui.Canvas(recorder));
    recorder.endRecording().dispose();
  });
}
