import 'package:flame/game.dart';
import 'package:naga/modes/game_mode.dart';
import 'package:naga/modes/arcade_mode.dart';
import 'package:naga/modes/zen_mode.dart';
import 'package:naga/modes/maze_mode.dart';
import 'package:naga/modes/trail_mode.dart';
import 'package:naga/modes/swarm_mode.dart';
import 'package:naga/modes/rush_mode.dart';
import 'package:naga/modes/fangs_mode.dart';
import 'package:naga/modes/venom_mode.dart';
import 'package:naga/modes/pit_mode.dart';
import 'package:naga/modes/snake2_mode.dart';
import 'package:naga/modes/ascii_mode.dart';
import 'package:naga/modes/cga_mode.dart';
import 'package:naga/modes/nibbles_mode.dart';
import 'package:naga/modes/multiplayer_mode.dart';
import 'package:naga/modes/dungeon_mode.dart';
import 'package:naga/modes/stampede_mode.dart';
import 'package:naga/modes/naga_dive_mode.dart';
import 'package:naga/modes/vs_ai_mode.dart';
import 'package:naga/game/maze_hunter_game.dart';
import 'package:naga/game/trail_game.dart' as trail;
import 'package:naga/game/swarm_game.dart';
import 'package:naga/game/rush_game.dart';
import 'package:naga/game/fangs_game.dart';
import 'package:naga/game/venom_game.dart';
import 'package:naga/game/pit_game.dart';
import 'package:naga/game/snake2_game.dart';
import 'package:naga/game/ascii_game.dart';
import 'package:naga/game/cga_game.dart';
import 'package:naga/game/nibbles_game.dart';
import 'package:naga/game/multiplayer_game.dart';
import 'package:naga/game/dungeon_game.dart';
import 'package:naga/game/stampede_game.dart';
import 'package:naga/game/naga_dive_game.dart';
import 'package:naga/game/vs_ai_game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/classic_mode.dart';
import 'package:naga/services/settings_service.dart';

void main() {
  test('Session blocks both direction controls and actions while paused', () {
    var paused = false;
    var directions = 0;
    var secondaryDirections = 0;
    var actions = 0;
    final session = GameSession(
      game: FlameGame(),
      changeDirection: (_) => directions++,
      changeSecondaryDirection: (_) => secondaryDirections++,
      setPaused: (value) => paused = value,
      isPaused: () => paused,
      triggerAction: () => actions++,
    );
    session.setPaused(true);
    session.changeDirection(Direction.up);
    session.changeSecondaryDirection!(Direction.down);
    session.triggerAction();
    expect((directions, secondaryDirections, actions), (0, 0, 0));
    session.setPaused(false);
    session.changeDirection(Direction.up);
    session.changeSecondaryDirection!(Direction.down);
    session.triggerAction();
    expect((directions, secondaryDirections, actions), (1, 1, 1));
  });

  test('Zen always wraps despite die wall setting', () {
    final game = _create(ZenMode()).game as SnakeGame;
    expect(game.wallsKillOverride, false);
  });

  test('Venom victory and action remain separate from death', () async {
    var wins = 0;
    var deaths = 0;
    final session = GameRegistry.create(
      mode: VenomMode(),
      settings: const GameSettings(),
      onScoreChanged: (_) {},
      onGameOver: () => deaths++,
      onVictory: () => wins++,
    );
    final game = session.game as VenomGame;
    game.onGameResize(Vector2(400, 560));
    await game.onLoad();
    expect(session.action, GameAction.bomb);
    session.triggerAction();
    game.update(game.mode.tickInterval(0));
    expect(game.bombsAvailable, lessThan(game.maxBombs));
    expect(session.result, SessionResult.loss);
    game.hasWon = true;
    game.onWin();
    expect(session.result, SessionResult.victory);
    expect(wins, 1);
    expect(deaths, 0);
  });

  test('Dungeon action fires arrows without unsafe screen casts', () async {
    final session = _create(DungeonMode());
    final game = session.game as DungeonGame;
    game.onGameResize(Vector2(400, 560));
    await game.onLoad();
    game.arrows = 3;
    expect(session.action, GameAction.shoot);
    session.triggerAction();
    expect(game.arrows, 2);
  });

  test('Dive touch action and up direction both flap', () {
    final session = _create(NagaDiveMode());
    final game = session.game as NagaDiveGame;
    expect(session.action, GameAction.flap);
    session.triggerAction();
    expect(game.snakeVelocity, NagaDiveGame.flapStrength);
    game.snakeVelocity = 0;
    session.changeDirection(Direction.up);
    expect(game.snakeVelocity, NagaDiveGame.flapStrength);
  });

  test('Duel exposes both players and all result variants', () {
    var p1 = 0;
    var p2 = 0;
    final session = GameRegistry.create(
      mode: MultiplayerMode(),
      settings: const GameSettings(),
      onGameOver: () {},
      onVictory: () {},
      onScoreChanged: (score) => p1 = score,
      onSecondaryScoreChanged: (score) => p2 = score,
    );
    final game = session.game as MultiplayerGame;
    expect(session.changeSecondaryDirection, isNotNull);
    session.changeDirection(Direction.up);
    session.changeSecondaryDirection!(Direction.down);
    game.onP1ScoreChanged(12);
    game.onP2ScoreChanged(34);
    expect((p1, p2), (12, 34));
    for (final entry in {
      MatchResult.player1Wins: SessionResult.player1Wins,
      MatchResult.player2Wins: SessionResult.player2Wins,
      MatchResult.draw: SessionResult.draw,
    }.entries) {
      game.matchResult = entry.key;
      expect(session.result, entry.value);
    }
  });

  test('AI result reads live state for shared and split arenas', () {
    for (final mode in [VsAiMode(), VsAiSplitMode()]) {
      final session = _create(mode);
      final game = session.game as VsAiGame;
      expect(session.result, SessionResult.loss);
      game.playerWon = true;
      expect(session.result, SessionResult.victory);
    }
  });

  test(
    'ClassicMode constructs its specialized game and safe pause controls',
    () {
      final session = GameRegistry.create(
        mode: ClassicMode(),
        settings: const GameSettings(lives: 5),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      expect(session.game, isA<SnakeGame>());
      session.setPaused(true);
      session.setPaused(true);
      expect(session.isPaused, isTrue);
      session.setPaused(false);
      expect(session.isPaused, isFalse);
      expect(session.canRespawn, false);
    },
  );
  test(
    'ArcadeMode constructs its specialized game and safe pause controls',
    () {
      final session = GameRegistry.create(
        mode: ArcadeMode(),
        settings: const GameSettings(lives: 5),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      expect(session.game, isA<SnakeGame>());
      session.setPaused(true);
      session.setPaused(true);
      expect(session.isPaused, isTrue);
      session.setPaused(false);
      expect(session.isPaused, isFalse);
      expect(session.canRespawn, true);
    },
  );
  test('ZenMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: ZenMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<SnakeGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, true);
  });
  test('MazeMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: MazeMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<MazeHunterGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    // HEAD behavior preserved: Maze death is always game over, even with
    // lives remaining (its respawn path leaves ghost vulnerability stale).
    expect(session.canRespawn, false);
  });
  test('TrailMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: TrailMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<trail.TrailGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, false);
  });
  test('SwarmMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: SwarmMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<SwarmGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, false);
  });
  test('RushMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: RushMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<RushGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, false);
  });
  test('FangsMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: FangsMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<FangsGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, false);
  });
  test('VenomMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: VenomMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<VenomGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, false);
  });
  test('PitMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: PitMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<PitGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, false);
  });
  test(
    'Snake2Mode constructs its specialized game and safe pause controls',
    () {
      final session = GameRegistry.create(
        mode: Snake2Mode(),
        settings: const GameSettings(lives: 5),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      expect(session.game, isA<Snake2Game>());
      session.setPaused(true);
      session.setPaused(true);
      expect(session.isPaused, isTrue);
      session.setPaused(false);
      expect(session.isPaused, isFalse);
      expect(session.canRespawn, true);
    },
  );
  test('AsciiMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: AsciiMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<AsciiGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, true);
  });
  test('CgaMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: CgaMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<CgaGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, true);
  });
  test(
    'NibblesMode constructs its specialized game and safe pause controls',
    () {
      final session = GameRegistry.create(
        mode: NibblesMode(),
        settings: const GameSettings(lives: 5),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      expect(session.game, isA<NibblesGame>());
      session.setPaused(true);
      session.setPaused(true);
      expect(session.isPaused, isTrue);
      session.setPaused(false);
      expect(session.isPaused, isFalse);
      expect(session.canRespawn, true);
    },
  );
  test(
    'MultiplayerMode constructs its specialized game and safe pause controls',
    () {
      final session = GameRegistry.create(
        mode: MultiplayerMode(),
        settings: const GameSettings(lives: 5),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      expect(session.game, isA<MultiplayerGame>());
      session.setPaused(true);
      session.setPaused(true);
      expect(session.isPaused, isTrue);
      session.setPaused(false);
      expect(session.isPaused, isFalse);
      expect(session.canRespawn, false);
    },
  );
  test(
    'DungeonMode constructs its specialized game and safe pause controls',
    () {
      final session = GameRegistry.create(
        mode: DungeonMode(),
        settings: const GameSettings(lives: 5),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      expect(session.game, isA<DungeonGame>());
      session.setPaused(true);
      session.setPaused(true);
      expect(session.isPaused, isTrue);
      session.setPaused(false);
      expect(session.isPaused, isFalse);
      expect(session.canRespawn, false);
    },
  );
  test(
    'StampedeMode constructs its specialized game and safe pause controls',
    () {
      final session = GameRegistry.create(
        mode: StampedeMode(),
        settings: const GameSettings(lives: 5),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      expect(session.game, isA<StampedeGame>());
      session.setPaused(true);
      session.setPaused(true);
      expect(session.isPaused, isTrue);
      session.setPaused(false);
      expect(session.isPaused, isFalse);
      expect(session.canRespawn, false);
    },
  );
  test(
    'NagaDiveMode constructs its specialized game and safe pause controls',
    () {
      final session = GameRegistry.create(
        mode: NagaDiveMode(),
        settings: const GameSettings(lives: 5),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      expect(session.game, isA<NagaDiveGame>());
      session.setPaused(true);
      session.setPaused(true);
      expect(session.isPaused, isTrue);
      session.setPaused(false);
      expect(session.isPaused, isFalse);
      expect(session.canRespawn, false);
    },
  );
  test('VsAiMode constructs its specialized game and safe pause controls', () {
    final session = GameRegistry.create(
      mode: VsAiMode(),
      settings: const GameSettings(lives: 5),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    expect(session.game, isA<VsAiGame>());
    session.setPaused(true);
    session.setPaused(true);
    expect(session.isPaused, isTrue);
    session.setPaused(false);
    expect(session.isPaused, isFalse);
    expect(session.canRespawn, false);
  });
  test(
    'VsAiSplitMode constructs its specialized game and safe pause controls',
    () {
      final session = GameRegistry.create(
        mode: VsAiSplitMode(),
        settings: const GameSettings(lives: 5),
        onGameOver: () {},
        onScoreChanged: (_) {},
        onVictory: () {},
      );
      expect(session.game, isA<VsAiGame>());
      session.setPaused(true);
      session.setPaused(true);
      expect(session.isPaused, isTrue);
      session.setPaused(false);
      expect(session.isPaused, isFalse);
      expect(session.canRespawn, false);
    },
  );

  test('Classic registry session preserves its authentic settings', () {
    final session = GameRegistry.create(
      mode: ClassicMode(),
      settings: const GameSettings(
        gridSize: GridSize.large,
        wallBehavior: WallBehavior.wrap,
        startSpeed: StartSpeed.insane,
        lives: 5,
      ),
      onGameOver: () {},
      onScoreChanged: (_) {},
      onVictory: () {},
    );
    final game = session.game as SnakeGame;
    expect(game.gridWidth, 20);
    expect(game.gridHeight, 28);
    expect(game.wallsKillOverride, isNull);
    expect(game.speedOverride, isNull);
    expect(session.canRespawn, isFalse);
    session.setPaused(true);
    expect(game.gameState, GameState.paused);
    session.setPaused(false);
    expect(game.gameState, GameState.playing);
  });
}

GameSession _create(
  GameMode mode, {
  GameSettings settings = const GameSettings(),
}) => GameRegistry.create(
  mode: mode,
  settings: settings,
  onGameOver: () {},
  onScoreChanged: (_) {},
  onVictory: () {},
);
