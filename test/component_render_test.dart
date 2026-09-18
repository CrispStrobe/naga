import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/arcade_mode.dart';
import 'package:naga/modes/classic_mode.dart';
import 'package:naga/modes/game_mode.dart';

Future<Uint8List> raster(void Function(ui.Canvas) render) async {
  final recorder = ui.PictureRecorder();
  render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 320);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final GameMode mode in [ClassicMode(), ArcadeMode()]) {
    for (final axis in ['x', 'y']) {
      test('${mode.name} board cache follows in-place $axis offset changes',
          () async {
        final game = SnakeGame(
          mode: mode,
          onGameOver: () {},
          onScoreChanged: (_) {},
        );
        game.onGameResize(Vector2(200, 280));
        await game.onLoad();
        final board = game.board;
        addTearDown(board.onRemove);
        final original = await raster(board.render);
        final cellSize = game.cellSize;
        // Exercise the component's layout inputs directly: a resize need not
        // change cell size, and Vector2 may be mutated rather than replaced.
        if (axis == 'x') {
          game.boardOffset.x += 20;
        } else {
          game.boardOffset.y += 20;
        }
        expect(game.cellSize, cellSize);
        final cached = await raster(board.render);
        board.invalidateCache();
        final fresh = await raster(board.render);
        expect(original, isNot(orderedEquals(fresh)));
        expect(cached, orderedEquals(fresh),
            reason: 'Same cell size must not reuse the old offset');
        expect(await raster(board.render), orderedEquals(fresh));
      });
    }
  }
}
