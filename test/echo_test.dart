import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/echo_game.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/echo_mode.dart';
import 'package:naga/services/settings_service.dart';

Future<EchoGame> start({void Function()? onGameOver}) async {
  final game = EchoGame(
    mode: EchoMode(),
    onGameOver: onGameOver ?? () {},
    onScoreChanged: (_) {},
    random: Random(9),
  );
  game.onGameResize(Vector2(400, 560));
  await game.onLoad();
  return game;
}

/// Moves once per call with the food parked out of the way.
void step(EchoGame game, [int moves = 1]) {
  for (var i = 0; i < moves; i++) {
    game.food.gridPosition = const Point(0, 27);
    game.update(1);
  }
}

/// Replaces the last run with [path] (length 3 per step) and restarts, so
/// the new run is echoed by [path].
void plantEcho(EchoGame game, List<Point<int>> path) {
  game.lastRecording
    ..clear()
    ..addAll([for (final p in path) (p, 3)]);
  game.restart();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(EchoGame.resetSession);

  test('a new game (Play again) echoes the previous game', () async {
    final first = await start();
    step(first, 12);
    final path = [for (final (p, _) in first.lastRecording) p];
    // The screen builds a fresh game rather than restarting this one.
    final second = await start();
    step(second, EchoGame.echoDelay);
    expect(second.echoBody, [path.first]);
  });

  test('the first run has no echo and records every move', () async {
    final game = await start();
    step(game, 5);
    expect(game.echoBody, isEmpty);
    expect(game.lastRecording, hasLength(6));
    expect(game.lastRecording.last.$1, game.snake.segments.first);
  });

  test('the echo replays the last run, delayed, with its recorded length',
      () async {
    final game = await start();
    final column = [for (var y = 27; y >= 10; y--) Point(1, y)];
    plantEcho(game, column);
    // Head up the board so the player outlasts the wall for 11+ moves.
    game.changeDirection(Direction.up);
    step(game, EchoGame.echoDelay - 1);
    expect(game.echoBody, isEmpty, reason: 'still inside the delay');
    step(game);
    expect(game.echoBody, [column[0]]);
    step(game, 3);
    expect(game.echoBody, [column[3], column[2], column[1]]);
  });

  test('steering into the echo as drawn kills', () async {
    var deaths = 0;
    final game = await start(onGameOver: () => deaths++);
    final head = game.snake.segments.first;
    // The echo appears after move 8 on the cell the player (heading right)
    // enters on move 9, so the player steers into a visible echo.
    final meet = Point(head.x + 9, head.y);
    plantEcho(game, [meet, for (var y = 1; y <= 9; y++) Point(meet.x, head.y - y)]);
    step(game, EchoGame.echoDelay + 1);
    expect(deaths, 1);
    expect(game.gameState, GameState.gameOver);
  });

  test('the echo running into you is harmless', () async {
    var deaths = 0;
    final game = await start(onGameOver: () => deaths++);
    final head = game.snake.segments.first;
    // The echo's head arrives on the player's cell on the same move: the
    // player could not have seen it coming, so the echo passes through.
    final meet = Point(head.x + 9, head.y);
    plantEcho(game, [
      Point(meet.x, head.y - 1),
      meet,
      for (var y = 1; y <= 8; y++) Point(meet.x, head.y + y),
    ]);
    step(game, EchoGame.echoDelay + 1);
    expect(deaths, 0);
    expect(game.echoBody.first, meet);
  });

  test('outliving the echo pays a bonus once', () async {
    final game = await start();
    plantEcho(game, [for (var y = 0; y < 10; y++) Point(0, y)]);
    step(game, 5);
    game.changeDirection(Direction.down);
    step(game, EchoGame.echoDelay + 10 - 5);
    expect(game.outlivedEcho, isTrue);
    expect(game.score, EchoGame.outliveBonus);
    expect(game.echoBody, isEmpty);
    step(game, 2);
    expect(game.score, EchoGame.outliveBonus);
  });

  test('a run too short to echo keeps the previous echo', () async {
    final game = await start();
    final column = [for (var y = 27; y >= 10; y--) Point(1, y)];
    plantEcho(game, column);
    step(game, 3); // Shorter than the delay.
    game.restart();
    step(game, EchoGame.echoDelay);
    expect(game.echoBody, [column[0]]);
  });

  test('registry session renders', () async {
    final session = GameRegistry.create(
      mode: EchoMode(),
      settings: const GameSettings(),
      onGameOver: () {},
      onVictory: () {},
      onScoreChanged: (_) {},
    );
    final game = session.game as EchoGame;
    game.onGameResize(Vector2(400, 560));
    await game.onLoad();
    expect(session.canRespawn, isTrue);
    final recorder = ui.PictureRecorder();
    game.render(ui.Canvas(recorder));
    recorder.endRecording().dispose();
  });
}
