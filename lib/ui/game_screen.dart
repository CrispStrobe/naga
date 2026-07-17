import 'dart:math' show Random;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/snake_game.dart';
import '../game/maze_hunter_game.dart';
import '../game/trail_game.dart' as trail;
import '../game/swarm_game.dart';
import '../game/rush_game.dart';
import '../game/fangs_game.dart';
import '../game/venom_game.dart';
import '../game/pit_game.dart';
import '../game/snake2_game.dart';
import '../game/ascii_game.dart';
import '../game/cga_game.dart';
import '../game/nibbles_game.dart';
import '../game/multiplayer_game.dart';
import '../game/dungeon_game.dart';
import '../game/vs_ai_game.dart';
import '../game/stampede_game.dart';
import '../game/naga_dive_game.dart';
import '../components/snake_ai.dart' show AiDifficulty;
import '../modes/game_mode.dart';
import '../modes/maze_mode.dart';
import '../modes/trail_mode.dart';
import '../modes/classic_mode.dart';
import '../modes/swarm_mode.dart';
import '../modes/rush_mode.dart';
import '../modes/fangs_mode.dart';
import '../modes/venom_mode.dart';
import '../modes/pit_mode.dart';
import '../modes/snake2_mode.dart';
import '../modes/ascii_mode.dart';
import '../modes/cga_mode.dart';
import '../modes/nibbles_mode.dart';
import '../modes/multiplayer_mode.dart';
import '../modes/dungeon_mode.dart';
import '../modes/vs_ai_mode.dart';
import '../modes/stampede_mode.dart';
import '../modes/naga_dive_mode.dart';
import '../generated/l10n.dart';
import '../services/settings_service.dart';
import '../services/high_score_service.dart';
import '../services/audio_service.dart';

class GameScreen extends StatefulWidget {
  final GameMode mode;
  final SettingsService settingsService;
  final HighScoreService highScoreService;
  final AudioService audioService;

  const GameScreen({
    super.key,
    required this.mode,
    required this.settingsService,
    required this.highScoreService,
    required this.audioService,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late FlameGame _game;
  final ValueNotifier<int> _scoreNotifier = ValueNotifier<int>(0);
  int _livesRemaining = 0;
  bool _isGameOver = false;
  bool _isNewHighScore = false;
  bool _isPaused = false;
  late bool _useButtons;
  int _quipIndex = 0;
  int _overlayFocus = 0; // 0 = play again, 1 = back to menu

  bool get _isMazeMode => widget.mode is MazeMode;
  bool get _isTrailMode => widget.mode is TrailMode;
  bool get _isClassicMode => widget.mode is ClassicMode;
  bool get _isSwarmMode => widget.mode is SwarmMode;
  bool get _isRushMode => widget.mode is RushMode;
  bool get _isFangsMode => widget.mode is FangsMode;
  bool get _isVenomMode => widget.mode is VenomMode;
  bool get _isPitMode => widget.mode is PitMode;
  bool get _isSnake2Mode => widget.mode is Snake2Mode;
  bool get _isAsciiMode => widget.mode is AsciiMode;
  bool get _isCgaMode => widget.mode is CgaMode;
  bool get _isNibblesMode => widget.mode is NibblesMode;
  bool get _isMultiplayerMode => widget.mode is MultiplayerMode;
  bool get _isDungeonMode => widget.mode is DungeonMode;
  bool get _isVsAiMode => widget.mode is VsAiMode;
  bool get _isStampedeMode => widget.mode is StampedeMode;
  bool get _isNagaDiveMode => widget.mode is NagaDiveMode;

  GameSettings get _settings => widget.settingsService.settings;

  @override
  void initState() {
    super.initState();
    _livesRemaining = _isClassicMode ? 0 : _settings.lives;
    _useButtons = _settings.controlType == ControlType.buttons;
    _createGame();
    widget.audioService.playMusicForMode(widget.mode.name);
  }

  @override
  void dispose() {
    _scoreNotifier.dispose();
    widget.audioService.stopMusic();
    super.dispose();
  }

  void _createGame() {
    if (_isMazeMode) {
      _game = MazeHunterGame(
        mode: widget.mode as MazeMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isTrailMode) {
      _game = trail.TrailGame(
        mode: widget.mode as TrailMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isSwarmMode) {
      _game = SwarmGame(
        mode: widget.mode as SwarmMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isRushMode) {
      _game = RushGame(
        mode: widget.mode as RushMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isFangsMode) {
      _game = FangsGame(
        mode: widget.mode as FangsMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isVenomMode) {
      _game = VenomGame(
        mode: widget.mode as VenomMode,
        onGameOver: _handleDeath,
        onWin: () => _onGameOver(victory: true),
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isPitMode) {
      _game = PitGame(
        mode: widget.mode as PitMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isSnake2Mode) {
      _game = Snake2Game(
        mode: widget.mode as Snake2Mode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
        gridWidth: _settings.gridSize.width,
        gridHeight: _settings.gridSize.height,
        startSpeed: _settings.startSpeed.baseInterval,
      );
    } else if (_isAsciiMode) {
      _game = AsciiGame(
        mode: widget.mode as AsciiMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
        gridWidth: _settings.gridSize.width,
        gridHeight: _settings.gridSize.height,
        startSpeed: _settings.startSpeed.baseInterval,
      );
    } else if (_isCgaMode) {
      _game = CgaGame(
        mode: widget.mode as CgaMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
        gridWidth: _settings.gridSize.width,
        gridHeight: _settings.gridSize.height,
        startSpeed: _settings.startSpeed.baseInterval,
      );
    } else if (_isNibblesMode) {
      _game = NibblesGame(
        mode: widget.mode as NibblesMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
        gridWidth: _settings.gridSize.width,
        gridHeight: _settings.gridSize.height,
        startSpeed: _settings.startSpeed.baseInterval,
      );
    } else if (_isMultiplayerMode) {
      _game = MultiplayerGame(
        mode: widget.mode as MultiplayerMode,
        onGameOver: _handleDeath,
        onP1ScoreChanged: (score) => _scoreNotifier.value = score,
        onP2ScoreChanged: (_) {},
      );
    } else if (_isDungeonMode) {
      _game = DungeonGame(
        mode: widget.mode as DungeonMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isStampedeMode) {
      _game = StampedeGame(
        mode: widget.mode as StampedeMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isNagaDiveMode) {
      _game = NagaDiveGame(
        mode: widget.mode as NagaDiveMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
      );
    } else if (_isVsAiMode) {
      _game = VsAiGame(
        mode: widget.mode as VsAiMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
        aiDifficulty: AiDifficulty.values.byName(_settings.difficulty.name),
        splitArena: widget.mode is VsAiSplitMode,
      );
    } else {
      // Classic: always walls kill. Zen: always wrap. Others: use settings.
      final bool? wallsOverride;
      if (_isClassicMode) {
        wallsOverride = null; // use mode default (true)
      } else if (widget.mode.name == 'Zen') {
        wallsOverride = false; // Zen never kills on walls
      } else {
        wallsOverride = _settings.wallBehavior == WallBehavior.die;
      }

      _game = SnakeGame(
        mode: widget.mode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => _scoreNotifier.value = score,
        gridWidth: _isClassicMode ? null : _settings.gridSize.width,
        gridHeight: _isClassicMode ? null : _settings.gridSize.height,
        wallsKillOverride: wallsOverride,
        speedOverride: _isClassicMode ? null : _settings.startSpeed.baseInterval,
      );
    }
  }

  void _handleDeath() {
    if (!_isClassicMode && _livesRemaining > 0) {
      setState(() => _livesRemaining--);
      // Respawn — keep score and remaining lives
      if (_isSnake2Mode) {
        (_game as Snake2Game).respawn();
      } else if (_isAsciiMode) {
        (_game as AsciiGame).respawn();
      } else if (_isCgaMode) {
        (_game as CgaGame).respawn();
      } else if (_isNibblesMode) {
        (_game as NibblesGame).respawn();
      } else if (!_isMazeMode && !_isTrailMode) {
        (_game as SnakeGame).respawn();
      }
      // Maze and Trail modes: for now just treat as game over
      // (respawn can be added to those game classes later)
      else {
        _onGameOver();
      }
    } else {
      _onGameOver();
    }
  }

  void _togglePause() {
    if (_isGameOver) return;
    // Only SnakeGame has togglePause — other modes just freeze the FlameGame
    if (!_isMazeMode && !_isTrailMode && !_isSwarmMode && !_isRushMode &&
        !_isFangsMode && !_isVenomMode && !_isPitMode && !_isSnake2Mode &&
        !_isAsciiMode && !_isCgaMode && !_isNibblesMode && !_isMultiplayerMode &&
        !_isStampedeMode && !_isNagaDiveMode) {
      (_game as SnakeGame).togglePause();
    } else {
      // For other game types, pause/resume the Flame engine
      if (_isPaused) {
        _game.resumeEngine();
      } else {
        _game.pauseEngine();
      }
    }
    setState(() => _isPaused = !_isPaused);
  }

  void _showInstructions() {
    // Pause the game while showing instructions
    if (!_isPaused && !_isGameOver) _togglePause();

    final modeName = widget.mode.name;
    final instructions = _getInstructions(modeName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(modeName),
        content: Text(instructions),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (_isPaused && !_isGameOver) _togglePause();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getInstructions(String modeName) {
    switch (modeName) {
      case 'Classic':
        return 'The original snake game.\n\n'
            'Eat food to grow longer. Don\'t hit the walls or yourself.\n'
            'No extra lives. How long can you survive?';
      case 'Arcade':
        return 'Fast-paced snake action.\n\n'
            'Eat food, collect power-ups, and rack up points.\n'
            'Power-ups: Speed, Shield, Magnet, Slow, Shrink.';
      case 'Zen':
        return 'Relaxed snake — no walls kill you.\n\n'
            'Walls wrap around. Just eat and grow at your own pace.';
      case 'Maze Hunter':
        return 'Navigate through maze corridors.\n\n'
            'Eat all food to complete each level. Watch out for dead ends!';
      case 'Trail':
        return 'Your trail is your weapon.\n\n'
            'Leave a trail behind you. Enemies that cross it are destroyed.';
      case 'Fangs':
        return 'Breakout meets Snake!\n\n'
            'Your snake is the paddle. Bounce the ball to break blocks.\n'
            'Move fast — the snake is quick in this mode!';
      case 'Venom':
        return 'Bomberman meets Snake!\n\n'
            'Drop venom bombs from your tail: press SPACE, the BOMB button,\n'
            'or simply TAP the board when using swipe controls.\n'
            'After 3 seconds the venom bursts in a circular cloud that\n'
            'destroys walls and enemies. Chain reactions possible!\n'
            'Destroyed walls may drop food — eat it to grow.\n'
            'A longer snake carries more bombs, but is easier to blast.\n'
            'Clear all enemies to advance. Survive all 5 levels to WIN!\n'
            'Don\'t get caught in your own venom.';
      case 'Swarm':
        return 'Space Invaders meets Snake!\n\n'
            'Enemies march down in formation. Eat them by approaching from the SIDES.\n'
            '⚠ Enemies have spikes on top and bottom — vertical contact is deadly!\n'
            'Clear all enemies to advance. Snake resets to bottom each wave.';
      case 'Rush':
        return 'Endless runner!\n\n'
            'Obstacles scroll down toward you. Dodge them and collect food.\n'
            'Wrap around left/right edges. Speed increases over time.';
      case 'Pit':
        return 'Eat or be eaten!\n\n'
            'Enemies roam the pit. Eat them head-on to score.\n'
            'Touching an enemy with your body is deadly.';
      case 'Dungeon':
        return 'Turn-based roguelike!\n\n'
            'Move with arrow keys or swipes — each step is one turn.\n'
            'Monsters move after you. Bumping one costs 1 HP unless armed.\n'
            'SPACE, the SHOOT button, or a TAP fires an arrow (needs arrows).\n\n'
            '🟡 Coin = points\n'
            '🔴 Potion = +1 HP (length)\n'
            '⚔️ Sword (blue) = 3 free bump-kills\n'
            '🏹 Bow (purple) = 3 arrows, shoot from afar\n'
            '🔨 Hammer (grey) = smash through 2 walls\n'
            '🛡️ Shield (silver) = absorbs 2 hits\n'
            '👾 Monsters: red grunt, orange runner (fast), purple brute (2 HP)\n'
            '⭐ Trap = active every 6th turn\n'
            '🚪 Exit = opens when all monsters dead';
      case 'Snake II':
        return 'Nokia Snake II style.\n\n'
            'Classic gameplay with configurable grid, speed, and wall behavior.';
      case 'ASCII':
        return 'Text-mode snake.\n\n'
            'Retro ASCII art style. Same classic gameplay.';
      case 'CGA':
        return 'CGA graphics throwback.\n\n'
            '4-color palette with scanline effects. Pure nostalgia.';
      case 'Nibbles':
        return 'QBasic NIBBLES.BAS!\n\n'
            'Faithful recreation of the classic QBasic snake game.';
      case 'Duel':
        return 'Local 2-player!\n\n'
            'Player 1: Arrow keys. Player 2: WASD.\n'
            'Eat food to grow. Last snake standing wins!';
      case 'VS AI':
        return 'Battle the AI!\n\n'
            'Compete against a computer-controlled snake.\n'
            'AI difficulty adapts to your settings.';
      case 'Stampede':
        return 'Animal race!\n\n'
            'Race down a jungle track against frogs, lizards, beetles and turtles.\n'
            'Use LEFT/RIGHT to switch lanes. Dodge rocks, collect golden stars.\n'
            'Speed increases the further you go!';
      case 'Naga Dive':
        return 'Underwater swim!\n\n'
            'TAP the screen or press SPACE/UP to swim upward.\n'
            'Gravity pulls you down. Navigate through gaps in coral reefs.\n'
            'Collect fish for bonus points. How far can you dive?';
      default:
        return '${widget.mode.description}\n\nUse arrow keys or d-pad to move.';
    }
  }

  void _onGameOver({bool victory = false}) async {
    if (victory) {
      widget.audioService.playLevelUp();
    } else {
      widget.audioService.playDie();
    }
    final isNew = await widget.highScoreService
        .submitScore(widget.mode.name, _scoreNotifier.value);
    setState(() {
      _isGameOver = true;
      _isNewHighScore = isNew;
      _quipIndex = Random().nextInt(8);
      _overlayFocus = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: widget.mode.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildScoreBar(s),
            Expanded(
              child: Stack(
                children: [
                  GameWidget(game: _game),
                  if (!_useButtons && !_isPaused) _buildSwipeControls(),
                  if (_isPaused && !_isGameOver) _buildPauseOverlay(),
                  if (_isGameOver) _buildGameOverOverlay(s),
                ],
              ),
            ),
            if (_useButtons && !_isGameOver) _buildDPad(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBar(S s) {
    final textColor =
        _isClassicMode ? const Color(0xFF0F380F) : Colors.green.shade300;
    final highScore = widget.highScoreService.getHighScore(widget.mode.name);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: widget.mode.backgroundColor,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (!_isClassicMode && _settings.lives > 0) ...[
            const SizedBox(width: 4),
            Text(
              s.livesRemaining(_livesRemaining),
              style: TextStyle(
                fontSize: 12,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ],
          const Spacer(),
          ValueListenableBuilder<int>(
            valueListenable: _scoreNotifier,
            builder: (context, score, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.scoreValue(score),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 2,
                  ),
                ),
                if (highScore > 0)
                  Text(
                    s.highScoreValue(highScore),
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          // Info button
          IconButton(
            icon: Icon(Icons.info_outline, color: textColor, size: 20),
            onPressed: _showInstructions,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Pause button
          IconButton(
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: textColor,
              size: 22,
            ),
            onPressed: _togglePause,
          ),
        ],
      ),
    );
  }

  void _changeDirection(Direction dir) {
    if (_isMazeMode) {
      (_game as MazeHunterGame).changeDirection(dir);
    } else if (_isTrailMode) {
      (_game as trail.TrailGame).changeDirection(
        trail.Direction.values.byName(dir.name),
      );
    } else if (_isSwarmMode) {
      (_game as SwarmGame).changeDirection(dir);
    } else if (_isRushMode) {
      (_game as RushGame).changeDirection(dir);
    } else if (_isFangsMode) {
      (_game as FangsGame).changeDirection(dir);
    } else if (_isVenomMode) {
      (_game as VenomGame).changeDirection(dir);
    } else if (_isPitMode) {
      (_game as PitGame).changeDirection(dir);
    } else if (_isSnake2Mode) {
      (_game as Snake2Game).changeDirection(dir);
    } else if (_isAsciiMode) {
      (_game as AsciiGame).changeDirection(dir);
    } else if (_isCgaMode) {
      (_game as CgaGame).changeDirection(dir);
    } else if (_isNibblesMode) {
      (_game as NibblesGame).changeDirection(dir);
    } else if (_isMultiplayerMode) {
      (_game as MultiplayerGame).changeDirectionP1(dir);
    } else if (_isDungeonMode) {
      (_game as DungeonGame).changeDirection(dir);
    } else if (_isStampedeMode) {
      (_game as StampedeGame).changeDirection(dir);
    } else if (_isNagaDiveMode) {
      // Naga Dive uses tap/space to flap, not directions
      // But map Up to flap for d-pad support
      if (dir == Direction.up) {
        // Trigger via keyboard handler in game
      }
    } else if (_isVsAiMode) {
      (_game as VsAiGame).changeDirection(dir);
    } else {
      (_game as SnakeGame).changeDirection(dir);
    }
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _togglePause,
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pause_circle_outline,
                    size: 64, color: Colors.green.shade400),
                const SizedBox(height: 16),
                Text(
                  'PAUSED',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade300,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap to resume',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeControls() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Tap = mode action (drop bomb / fire arrow) for swipe players
        onTap: _hasActionButton ? _triggerAction : null,
        onVerticalDragUpdate: (details) {
          if (details.delta.dy < -2) {
            _changeDirection(Direction.up);
          } else if (details.delta.dy > 2) {
            _changeDirection(Direction.down);
          }
        },
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx < -2) {
            _changeDirection(Direction.left);
          } else if (details.delta.dx > 2) {
            _changeDirection(Direction.right);
          }
        },
      ),
    );
  }

  void _triggerAction() {
    if (_isVenomMode) {
      (_game as VenomGame).dropBomb();
    } else if (_isDungeonMode) {
      (_game as DungeonGame).fireArrow();
    }
  }

  bool get _hasActionButton => _isVenomMode || _isDungeonMode;

  String get _actionLabel {
    if (_isVenomMode) return 'BOMB';
    if (_isDungeonMode) return 'SHOOT';
    return '';
  }

  IconData get _actionIcon {
    if (_isVenomMode) return Icons.local_fire_department;
    if (_isDungeonMode) return Icons.gps_fixed;
    return Icons.circle;
  }

  Widget _buildDPad() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      color: widget.mode.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Action button (left side) — only for modes that need it
          SizedBox(
            width: 72,
            child: _hasActionButton
                ? _ActionButton(
                    icon: _actionIcon,
                    label: _actionLabel,
                    onPressed: _triggerAction,
                  )
                : null,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DPadButton(
                icon: Icons.arrow_drop_up,
                onPressed: () => _changeDirection(Direction.up),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DPadButton(
                    icon: Icons.arrow_left,
                    onPressed: () => _changeDirection(Direction.left),
                  ),
                  const SizedBox(width: 48, height: 48),
                  _DPadButton(
                    icon: Icons.arrow_right,
                    onPressed: () => _changeDirection(Direction.right),
                  ),
                ],
              ),
              _DPadButton(
                icon: Icons.arrow_drop_down,
                onPressed: () => _changeDirection(Direction.down),
              ),
            ],
          ),
          const SizedBox(width: 72),
        ],
      ),
    );
  }

  String _getResultText(S s) {
    if (_isVenomMode && (_game as VenomGame).hasWon) {
      return 'YOU WIN!';
    }
    if (_isVsAiMode) {
      final won = (_game as VsAiGame).playerWon;
      return won ? 'YOU WIN!' : s.gameOver;
    }
    if (_isMultiplayerMode) {
      final result = (_game as MultiplayerGame).matchResult;
      if (result == MatchResult.player1Wins) return s.player1Wins;
      if (result == MatchResult.player2Wins) return s.player2Wins;
      if (result == MatchResult.draw) return s.draw;
    }
    return s.gameOver;
  }

  Color _getResultColor() {
    if (_isVenomMode && (_game as VenomGame).hasWon) {
      return Colors.green.shade400;
    }
    if (_isVsAiMode && (_game as VsAiGame).playerWon) {
      return Colors.green.shade400;
    }
    if (_isMultiplayerMode) {
      final result = (_game as MultiplayerGame).matchResult;
      if (result == MatchResult.player1Wins) return widget.mode.snakeColor;
      if (result == MatchResult.player2Wins) return Colors.blue.shade400;
      if (result == MatchResult.draw) return Colors.amber;
    }
    return Colors.red.shade400;
  }

  String _getQuip(S s) {
    final quips = [
      s.gameOverQuip1,
      s.gameOverQuip2,
      s.gameOverQuip3,
      s.gameOverQuip4,
      s.gameOverQuip5,
      s.gameOverQuip6,
      s.gameOverQuip7,
      s.gameOverQuip8,
    ];
    return quips[_quipIndex % quips.length];
  }

  void _playAgain() {
    setState(() {
      _isGameOver = false;
      _isNewHighScore = false;
      _scoreNotifier.value = 0;
      _livesRemaining = _isClassicMode ? 0 : _settings.lives;
      _createGame();
    });
  }

  KeyEventResult _onOverlayKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.tab) {
      setState(() => _overlayFocus = 1 - _overlayFocus);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.select) {
      if (_overlayFocus == 0) {
        _playAgain();
      } else {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildGameOverOverlay(S s) {
    final resultText = _getResultText(s);
    final resultColor = _getResultColor();
    final isLoss = resultText == s.gameOver;
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Focus(
          autofocus: true,
          onKeyEvent: _onOverlayKey,
          child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resultText,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: resultColor,
                  letterSpacing: 4,
                ),
              ),
              if (isLoss) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _getQuip(s),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFFFD740),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${s.score}: ${_scoreNotifier.value}',
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white70,
                ),
              ),
              if (_isNewHighScore) ...[
                const SizedBox(height: 8),
                Text(
                  s.newHighScore,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _overlayFocus == 0
                        ? const Color(0xFFFFD740)
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _playAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                  child: Text(
                    s.playAgain,
                    style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _overlayFocus == 1
                        ? const Color(0xFFFFD740)
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    s.backToMenu,
                    style: TextStyle(
                      color: Colors.green.shade400,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DPadButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _DPadButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Icon(icon, color: Colors.green.shade400, size: 36),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.red.shade300, size: 24),
            Text(
              label,
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
