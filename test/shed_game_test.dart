import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/shed_game.dart';
import 'package:naga/game/snake_game.dart' show GameState;
import 'package:naga/modes/shed_mode.dart';
import 'package:naga/services/settings_service.dart';

Future<ShedGame> start({void Function()? onGameOver}) async {
  final game = ShedGame(
    mode: ShedMode(),
    onGameOver: onGameOver ?? () {},
    onScoreChanged: (_) {},
    random: Random(1),
  );
  game.onGameResize(Vector2(400, 620));
  await game.onLoad();
  return game;
}

/// Feeds the snake by placing food directly ahead, one tick per meal.
void eatAhead(ShedGame game) {
  final head = game.snakeSegments.first;
  game.food = Point(head.x + 1, head.y);
  game.update(1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each meal grows the snake by two', () async {
    final game = await start();
    eatAhead(game);
    expect(game.snakeSegments.length, 3);
    game.update(1);
    game.update(1);
    expect(game.snakeSegments.length, 5);
    game.update(1);
    expect(game.snakeSegments.length, 5);
  });

  test('every fourth meal sheds the body behind the neck into skin', () async {
    final game = await start();
    for (var meal = 1; meal <= 3; meal++) {
      eatAhead(game);
      expect(game.mealsUntilShed, 4 - meal);
    }
    final before = List.of(game.snakeSegments);
    eatAhead(game);
    expect(game.snakeSegments.length, ShedGame.keptSegments);
    // Growth is applied one tick late, so the fourth meal sheds the tail
    // the snake had just before eating it (minus the moved-off tail cell).
    expect(game.skin, isNotEmpty);
    expect(game.skin.every(before.contains), isTrue);
    expect(game.mealsUntilShed, ShedGame.shedEvery);
    expect(game.gameState, GameState.playing);
  });

  test('a row filled with skin clears for a bonus', () async {
    final game = await start();
    // The body lies along row 5 from x=13 back to x=6 and the head has
    // turned up out of the row; x=0..5 is skin already, so shedding the
    // body completes the row. (The kept head and neck never count.)
    game.snakeSegments
      ..clear()
      ..addAll([
        const Point(13, 2), const Point(13, 3), const Point(13, 4),
        for (var x = 13; x >= 6; x--) Point(x, 5),
      ]);
    for (var x = 0; x < 6; x++) {
      game.skin.add(Point(x, 5));
    }
    game.skin.add(const Point(0, 6)); // Other rows are untouched.
    final score = game.score;
    // Keeps the head and neck; sheds x=13..6 of row 5 (8 cells).
    game.shedSkin();
    expect(game.snakeSegments, [const Point(13, 2), const Point(13, 3), const Point(13, 4)]);
    expect(game.rowsCleared, 1);
    expect(game.skin, {const Point(0, 6)});
    expect(game.score, score + 8 * 2 + ShedGame.rowBonus.first);
  });

  test('skin kills', () async {
    var deaths = 0;
    final game = await start(onGameOver: () => deaths++);
    final head = game.snakeSegments.first;
    game.skin.add(Point(head.x + 1, head.y));
    game.update(1);
    expect(deaths, 1);
    expect(game.gameState, GameState.gameOver);
  });

  test('food never spawns on skin or the snake', () async {
    final game = await start();
    final snakeRow = game.snakeSegments.first.y;
    // Only row 3 and the snake's own row stay open.
    game.skin.addAll([
      for (var y = 0; y < ShedGame.gridHeight; y++)
        for (var x = 0; x < ShedGame.gridWidth; x++)
          if (y != 3 && y != snakeRow) Point(x, y),
    ]);
    for (var meal = 0; meal < 3; meal++) {
      eatAhead(game);
      final f = game.food!;
      expect(game.skin.contains(f), isFalse);
      expect(game.snakeSegments.contains(f), isFalse);
      expect(f.y == 3 || f.y == snakeRow, isTrue);
    }
  });

  test('registry session and rendering after a resize', () async {
    final session = GameRegistry.create(
      mode: ShedMode(),
      settings: const GameSettings(),
      onGameOver: () {},
      onVictory: () {},
      onScoreChanged: (_) {},
    );
    final game = session.game as ShedGame;
    game.onGameResize(Vector2(400, 620));
    await game.onLoad();
    game.shedSkin();
    game.onGameResize(Vector2(700, 400));
    final recorder = ui.PictureRecorder();
    game.render(ui.Canvas(recorder));
    recorder.endRecording().dispose();
    session.setPaused(true);
    expect(session.isPaused, isTrue);
  });
}
