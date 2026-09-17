import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/ascii_game.dart';
import 'package:naga/game/cga_game.dart';
import 'package:naga/game/nibbles_game.dart';
import 'package:naga/game/snake_game.dart' show Direction, GameState;
import 'package:naga/game/shared/grid_snake_body.dart';
import 'package:naga/modes/ascii_mode.dart';
import 'package:naga/modes/cga_mode.dart';
import 'package:naga/modes/nibbles_mode.dart';

import 'package:naga/game/snake2_game.dart';
import 'package:naga/modes/snake2_mode.dart';
import 'package:naga/game/rush_game.dart';
import 'package:naga/modes/rush_mode.dart';
import 'package:naga/game/swarm_game.dart';
import 'package:naga/modes/swarm_mode.dart';
import 'package:naga/game/fangs_game.dart';
import 'package:naga/modes/fangs_mode.dart';
import 'package:naga/game/venom_game.dart';
import 'package:naga/modes/venom_mode.dart';
import 'package:naga/game/dungeon_game.dart';
import 'package:naga/modes/dungeon_mode.dart';
import 'package:naga/game/pit_game.dart';
import 'package:naga/modes/pit_mode.dart';
import 'package:naga/game/vs_ai_game.dart';
import 'package:naga/modes/vs_ai_mode.dart';

void main() {
  final extended = <String, dynamic Function()>{
    'Snake II': () => Snake2Game(mode: Snake2Mode(), onGameOver: () {}, onScoreChanged: (_) {}),
    'Rush': () => RushGame(mode: RushMode(), onGameOver: () {}, onScoreChanged: (_) {}),
    'Swarm': () => SwarmGame(mode: SwarmMode(), onGameOver: () {}, onScoreChanged: (_) {}),
    'Fangs': () => FangsGame(mode: FangsMode(), onGameOver: () {}, onScoreChanged: (_) {}),
    'Venom': () => VenomGame(mode: VenomMode(), onGameOver: () {}, onWin: () {}, onScoreChanged: (_) {}),
    'Dungeon': () => DungeonGame(mode: DungeonMode(), onGameOver: () {}, onScoreChanged: (_) {}),
    'Pit': () => PitGame(mode: PitMode(), onGameOver: () {}, onScoreChanged: (_) {}),
  };
  for (final entry in extended.entries) {
    test('${entry.key} spawns a mutable ring body', () async {
      final dynamic game = entry.value();
      game.onGameResize(Vector2(400, 560));
      await game.onLoad();
      final List<Point<int>> segments = game.snakeSegments;
      expect(segments, isA<GridSnakeBody>());
      final tail = segments.last;
      segments.add(tail);
      segments.removeLast();
      expect(segments.contains(tail), isTrue);
      final replacement = [const Point(5, 5), const Point(4, 5)];
      game.snakeSegments = replacement;
      expect(identical(game.snakeSegments, replacement), isTrue);
    });
  }
  test('VS AI spawns ring player body', () async {
    final game = VsAiGame(mode: VsAiMode(), onGameOver: () {}, onScoreChanged: (_) {});
    game.onGameResize(Vector2(400, 560));
    await game.onLoad();
    expect(game.playerSegments, isA<GridSnakeBody>());
  });

  final factories = <String, dynamic Function()>{
    'ASCII': () => AsciiGame(mode: AsciiMode(), onGameOver: () {}, onScoreChanged: (_) {}, startSpeed: 0.1),
    'CGA': () => CgaGame(mode: CgaMode(), onGameOver: () {}, onScoreChanged: (_) {}, startSpeed: 0.1),
    'Nibbles': () => NibblesGame(mode: NibblesMode(), onGameOver: () {}, onScoreChanged: (_) {}, startSpeed: 0.1),
  };
  for (final entry in factories.entries) {
    test('${entry.key} uses ring on spawn and respawn, preserving List assignment', () async {
      final dynamic game = entry.value();
      game.onGameResize(Vector2(400, 560));
      await game.onLoad();
      expect(game.snakeSegments, isA<GridSnakeBody>());
      final assigned = [const Point(5, 5), const Point(4, 5), const Point(3, 5)];
      game.snakeSegments = assigned;
      expect(identical(game.snakeSegments, assigned), isTrue);
      game.foodPosition = const Point(6, 5);
      game.update(0.1);
      expect(assigned, [const Point(6, 5), const Point(5, 5), const Point(4, 5), const Point(3, 5)]);
      game.respawn();
      expect(game.snakeSegments, isA<GridSnakeBody>());
      expect(game.snakeSegments.length, 3);
      game.restart();
      expect(game.snakeSegments, isA<GridSnakeBody>());
      expect(game.score, 0);
    });
    test('${entry.key} retains strict tail collision rule', () async {
      final dynamic game = entry.value();
      game.onGameResize(Vector2(400, 560));
      await game.onLoad();
      game.snakeSegments = GridSnakeBody([
        const Point(5, 5), const Point(5, 6), const Point(6, 6), const Point(6, 5),
      ]);
      game.foodPosition = const Point(10, 10);
      game.currentDirection = Direction.right;
      game.update(0.1);
      expect(game.gameState, GameState.gameOver);
      expect(game.snakeSegments.first, const Point(5, 5));
    });
  }
}
