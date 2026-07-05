import 'package:flame/game.dart';
import 'package:flutter/material.dart';
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
  int _score = 0;
  int _livesRemaining = 0;
  bool _isGameOver = false;
  bool _isNewHighScore = false;
  late bool _useButtons;

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
    widget.audioService.stopMusic();
    super.dispose();
  }

  void _createGame() {
    if (_isMazeMode) {
      _game = MazeHunterGame(
        mode: widget.mode as MazeMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isTrailMode) {
      _game = trail.TrailGame(
        mode: widget.mode as TrailMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isSwarmMode) {
      _game = SwarmGame(
        mode: widget.mode as SwarmMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isRushMode) {
      _game = RushGame(
        mode: widget.mode as RushMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isFangsMode) {
      _game = FangsGame(
        mode: widget.mode as FangsMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isVenomMode) {
      _game = VenomGame(
        mode: widget.mode as VenomMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isPitMode) {
      _game = PitGame(
        mode: widget.mode as PitMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isSnake2Mode) {
      _game = Snake2Game(
        mode: widget.mode as Snake2Mode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isAsciiMode) {
      _game = AsciiGame(
        mode: widget.mode as AsciiMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isCgaMode) {
      _game = CgaGame(
        mode: widget.mode as CgaMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else if (_isNibblesMode) {
      _game = NibblesGame(
        mode: widget.mode as NibblesMode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
      );
    } else {
      final effectiveWallsKill = _isClassicMode
          ? true
          : _settings.wallBehavior == WallBehavior.die;

      _game = SnakeGame(
        mode: widget.mode,
        onGameOver: _handleDeath,
        onScoreChanged: (score) => setState(() => _score = score),
        gridWidth: _isClassicMode ? null : _settings.gridSize.width,
        gridHeight: _isClassicMode ? null : _settings.gridSize.height,
        wallsKillOverride: _isClassicMode ? null : effectiveWallsKill,
      );
    }
  }

  void _handleDeath() {
    if (!_isClassicMode && _livesRemaining > 0) {
      setState(() => _livesRemaining--);
      // Respawn — keep score and remaining lives
      if (!_isMazeMode && !_isTrailMode) {
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

  void _onGameOver() async {
    widget.audioService.playDie();
    final isNew = await widget.highScoreService
        .submitScore(widget.mode.name, _score);
    setState(() {
      _isGameOver = true;
      _isNewHighScore = isNew;
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
                  if (!_useButtons) _buildSwipeControls(),
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.scoreValue(_score),
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
          const Spacer(),
          // Toggle controls button
          IconButton(
            icon: Icon(
              _useButtons ? Icons.swipe : Icons.gamepad,
              color: textColor.withOpacity(0.5),
              size: 20,
            ),
            onPressed: () {
              setState(() => _useButtons = !_useButtons);
              widget.settingsService.setControlType(
                _useButtons ? ControlType.buttons : ControlType.swipe,
              );
            },
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
    } else {
      (_game as SnakeGame).changeDirection(dir);
    }
  }

  Widget _buildSwipeControls() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
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

  Widget _buildDPad() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      color: widget.mode.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 48),
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
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay(S s) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.gameOver,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade400,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${s.score}: $_score',
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
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isGameOver = false;
                    _isNewHighScore = false;
                    _score = 0;
                    _livesRemaining = _isClassicMode ? 0 : _settings.lives;
                    _createGame();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  s.backToMenu,
                  style: TextStyle(
                    color: Colors.green.shade400,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
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
