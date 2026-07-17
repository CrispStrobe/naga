import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/dungeon_game.dart';
import 'package:naga/modes/dungeon_mode.dart';

DungeonGame _makeGame() {
  final game = DungeonGame(
    mode: DungeonMode(),
    onGameOver: () {},
    onScoreChanged: (_) {},
  );
  game.onGameResize(Vector2(400, 560));
  return game;
}

void main() {
  test('starts with a small sword loadout and empty ranged inventory',
      () async {
    final game = _makeGame();
    await game.onLoad();
    expect(game.swordHits, 2);
    expect(game.arrows, 0);
    expect(game.hammerCharges, 0);
    expect(game.shieldBlocks, 0);
  });

  test('firing an arrow consumes one arrow; firing with none is a no-op',
      () async {
    final game = _makeGame();
    await game.onLoad();
    game.fireArrow();
    expect(game.arrows, 0); // none to fire
    game.arrows = 3;
    game.fireArrow();
    expect(game.arrows, 2);
  });
}
