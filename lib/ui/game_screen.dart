import 'dart:math' show Random;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/daily_service.dart';
import '../modes/daily_mode.dart';
import '../game/game_registry.dart';
import '../game/snake_game.dart' show Direction;
import '../modes/classic_mode.dart';
import '../modes/game_mode.dart';
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

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameSession _session;
  int _sessionGeneration = 0;
  int _backgroundGeneration = 0;
  final FocusNode _gameFocus = FocusNode();
  bool get _inputBlocked => _isPaused || _isGameOver;
  final ValueNotifier<int> _scoreNotifier = ValueNotifier<int>(0);
  int _livesRemaining = 0;
  bool _isGameOver = false;
  bool _isNewHighScore = false;
  bool _isPaused = false;
  late bool _useButtons;
  int _quipIndex = 0;
  int _overlayFocus = 0; // 0 = play again, 1 = back to menu

  bool get _isClassicMode => widget.mode is ClassicMode;

  /// Fixed-rule modes (Classic, Daily) never grant extra lives.
  bool get _fixedRules => widget.mode.fixedRules;

  GameSettings get _settings => widget.settingsService.settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _livesRemaining = _fixedRules ? 0 : _settings.lives;
    _useButtons = _settings.controlType == ControlType.buttons;
    _createGame();
    widget.audioService.playMusicForMode(widget.mode.name);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameFocus.dispose();
    _scoreNotifier.dispose();
    widget.audioService.stopMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the app never resumes a covered match automatically.
    if (state != AppLifecycleState.resumed) {
      _backgroundGeneration++;
      if (!_isPaused && !_isGameOver) _togglePause();
    }
  }

  void _createGame() {
    final generation = ++_sessionGeneration;
    bool isCurrent() => mounted && generation == _sessionGeneration;
    _session = GameRegistry.create(
      mode: widget.mode,
      settings: _settings,
      onGameOver: () {
        if (isCurrent()) _handleDeath();
      },
      onScoreChanged: (score) {
        if (isCurrent()) _scoreNotifier.value = score;
      },
      onVictory: () {
        if (isCurrent()) _onGameOver(victory: true);
      },
    );
    // The screen owns lifecycle pause; Flame otherwise resumes on return.
    _session.game.pauseWhenBackgrounded = false;
  }

  void _handleDeath() {
    if (!_fixedRules && _livesRemaining > 0) {
      setState(() => _livesRemaining--);
      // Respawn — keep score and remaining lives
      if (_session.canRespawn) {
        _session.respawn!();
      } else {
        _onGameOver();
      }
    } else {
      _onGameOver();
    }
  }

  void _togglePause() {
    if (_isGameOver) return;
    // Freeze the session and keep keyboard input out of the covered game.
    _session.setPaused(!_isPaused);
    setState(() => _isPaused = !_isPaused);
    if (!_isPaused) _focusGameAfterFrame();
  }

  void _showInstructions() {
    // Only undo the pause introduced by this dialog, not a user/app pause.
    final resumeOnClose = !_isPaused && !_isGameOver;
    final backgroundGeneration = _backgroundGeneration;
    if (resumeOnClose) _togglePause();

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
              if (mounted &&
                  resumeOnClose &&
                  backgroundGeneration == _backgroundGeneration &&
                  _isPaused &&
                  !_isGameOver) {
                _togglePause();
              }
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
      case 'Daily':
        return 'One board per day, the same for everyone.\n\n'
            'The rocks and the order food appears in come from today\'s date. '
            'Classic rules: walls and rocks kill, no power-ups, no extra lives.\n'
            'Play as often as you like; your best run of the day counts. '
            'Play on consecutive days to build a streak.';
      case 'Shed':
        return 'Tetris meets Snake!\n\n'
            'Each meal grows you by three. Every 4th meal you shed your skin: '
            'everything behind your neck stays behind as solid wall.\n'
            'Fill a whole row with shed skin to clear it for a big bonus. '
            'Lay your body along a row before you shed!';
      case 'Nightfall':
        return 'Snake by lantern light.\n\n'
            'Only the area around your head is lit. Food glimmers like a '
            'firefly in the dark, and the board edge glows faintly.\n'
            'Your lantern dims as your score climbs.';
      case 'Portals':
        return 'Step in here, come out there.\n\n'
            'Enter the cyan or the orange portal and your head comes out of '
            'the other one, still heading the same way.\n'
            'Both portals jump to new places after every meal. '
            'Mind your tail: it may still be passing through.';
      case 'Ouroboros':
        return 'Catch fireflies in a loop.\n\n'
            'The glowing fireflies can\'t be eaten: circle them with your own '
            'body until the loop is closed and everything inside is caught.\n'
            'More fireflies in one loop score far more (1: 10, 2: 40, 3: 90). '
            'Walls don\'t count as part of a loop. Eat fruit to grow longer.';
      case 'Echo':
        return 'Outrun your last run.\n\n'
            'From your second run on, your previous run replays as a ghost '
            'snake, starting a few moves behind you. Touching it is deadly; '
            'it passes through your body harmlessly.\n'
            'Stay alive until your echo fades for a bonus that grows with its length. '
            'Each life leaves an echo for the next one.';
      case 'Territory':
        return 'Claim the jungle.\n\n'
            'Leave your land to draw a trail, then come back: the trail and '
            'everything it seals off become yours.\n'
            'While you are outside, your trail is your weak spot: if a rival '
            'crosses it, you are out. Cross a rival\'s trail to cut them down.\n'
            'Your score is the share of the board you own, in percent. '
            'Own half the board to win.';
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
        return 'Snake II style.\n\n'
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
            'Player 1: WASD. Player 2: Arrow keys.\n'
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
    if (!mounted || _isGameOver) return;
    final session = _session;
    // The result and restart controls must not wait for disk/plugin I/O.
    setState(() {
      _isGameOver = true;
      _isNewHighScore = false;
      _quipIndex = Random().nextInt(8);
      _overlayFocus = 0;
    });
    if (victory) {
      widget.audioService.playLevelUp();
    } else {
      widget.audioService.playDie();
    }
    final mode = widget.mode;
    if (mode is DailyMode) {
      final score = _scoreNotifier.value;
      DailyService.instance()
          .then((daily) => daily.recordRun(mode.day, score))
          .catchError((Object error) {
            debugPrint('Could not save daily result: $error');
            return false;
          });
    }
    try {
      final isNew = await widget.highScoreService.submitScore(
        widget.mode.name,
        _scoreNotifier.value,
      );
      if (!mounted || !identical(session, _session)) return;
      setState(() => _isNewHighScore = isNew);
    } catch (error) {
      // Persistence failure must not break the result screen or escape after
      // disposal. Do not claim a high score that could not be saved.
      debugPrint('Could not save high score: $error');
    }
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
                  ExcludeFocus(
                    excluding: _inputBlocked,
                    child: GameWidget(
                      game: _session.game,
                      focusNode: _gameFocus,
                    ),
                  ),
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
    final textColor = _isClassicMode
        ? const Color(0xFF0F380F)
        : Colors.green.shade300;
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
          if (!_fixedRules && _settings.lives > 0) ...[
            const SizedBox(width: 4),
            Text(
              s.livesRemaining(_livesRemaining),
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.7),
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
                      color: textColor.withValues(alpha: 0.5),
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
    if (!_inputBlocked) _session.changeDirection(dir);
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, _) => KeyEventResult.handled,
        child: GestureDetector(
          onTap: _togglePause,
          child: Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    size: 64,
                    color: Colors.green.shade400,
                  ),
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
    if (!_inputBlocked) _session.triggerAction();
  }

  bool get _hasActionButton =>
      _session.action == GameAction.bomb || _session.action == GameAction.shoot;

  String get _actionLabel => switch (_session.action) {
    GameAction.bomb => 'BOMB',
    GameAction.shoot => 'SHOOT',
    _ => '',
  };

  IconData get _actionIcon => switch (_session.action) {
    GameAction.bomb => Icons.local_fire_department,
    GameAction.shoot => Icons.gps_fixed,
    _ => Icons.circle,
  };

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

  String _getResultText(S s) => switch (_session.result) {
    SessionResult.victory => 'YOU WIN!',
    SessionResult.player1Wins => s.player1Wins,
    SessionResult.player2Wins => s.player2Wins,
    SessionResult.draw => s.draw,
    SessionResult.loss => s.gameOver,
  };

  Color _getResultColor() => switch (_session.result) {
    SessionResult.victory => Colors.green.shade400,
    SessionResult.player1Wins => widget.mode.snakeColor,
    SessionResult.player2Wins => Colors.blue.shade400,
    SessionResult.draw => Colors.amber,
    SessionResult.loss => Colors.red.shade400,
  };

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
      _livesRemaining = _fixedRules ? 0 : _settings.lives;
      _createGame();
    });
    // The overlay held focus (a tapped button or its key handler); without
    // this the new game ignores the keyboard until the board is clicked.
    _focusGameAfterFrame();
  }

  void _focusGameAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_inputBlocked) _gameFocus.requestFocus();
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
                  style: const TextStyle(fontSize: 24, color: Colors.white70),
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
                        horizontal: 32,
                        vertical: 16,
                      ),
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
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.5),
            width: 2,
          ),
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
