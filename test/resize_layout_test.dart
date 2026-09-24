import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/modes/ascii_mode.dart';
import 'package:naga/modes/cga_mode.dart';
import 'package:naga/modes/classic_mode.dart';
import 'package:naga/modes/dungeon_mode.dart';
import 'package:naga/modes/fangs_mode.dart';
import 'package:naga/modes/game_mode.dart';
import 'package:naga/modes/maze_mode.dart';
import 'package:naga/modes/multiplayer_mode.dart';
import 'package:naga/modes/nibbles_mode.dart';
import 'package:naga/modes/pit_mode.dart';
import 'package:naga/modes/rush_mode.dart';
import 'package:naga/modes/snake2_mode.dart';
import 'package:naga/modes/swarm_mode.dart';
import 'package:naga/modes/trail_mode.dart';
import 'package:naga/modes/venom_mode.dart';
import 'package:naga/modes/vs_ai_mode.dart';
import 'package:naga/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every grid mode, landscape to portrait: a rotation mid-game.
  final List<GameMode> modes = [
    ClassicMode(), MazeMode(), TrailMode(), SwarmMode(), RushMode(),
    FangsMode(), VenomMode(), PitMode(), Snake2Mode(), AsciiMode(),
    CgaMode(), NibblesMode(), MultiplayerMode(), DungeonMode(), VsAiMode(),
  ];

  for (final mode in modes) {
    test('${mode.name} re-fits its board after a resize', () async {
      final game = GameRegistry.create(
        mode: mode,
        settings: const GameSettings(),
        onGameOver: () {},
        onVictory: () {},
        onScoreChanged: (_) {},
      ).game;
      game.onGameResize(Vector2(900, 500));
      await game.onLoad();
      // Let child components finish their own async loads (the maze layout).
      await Future<void>.delayed(Duration.zero);
      final dynamic grid = game;
      final double before = grid.cellSize;

      game.onGameResize(Vector2(390, 700));
      final double after = grid.cellSize;
      final Vector2 offset = grid.boardOffset;
      // The grids are taller than wide, so the cell size changes (it grows
      // here); a centered board that fits has non-negative offsets.
      expect(after, isNot(before));
      expect(offset.x, greaterThanOrEqualTo(0));
      expect(offset.y, greaterThanOrEqualTo(0));

      // Cached layers must follow the new layout rather than throw or stale.
      final recorder = ui.PictureRecorder();
      game.render(ui.Canvas(recorder));
      recorder.endRecording().dispose();
    });
  }
}
