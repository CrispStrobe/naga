import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/snake_game.dart' show Direction, GameState;
import 'package:naga/game/venom_game.dart';
import 'package:naga/modes/venom_mode.dart';

VenomGame _makeGame() {
  final game = VenomGame(
    mode: VenomMode(),
    onGameOver: () {},
    onScoreChanged: (_) {},
  );
  game.onGameResize(Vector2(400, 560));
  return game;
}

void main() {
  test('bomb capacity grows with snake length', () async {
    final game = _makeGame();
    await game.onLoad();
    expect(game.maxBombs, 3);
    game.targetLength = 6;
    expect(game.maxBombs, 4);
    game.targetLength = 30;
    expect(game.maxBombs, 6);
  });

  test('bomb drops even when snake is blocked against a wall', () async {
    final game = _makeGame();
    await game.onLoad();
    // Snake spawns one row above the bottom border — steer into it
    game.changeDirection(Direction.down);
    game.update(0.2); // tick: turn down, blocked by border, stay put
    expect(game.gameState, GameState.playing);
    expect(game.bombsAvailable, 3);
    game.dropBomb();
    game.update(0.2); // tick: bomb placed at tail despite being blocked
    expect(game.bombsAvailable, 2);
  });

  test('snake grows toward targetLength as it moves', () async {
    final game = _makeGame();
    await game.onLoad();
    expect(game.snakeSegments.length, VenomGame.startLength);
    game.targetLength = 5;
    game.update(0.2);
    game.update(0.2);
    expect(game.snakeSegments.length, 5);
  });
}
