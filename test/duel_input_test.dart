import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/multiplayer_game.dart';
import 'package:naga/game/snake_game.dart' show Direction;
import 'package:naga/modes/multiplayer_mode.dart';
import 'package:naga/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MultiplayerGame> start() async {
    final session = GameRegistry.create(
      mode: MultiplayerMode(),
      settings: const GameSettings(),
      onGameOver: () {},
      onVictory: () {},
      onScoreChanged: (_) {},
    );
    final game = session.game as MultiplayerGame;
    game.onGameResize(Vector2(400, 560));
    await game.onLoad();
    return game;
  }

  Future<MultiplayerGame> startPlaying() async =>
      (await start())..debugSkipCountdown();

  test('nothing moves during the countdown; turns pressed in it apply first',
      () async {
    final game = await start();
    final head = game.debugP1Head;
    game.changeDirectionP1(Direction.up);
    game.update(MultiplayerGame.countdownSeconds / 2);
    game.update(MultiplayerGame.countdownSeconds / 2 - 0.01);
    expect(game.debugP1Head, head, reason: 'still counting down');
    game.update(0.02); // Countdown over.
    game.update(1);
    expect(game.debugP1Head, Point(head.x, head.y - 1));
  });

  test('play again restarts the countdown', () async {
    final game = await startPlaying();
    game.restart();
    final head = game.debugP1Head;
    game.update(1);
    expect(game.debugP1Head, head);
  });

  test('two quick turns inside one tick both apply, in order', () async {
    final game = await startPlaying();
    final head = game.debugP1Head;
    // P1 starts heading right. Up then right before the next tick used to
    // keep only the last press, so the snake never left its row.
    game.changeDirectionP1(Direction.up);
    game.changeDirectionP1(Direction.right);
    game.update(1); // One tick per update: the timer resets on each tick.
    expect(game.debugP1Head, Point(head.x, head.y - 1));
    game.update(1);
    expect(game.debugP1Head, Point(head.x + 1, head.y - 1));
  });

  test('a reversal against the last queued turn is ignored', () async {
    final game = await startPlaying();
    final head = game.debugP1Head;
    game.changeDirectionP1(Direction.up);
    game.changeDirectionP1(Direction.down);
    game.update(1);
    game.update(1);
    expect(game.debugP1Head, Point(head.x, head.y - 2));
  });
}
