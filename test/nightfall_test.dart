import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/nightfall_game.dart';
import 'package:naga/modes/nightfall_mode.dart';
import 'package:naga/services/settings_service.dart';

Future<ByteData> renderGame(NightfallGame game) async {
  final recorder = ui.PictureRecorder();
  game.render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(game.size.x.ceil(), game.size.y.ceil());
  final bytes = (await image.toByteData())!;
  image.dispose();
  picture.dispose();
  return bytes;
}

/// Brightness (0-255 sum of RGB / 3) at the centre of [cell].
double brightness(NightfallGame game, ByteData bytes, Point<int> cell) {
  final p = game.gridToScreen(cell);
  final x = (p.x + game.cellSize / 2).floor();
  final y = (p.y + game.cellSize / 2).floor();
  final i = (y * game.size.x.ceil() + x) * 4;
  return (bytes.getUint8(i) + bytes.getUint8(i + 1) + bytes.getUint8(i + 2)) / 3;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the lantern shrinks with score but never below 2.5 cells', () {
    final mode = NightfallMode();
    expect(mode.lanternCells(0), 4.5);
    expect(mode.lanternCells(200), lessThan(4.5));
    expect(mode.lanternCells(100000), 2.5);
  });

  test('only the lantern lights the board', () async {
    final session = GameRegistry.create(
      mode: NightfallMode(),
      settings: const GameSettings(),
      onGameOver: () {},
      onVictory: () {},
      onScoreChanged: (_) {},
    );
    final game = session.game as NightfallGame;
    game.onGameResize(Vector2(400, 560));
    await game.onLoad();
    final head = game.snake.segments.first;
    final bytes = await renderGame(game);
    final lit = brightness(game, bytes, head);
    // A corner well outside the lantern and away from the food's glimmer.
    final w = game.gridWidth - 1, h = game.gridHeight - 1;
    final corner = [const Point(0, 0), Point(w, 0), Point(0, h), Point(w, h)]
        .firstWhere((c) =>
            c.distanceTo(head) > 8 && c.distanceTo(game.food.gridPosition) > 3);
    final dark = brightness(game, bytes, corner);
    expect(lit, greaterThan(40), reason: 'the head is drawn under the lantern');
    expect(dark, lessThan(15), reason: 'far cells are night');
    expect(session.canRespawn, isTrue, reason: 'Nightfall uses the lives setting');
  });
}
