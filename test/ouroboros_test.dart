import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/ouroboros_game.dart';
import 'package:naga/modes/ouroboros_mode.dart';
import 'package:naga/services/settings_service.dart';

Future<OuroborosGame> start() async {
  final game = OuroborosGame(
    mode: OuroborosMode(),
    onGameOver: () {},
    onScoreChanged: (_) {},
    random: Random(5),
  );
  game.onGameResize(Vector2(400, 560));
  await game.onLoad();
  return game;
}

/// The perimeter of the rectangle x in [x0, x1], y in [y0, y1], as a body
/// (head first, walking clockwise).
List<Point<int>> ring(int x0, int y0, int x1, int y1) => [
  for (var x = x0; x <= x1; x++) Point(x, y0),
  for (var y = y0 + 1; y <= y1; y++) Point(x1, y),
  for (var x = x1 - 1; x >= x0; x--) Point(x, y1),
  for (var y = y1 - 1; y > y0; y--) Point(x0, y),
];

void setBody(OuroborosGame game, List<Point<int>> body) {
  game.snake.segments
    ..clear()
    ..addAll(body);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a closed ring encloses its inside; the wall never helps', () async {
    final game = await start();
    setBody(game, ring(4, 4, 7, 6));
    expect(game.enclosedCells(), {const Point(5, 5), const Point(6, 5)});

    // A U against the left wall: open to the edge, so nothing is enclosed.
    setBody(game, [
      const Point(0, 4), const Point(1, 4), const Point(2, 4),
      const Point(2, 5), const Point(2, 6), const Point(1, 6), const Point(0, 6),
    ]);
    expect(game.enclosedCells(), isEmpty);
  });

  test('two motes in one loop score 40 and grow the snake by 4', () async {
    final game = await start();
    setBody(game, ring(4, 4, 7, 6));
    game.motes
      ..clear()
      ..addAll([const Point(5, 5), const Point(6, 5), const Point(15, 20)]);
    final score = game.score;
    expect(game.catchEnclosed(), isTrue);
    expect(game.score, score + 40);
    expect(game.moteCatches, 2);
    expect(game.motes, [const Point(15, 20)]);
    // Pending growth shows up as the body lengthening over the next moves.
    final length = game.snake.segments.length;
    setBody(game, [const Point(10, 10), const Point(9, 10), const Point(8, 10)]);
    game.food.gridPosition = const Point(0, 27);
    for (var i = 0; i < 4; i++) {
      game.update(1);
    }
    expect(length, 10);
    expect(game.snake.segments.length, 3 + 4);
  });

  test('a mote the head touches hops away, and motes are refilled', () async {
    final game = await start();
    final head = game.snake.segments.first;
    final ahead = Point(head.x + 1, head.y);
    game.motes
      ..clear()
      ..add(ahead);
    game.food.gridPosition = const Point(0, 27);
    game.update(1);
    expect(game.snake.segments.first, ahead);
    expect(game.motes.contains(ahead), isFalse);
    expect(game.motes.length, OuroborosGame.moteCount);
  });

  test('registry session renders', () async {
    final session = GameRegistry.create(
      mode: OuroborosMode(),
      settings: const GameSettings(),
      onGameOver: () {},
      onVictory: () {},
      onScoreChanged: (_) {},
    );
    final game = session.game as OuroborosGame;
    game.onGameResize(Vector2(400, 560));
    await game.onLoad();
    expect(game.motes, hasLength(OuroborosGame.moteCount));
    final recorder = ui.PictureRecorder();
    game.render(ui.Canvas(recorder));
    recorder.endRecording().dispose();
  });
}
