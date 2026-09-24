import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/snake_game.dart' show Direction, GameState;
import 'package:naga/game/territory_game.dart';
import 'package:naga/modes/territory_mode.dart';
import 'package:naga/services/settings_service.dart';

Future<TerritoryGame> start({
  int rivals = 0,
  void Function()? onGameOver,
  void Function()? onVictory,
  int seed = 1,
}) async {
  final game = TerritoryGame(
    mode: TerritoryMode(),
    onGameOver: onGameOver ?? () {},
    onVictory: onVictory ?? () {},
    onScoreChanged: (_) {},
    rivalCount: rivals,
    random: Random(seed),
  );
  game.onGameResize(Vector2(480, 640));
  await game.onLoad();
  return game;
}

/// Steers the player through [moves] (one direction per tick).
void drive(TerritoryGame game, List<Direction> moves) {
  for (final m in moves) {
    game.changeDirection(m);
    game.tick();
  }
}

List<Direction> times(Direction d, int n) => List.filled(n, d);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a loop out of your land claims the trail and what it encloses',
      () async {
    final game = await start();
    // Home is the 3x3 around (5, 25). Loop up, right, down, and left
    // back into it.
    expect(game.ownedBy(TerritoryGame.playerId), 9);
    drive(game, [
      ...times(Direction.up, 5),
      ...times(Direction.right, 4),
      ...times(Direction.down, 4),
      ...times(Direction.left, 3),
    ]);
    expect(game.player.trail, isEmpty);
    // The rectangle x 5..9, y 20..24 (the trail plus its inside) is land now.
    for (var y = 20; y <= 24; y++) {
      for (var x = 5; x <= 9; x++) {
        expect(game.ownerAt(Point(x, y)), TerritoryGame.playerId, reason: '($x, $y)');
      }
    }
    expect(game.score, (game.playerShare * 100).floor());
  });

  test('walls help enclose: a loop against the wall claims its pocket',
      () async {
    final game = await start();
    // Out left to the wall column x=0, down along it and back in.
    drive(game, [
      ...times(Direction.left, 1),
      ...times(Direction.up, 3),
      ...times(Direction.left, 4),
      ...times(Direction.down, 3),
      ...times(Direction.right, 4),
    ]);
    expect(game.player.trail, isEmpty);
    expect(game.ownerAt(const Point(1, 23)), TerritoryGame.playerId);
    expect(game.ownerAt(const Point(0, 22)), TerritoryGame.playerId);
  });

  test('your own trail and the walls kill', () async {
    var deaths = 0;
    final game = await start(onGameOver: () => deaths++);
    drive(game, [
      ...times(Direction.up, 3),
      Direction.right,
      Direction.down,
      Direction.left, // Back onto the trail.
    ]);
    expect(deaths, 1);
    expect(game.gameState, GameState.gameOver);

    final walled = await start(onGameOver: () => deaths++);
    drive(walled, times(Direction.left, 6));
    expect(deaths, 2);
  });

  test('crossing a rival trail kills the rival and frees its land', () async {
    final game = await start(rivals: 1);
    final rival = game.rivals.single;
    // Freeze the rival outside its land with a trail across the player's path.
    rival
      ..head = const Point(15, 14)
      ..direction = Direction.right;
    for (var x = 5; x <= 14; x++) {
      rival.trail.add(Point(x, 20));
      rival.trailCells.add(Point(x, 20));
    }
    rival.legs.addAll([(Direction.right, 1)]);
    drive(game, times(Direction.up, 5));
    expect(rival.alive, isFalse);
    expect(game.ownedBy(rival.id), 0);
    expect(game.gameState, GameState.playing);
  });

  test('a rival crossing your trail kills you', () async {
    var deaths = 0;
    final game = await start(rivals: 1, onGameOver: () => deaths++);
    drive(game, times(Direction.up, 3)); // Trail at (5, 23), head (5, 22).
    final rival = game.rivals.single;
    // The rival cuts across the older trail cell, not the player's head.
    rival
      ..head = const Point(4, 23)
      ..direction = Direction.right
      ..legs.clear()
      ..legs.add((Direction.right, 1));
    game.tick();
    expect(deaths, 1);
  });

  test('owning half the board wins', () async {
    var wins = 0;
    final game = await start(onVictory: () => wins++);
    // One big loop: the rectangle x 4..23, y 11..31 (420 of 768 cells).
    drive(game, [
      Direction.left,
      ...times(Direction.up, 14),
      ...times(Direction.right, 19),
      ...times(Direction.down, 20),
      ...times(Direction.left, 19),
      ...times(Direction.up, 5),
    ]);
    expect(game.playerShare, greaterThanOrEqualTo(0.5));
    expect(wins, 1);
    expect(game.hasWon, isTrue);
  });

  test('rivals survive long unattended runs without errors', () async {
    for (var seed = 0; seed < 5; seed++) {
      final game = await start(rivals: 3, seed: seed);
      // Keep the player circling inside its home so only rivals roam.
      final loop = [Direction.up, Direction.right, Direction.down, Direction.left];
      for (var t = 0; t < 600 && game.gameState == GameState.playing; t++) {
        game.changeDirection(loop[t % 4]);
        game.update(0.2);
      }
      expect(game.rivals.any((r) => r.alive || r.respawnTimer > 0), isTrue);
    }
  });

  test('registry session renders and reports victory', () async {
    final session = GameRegistry.create(
      mode: TerritoryMode(),
      settings: const GameSettings(),
      onGameOver: () {},
      onVictory: () {},
      onScoreChanged: (_) {},
    );
    final game = session.game as TerritoryGame;
    game.onGameResize(Vector2(390, 700));
    await game.onLoad();
    expect(game.rivals, hasLength(2));
    final recorder = ui.PictureRecorder();
    game.render(ui.Canvas(recorder));
    recorder.endRecording().dispose();
    game.hasWon = true;
    expect(session.result.name, 'victory');
  });
}
