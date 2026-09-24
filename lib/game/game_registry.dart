import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import '../modes/ai_difficulty.dart' show AiDifficulty;
import '../modes/game_mode.dart';
import '../services/settings_service.dart';
import 'snake_game.dart';
import '../modes/daily_mode.dart';
import '../modes/maze_mode.dart';
import '../modes/trail_mode.dart';
import '../modes/swarm_mode.dart';
import '../modes/rush_mode.dart';
import '../modes/shed_mode.dart';
import '../modes/fangs_mode.dart';
import '../modes/venom_mode.dart';
import '../modes/pit_mode.dart';
import '../modes/snake2_mode.dart';
import '../modes/ascii_mode.dart';
import '../modes/cga_mode.dart';
import '../modes/nibbles_mode.dart';
import '../modes/multiplayer_mode.dart';
import '../modes/dungeon_mode.dart';
import '../modes/stampede_mode.dart';
import '../modes/naga_dive_mode.dart';
import '../modes/vs_ai_mode.dart';
import 'daily_game.dart';
import 'maze_hunter_game.dart';
import 'trail_game.dart' as trail;
import 'swarm_game.dart';
import 'rush_game.dart';
import 'shed_game.dart';
import 'fangs_game.dart';
import 'venom_game.dart';
import 'pit_game.dart';
import 'snake2_game.dart';
import 'ascii_game.dart';
import 'cga_game.dart';
import 'nibbles_game.dart';
import 'multiplayer_game.dart';
import 'dungeon_game.dart';
import 'stampede_game.dart';
import 'naga_dive_game.dart';
import 'vs_ai_game.dart';

enum GameAction { none, bomb, shoot, flap }

enum SessionResult { loss, victory, player1Wins, player2Wins, draw }

/// UI-facing controls captured once, without changing the existing game APIs.
class GameSession {
  final FlameGame game;
  final ValueChanged<Direction> _changeDirection;
  final ValueChanged<bool> setPaused;
  final bool Function() _isPaused;
  final VoidCallback? respawn;
  final ValueChanged<Direction>? _changeSecondaryDirection;
  final GameAction action;
  final VoidCallback? _action;
  final SessionResult Function()? _result;

  const GameSession({
    required this.game,
    required this._changeDirection,
    required this.setPaused,
    required this._isPaused,
    this.respawn,
    this._changeSecondaryDirection,
    this.action = GameAction.none,
    VoidCallback? triggerAction,
    this._result,
  }) : _action = triggerAction;

  void changeDirection(Direction direction) {
    if (!isPaused) _changeDirection(direction);
  }

  ValueChanged<Direction>? get changeSecondaryDirection =>
      _changeSecondaryDirection == null
      ? null
      : _changeSecondaryDirectionIfPlaying;

  void _changeSecondaryDirectionIfPlaying(Direction direction) {
    if (!isPaused) _changeSecondaryDirection?.call(direction);
  }

  SessionResult get result => _result?.call() ?? SessionResult.loss;
  void triggerAction() {
    if (!isPaused) _action?.call();
  }

  bool get canRespawn => respawn != null;
  bool get isPaused => _isPaused();
}

/// The only place that pairs each mode with its concrete game and controls.
/// Type promotion keeps constructor arguments and method tear-offs checked.
abstract final class GameRegistry {
  static GameSession create({
    required GameMode mode,
    required GameSettings settings,
    required VoidCallback onGameOver,
    required ValueChanged<int> onScoreChanged,
    required VoidCallback onVictory,
    ValueChanged<int>? onSecondaryScoreChanged,
  }) {
    if (mode is MazeMode) {
      final game = MazeHunterGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is TrailMode) {
      final game = trail.TrailGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return GameSession(
        game: game,
        changeDirection: (dir) =>
            game.changeDirection(trail.Direction.values.byName(dir.name)),
        isPaused: () => game.gameState == trail.TrailGameState.paused,
        setPaused: (paused) {
          if (game.gameState != trail.TrailGameState.gameOver) {
            game.gameState = paused
                ? trail.TrailGameState.paused
                : trail.TrailGameState.playing;
            paused ? game.pauseEngine() : game.resumeEngine();
          }
        },
      );
    }
    if (mode is SwarmMode) {
      final game = SwarmGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is RushMode) {
      final game = RushGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is ShedMode) {
      final game = ShedGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is FangsMode) {
      final game = FangsGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is VenomMode) {
      final game = VenomGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
        onWin: onVictory,
      );
      return _session(
        game: game,
        action: GameAction.bomb,
        triggerAction: game.dropBomb,
        result: () => game.hasWon ? SessionResult.victory : SessionResult.loss,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is PitMode) {
      final game = PitGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is Snake2Mode) {
      final game = Snake2Game(
        mode: mode,
        onGameOver: onGameOver,
        onVictory: onVictory,
        onScoreChanged: onScoreChanged,
        gridWidth: settings.gridSize.width,
        gridHeight: settings.gridSize.height,
        startSpeed: settings.startSpeed.baseInterval,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
        respawn: game.respawn,
        result: () => game.hasWon ? SessionResult.victory : SessionResult.loss,
      );
    }
    if (mode is AsciiMode) {
      final game = AsciiGame(
        mode: mode,
        onGameOver: onGameOver,
        onVictory: onVictory,
        onScoreChanged: onScoreChanged,
        gridWidth: settings.gridSize.width,
        gridHeight: settings.gridSize.height,
        startSpeed: settings.startSpeed.baseInterval,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
        respawn: game.respawn,
        result: () => game.hasWon ? SessionResult.victory : SessionResult.loss,
      );
    }
    if (mode is CgaMode) {
      final game = CgaGame(
        mode: mode,
        onGameOver: onGameOver,
        onVictory: onVictory,
        onScoreChanged: onScoreChanged,
        gridWidth: settings.gridSize.width,
        gridHeight: settings.gridSize.height,
        startSpeed: settings.startSpeed.baseInterval,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
        respawn: game.respawn,
        result: () => game.hasWon ? SessionResult.victory : SessionResult.loss,
      );
    }
    if (mode is NibblesMode) {
      final game = NibblesGame(
        mode: mode,
        onGameOver: onGameOver,
        onVictory: onVictory,
        onScoreChanged: onScoreChanged,
        gridWidth: settings.gridSize.width,
        gridHeight: settings.gridSize.height,
        startSpeed: settings.startSpeed.baseInterval,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
        respawn: game.respawn,
        result: () => game.hasWon ? SessionResult.victory : SessionResult.loss,
      );
    }
    if (mode is MultiplayerMode) {
      final game = MultiplayerGame(
        mode: mode,
        onGameOver: onGameOver,
        onP1ScoreChanged: onScoreChanged,
        onP2ScoreChanged: onSecondaryScoreChanged ?? (_) {},
      );
      return GameSession(
        game: game,
        changeDirection: game.changeDirectionP1,
        changeSecondaryDirection: game.changeDirectionP2,
        result: () => switch (game.matchResult) {
          MatchResult.player1Wins => SessionResult.player1Wins,
          MatchResult.player2Wins => SessionResult.player2Wins,
          MatchResult.draw => SessionResult.draw,
          null => SessionResult.loss,
        },
        isPaused: () => game.paused,
        setPaused: (paused) =>
            paused ? game.pauseEngine() : game.resumeEngine(),
      );
    }
    if (mode is DungeonMode) {
      final game = DungeonGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return _session(
        game: game,
        action: GameAction.shoot,
        triggerAction: game.fireArrow,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is StampedeMode) {
      final game = StampedeGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is NagaDiveMode) {
      final game = NagaDiveGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      // Adapt the existing public keyboard API; no game API changes needed.
      void flap() => game.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          timeStamp: Duration.zero,
        ),
        {},
      );
      return _session(
        game: game,
        action: GameAction.flap,
        triggerAction: flap,
        changeDirection: (dir) {
          if (dir == Direction.up) flap();
        },
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is VsAiMode) {
      final game = VsAiGame(
        mode: mode,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
        aiDifficulty: AiDifficulty.values.byName(settings.difficulty.name),
        splitArena: mode is VsAiSplitMode,
      );
      return _session(
        game: game,
        result: () =>
            game.playerWon ? SessionResult.victory : SessionResult.loss,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
      );
    }
    if (mode is DailyMode) {
      final game = DailyGame(
        mode: mode,
        onVictory: onVictory,
        onGameOver: onGameOver,
        onScoreChanged: onScoreChanged,
      );
      return _session(
        game: game,
        changeDirection: game.changeDirection,
        state: () => game.gameState,
        setState: (state) => game.gameState = state,
        result: () => game.hasWon ? SessionResult.victory : SessionResult.loss,
      );
    }
    final classic = mode.fixedRules;
    final game = SnakeGame(
      mode: mode,
      onVictory: onVictory,
      onGameOver: onGameOver,
      onScoreChanged: onScoreChanged,
      gridWidth: classic ? null : settings.gridSize.width,
      gridHeight: classic ? null : settings.gridSize.height,
      wallsKillOverride: classic
          ? null
          : mode.name == 'Zen'
          ? false
          : settings.wallBehavior == WallBehavior.die,
      speedOverride: classic ? null : settings.startSpeed.baseInterval,
    );
    return _session(
      game: game,
      changeDirection: game.changeDirection,
      state: () => game.gameState,
      setState: (state) => game.gameState = state,
      respawn: classic ? null : game.respawn,
      result: () => game.hasWon ? SessionResult.victory : SessionResult.loss,
    );
  }

  static GameSession _session({
    required FlameGame game,
    required ValueChanged<Direction> changeDirection,
    required GameState Function() state,
    required ValueChanged<GameState> setState,
    VoidCallback? respawn,
    GameAction action = GameAction.none,
    VoidCallback? triggerAction,
    SessionResult Function()? result,
  }) => GameSession(
    game: game,
    changeDirection: changeDirection,
    respawn: respawn,
    action: action,
    triggerAction: triggerAction,
    result: result,
    isPaused: () => state() == GameState.paused,
    setPaused: (paused) {
      if (state() != GameState.gameOver) {
        setState(paused ? GameState.paused : GameState.playing);
        // State alone does not stop updates to mounted Flame children.
        if (game is! SnakeGame) {
          paused ? game.pauseEngine() : game.resumeEngine();
        }
      }
    },
  );
}
