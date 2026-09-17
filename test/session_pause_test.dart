import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/classic_mode.dart';
import 'package:naga/modes/maze_mode.dart';
import 'package:naga/modes/trail_mode.dart';
import 'package:naga/modes/dungeon_mode.dart';
import 'package:naga/modes/multiplayer_mode.dart';
import 'package:naga/services/settings_service.dart';

class _CountingComponent extends Component {
  int updates = 0;
  @override
  void update(double dt) {
    updates++;
  }
}

void main() {
  for (final mode in [
    MazeMode(),
    TrailMode(),
    DungeonMode(),
    MultiplayerMode(),
  ]) {
    testWidgets('${mode.name} pause freezes mounted Flame children', (
      tester,
    ) async {
      final session = GameRegistry.create(
        mode: mode,
        settings: const GameSettings(),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      final game = session.game;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GameWidget(game: game),
        ),
      );
      await tester.runAsync(() => game.loaded);
      final counter = _CountingComponent();
      game.add(counter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(counter.isMounted, isTrue);
      expect(counter.updates, greaterThan(0));

      session.setPaused(true);
      session.setPaused(true);
      final before = counter.updates;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        counter.updates,
        before,
        reason: 'Child updates must stop, not just the parent game logic',
      );
      expect(game.paused, isTrue);
      expect(session.isPaused, isTrue);

      session.setPaused(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(counter.updates, greaterThan(before));
      expect(game.paused, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  test('Classic pause preserves gameState without pausing the engine', () {
    final session = GameRegistry.create(
      mode: ClassicMode(),
      settings: const GameSettings(),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    final game = session.game as SnakeGame;
    session.setPaused(true);
    expect(game.gameState, GameState.paused);
    expect(game.paused, isFalse);
    session.setPaused(false);
    expect(game.gameState, GameState.playing);
  });
}
