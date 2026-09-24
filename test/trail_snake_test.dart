import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/trail_game.dart';
import 'package:naga/modes/trail_mode.dart';

Future<TrailGame> start([Vector2? size]) async {
  final game = TrailGame(
    mode: TrailMode(),
    onGameOver: () {},
    onScoreChanged: (_) {},
  );
  game.onGameResize(size ?? Vector2(400, 560));
  await game.onLoad();
  return game;
}

/// Renders only the player snake, so random AI spawns cannot overlap it.
Future<ByteData> renderPlayer(TrailGame game) async {
  final recorder = ui.PictureRecorder();
  game.player.render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(game.size.x.ceil(), game.size.y.ceil());
  final bytes = (await image.toByteData())!;
  image.dispose();
  picture.dispose();
  return bytes;
}

List<int> pixel(TrailGame game, ByteData bytes, Point<int> cell) {
  final p = game.gridToScreen(cell);
  final x = (p.x + game.cellSize / 2).floor();
  final y = (p.y + game.cellSize / 2).floor();
  final i = (y * game.size.x.ceil() + x) * 4;
  return [for (var c = 0; c < 4; c++) bytes.getUint8(i + c)];
}

/// Moves the player right along its row, one cell per call.
void stepRight(TrailGame game, int count) {
  for (var i = 0; i < count; i++) {
    final head = game.player.segments.first;
    game.player.advance(Point(head.x + 1, head.y));
  }
}

void main() {
  test('two quick turns inside one tick both apply, in order', () async {
    final game = await start();
    final head = game.player.segments.first;
    // Heading right: up then right used to keep only the last press.
    game.changeDirection(Direction.up);
    game.changeDirection(Direction.right);
    game.update(1);
    expect(game.player.segments.first, Point(head.x, head.y - 1));
    game.update(1);
    expect(game.player.segments.first, Point(head.x + 1, head.y - 1));
  });

  test('cached trail renders the same once a cell moves into a sealed chunk',
      () async {
    final game = await start(Vector2(2000, 560));
    final start0 = game.player.segments.last;
    // 60 settled cells: all in the open chunk.
    stepRight(game, 60);
    final probe = Point(start0.x + 30, start0.y);
    final before = pixel(game, await renderPlayer(game), probe);
    expect(before[3], greaterThan(0), reason: 'trail cell must be drawn');
    expect(game.player.debugRecordedChunks, 1);

    // 70 settled cells: the probe now lives in the first sealed chunk.
    stepRight(game, 10);
    final after = pixel(game, await renderPlayer(game), probe);
    expect(game.player.debugRecordedChunks, 2);
    expect(after, before);
  });

  test('a resize re-records the trail at the new cell size', () async {
    final game = await start(Vector2(2000, 560));
    final start0 = game.player.segments.last;
    stepRight(game, 20);
    await renderPlayer(game);
    game.onGameResize(Vector2(1000, 280));
    final probe = Point(start0.x + 10, start0.y);
    expect(pixel(game, await renderPlayer(game), probe)[3], greaterThan(0));
  });

  test('a dead snake still draws its last cells as trail', () async {
    final game = await start(Vector2(2000, 560));
    stepRight(game, 20);
    game.player.alive = false;
    final bytes = await renderPlayer(game);
    final settled = pixel(game, bytes, game.player.segments.last - const Point(3, 0));
    // The middle body cell has trail on both sides, like a settled cell.
    expect(pixel(game, bytes, game.player.segments[1]), settled);
  });
}
