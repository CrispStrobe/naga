import 'shared/direction_buffer.dart';
import 'dart:math';
import 'dart:typed_data';
import 'shared/grid_motion.dart';
import 'shared/grid_snake_body.dart';
import 'shared/cached_text.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/ai_difficulty.dart' show AiDifficulty;
import '../modes/vs_ai_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Player vs 1-3 AI snakes.
///
/// Two variants:
/// - **Shared arena** ([splitArena] = false): everyone competes on the same
///   grid for the same food. The AI actively defends its space and tries to
///   cut across the player's path.
/// - **Split arena** ([splitArena] = true): an impassable vertical divider
///   wall splits the field. The player lives in the left half, the AI
///   snake(s) in the right half, each side with its own food. First to die
///   loses — if the AI crashes in its half, the player wins.
///
/// Score = player's food count.  Game over when the player dies.
/// Win condition: all AI snakes are dead.
class VsAiGame extends FlameGame with KeyboardEvents {
  final VsAiMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;
  final AiDifficulty aiDifficulty;
  final int aiCount; // 1-3
  final bool splitArena;

  late final int gridWidth;
  late final int gridHeight;
  late double cellSize;
  late Vector2 boardOffset;

  // State
  GameState gameState = GameState.playing;
  int score = 0;
  double _tickTimer = 0;
  double _foodPulse = 0;
  final Random _random;

  /// True when the player won (all AI dead).
  bool playerWon = false;

  // Player
  List<Point<int>> playerSegments = GridSnakeBody([]);
  Direction currentDirection = Direction.right;
  final _directionQueue = DirectionBuffer(capacity: _maxQueuedInputs);
  static const int _maxQueuedInputs = 4;

  // AI opponents
  late List<_AiOpponent> _aiOpponents;

  /// Final scores of AI snakes that died this round (color, score) —
  /// kept so the HUD comparison stays visible.
  final List<(Color, int)> _fallenAiScores = [];

  // Food (player food; in split mode it lives in the left half)
  late Point<int> _foodPos;

  // AI-side food (split mode only, lives in the right half)
  Point<int>? _aiFoodPos;

  VsAiGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
    this.aiDifficulty = AiDifficulty.medium,
    this.aiCount = 1,
    this.splitArena = false,
    int? gridWidth,
    int? gridHeight,
    Random? random,
  })  : gridWidth = gridWidth ?? (splitArena ? 21 : 20),
        gridHeight = gridHeight ?? 28,
        _random = random ?? Random();

  /// Detached state for deterministic runtime regression tests and benchmarks.
  @visibleForTesting
  Map<String, Object?> debugSnapshot() {
    List<List<int>> cells(Iterable<Point<int>> body) =>
        [for (final p in body) [p.x, p.y]];
    return {
      'player': cells(playerSegments),
      'direction': currentDirection.name,
      'queue': [for (final d in _directionQueue) d.name],
      'food': [_foodPos.x, _foodPos.y],
      'aiFood': _aiFoodPos == null ? null : [_aiFoodPos!.x, _aiFoodPos!.y],
      'ai': [for (final ai in _aiOpponents) {
        'body': cells(ai.segments), 'direction': ai.direction.name,
        'score': ai.score,
      }],
      'fallen': [for (final entry in _fallenAiScores) entry.$2],
      'score': score, 'state': gameState.name, 'won': playerWon,
    };
  }

  /// Column occupied by the divider wall (split arena only).
  int get _dividerX => gridWidth ~/ 2;

  // Reused across candidates, opponents and ticks. Decisions see one immutable
  // occupancy snapshot; movement below still uses the sequential live bodies.
  late final _AiSearchGrid _search =
      _AiSearchGrid(gridWidth, gridHeight, splitArena);

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  @override
  Color backgroundColor() => mode.backgroundColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _calculateGrid();
    _startNewGame();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Rotation and window resizes must re-fit the board, not just the first
    // layout; this only depends on constructor dimensions.
    _calculateGrid();
  }

  void _calculateGrid() {
    final w = size.x;
    final h = size.y;
    cellSize = min(w / gridWidth, h / gridHeight);
    boardOffset = Vector2(
      (w - cellSize * gridWidth) / 2,
      (h - cellSize * gridHeight) / 2,
    );
  }

  void _startNewGame() {
    score = 0;
    _tickTimer = 0;
    _foodPulse = 0;
    gameState = GameState.playing;
    playerWon = false;
    currentDirection = Direction.right;
    _directionQueue.clear();

    // Player starts centre-left (of its half in split mode)
    final px = splitArena ? _dividerX ~/ 2 : gridWidth ~/ 4;
    final py = gridHeight ~/ 2;
    playerSegments = GridSnakeBody([
      Point(px, py),
      Point(px - 1, py),
      Point(px - 2, py),
    ]);

    // Spawn AI opponents at different positions
    final List<(Point<int>, Direction)> spawnConfigs;
    if (splitArena) {
      // All AI snakes live in the right half.
      final rightMid = _dividerX + 1 + (gridWidth - _dividerX - 1) ~/ 2;
      spawnConfigs = [
        (Point(rightMid, gridHeight ~/ 2), Direction.left),
        (Point(rightMid, gridHeight ~/ 4), Direction.left),
        (Point(rightMid, (gridHeight * 3) ~/ 4), Direction.left),
      ];
    } else {
      spawnConfigs = [
        (Point((gridWidth * 3) ~/ 4, gridHeight ~/ 2), Direction.left),
        (Point(gridWidth ~/ 2, gridHeight ~/ 4), Direction.down),
        (Point(gridWidth ~/ 2, (gridHeight * 3) ~/ 4), Direction.up),
      ];
    }

    final count = aiCount.clamp(1, 3);
    _aiOpponents = [];
    _fallenAiScores.clear();
    for (int i = 0; i < count; i++) {
      final (pos, dir) = spawnConfigs[i];
      final dx = dir == Direction.left
          ? 1
          : (dir == Direction.right ? -1 : 0);
      final dy = dir == Direction.up
          ? 1
          : (dir == Direction.down ? -1 : 0);
      _aiOpponents.add(_AiOpponent(
        segments: GridSnakeBody([
          pos,
          Point(pos.x + dx, pos.y + dy),
          Point(pos.x + dx * 2, pos.y + dy * 2),
        ]),
        direction: dir,
        color: VsAiMode.aiColors[i],
      ));
    }

    _spawnFood();
    if (splitArena) _spawnAiFood();
  }

  void restart() {
    _startNewGame();
    onScoreChanged(0);
  }

  // ------------------------------------------------------------------
  // Food
  // ------------------------------------------------------------------

  void _spawnFood() {
    _foodPos = _randomFreeCell(
      minX: 0,
      maxX: splitArena ? _dividerX - 1 : gridWidth - 1,
    );
  }

  void _spawnAiFood() {
    _aiFoodPos = _randomFreeCell(minX: _dividerX + 1, maxX: gridWidth - 1);
  }

  Point<int> _randomFreeCell({required int minX, required int maxX}) {
    Point<int> pos;
    int attempts = 0;
    do {
      pos = Point(
        minX + _random.nextInt(maxX - minX + 1),
        _random.nextInt(gridHeight),
      );
      attempts++;
      if (attempts > 200) break;
    } while (_isOccupied(pos));
    return pos;
  }

  bool _isOccupied(Point<int> p) {
    if (playerSegments.contains(p)) return true;
    for (final ai in _aiOpponents) {
      if (ai.segments.contains(p)) return true;
    }
    return false;
  }

  // ------------------------------------------------------------------
  // Direction (public API for external controls)
  // ------------------------------------------------------------------

  void changeDirection(Direction dir) {
    if (_directionQueue.enqueue(dir, currentDirection) ==
        DirectionInput.rejected) {
      return;
    }
    _maybeEarlyTick();
  }

  bool _isOpposite(Direction a, Direction b) {
    return (a == Direction.up && b == Direction.down) ||
        (a == Direction.down && b == Direction.up) ||
        (a == Direction.left && b == Direction.right) ||
        (a == Direction.right && b == Direction.left);
  }

  void _maybeEarlyTick() {
    final interval = mode.tickInterval(score);
    if (_tickTimer > interval * 0.4) {
      _tickTimer = interval;
    }
  }

  // ------------------------------------------------------------------
  // Keyboard
  // ------------------------------------------------------------------

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.keyP) {
      if (gameState == GameState.playing) {
        gameState = GameState.paused;
      } else if (gameState == GameState.paused) {
        gameState = GameState.playing;
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyW) {
      changeDirection(Direction.up);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.keyS) {
      changeDirection(Direction.down);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyA) {
      changeDirection(Direction.left);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyD) {
      changeDirection(Direction.right);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------------
  // Update / Tick
  // ------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    if (gameState != GameState.playing) return;

    _foodPulse += dt;
    _tickTimer += dt;
    final interval = mode.tickInterval(score);
    if (_tickTimer >= interval) {
      _tickTimer = 0;
      _tick();
    }
  }

  void _tick() {
    // --- AI decisions (before movement) ---
    final upcomingDir =
        _directionQueue.isNotEmpty ? _directionQueue.first : currentDirection;
    final playerNext = _advance(playerSegments.first, upcomingDir);

    _search.clearOccupancy();
    _search.occupy(playerSegments);
    for (final ai in _aiOpponents) {
      _search.occupy(ai.segments);
    }

    // Baseline of the player's reachable space (for offensive squeeze moves).
    int basePlayerSpace = 0;
    if (!splitArena) {
      basePlayerSpace = _search.floodFill(
        playerNext, free: playerSegments.last,
      );
    }

    for (final ai in _aiOpponents) {
      final food = splitArena ? _aiFoodPos : _foodPos;
      final chosen = _decideAiDirection(
        ai,
        food,
        playerNext,
        upcomingDir,
        basePlayerSpace,
      );
      if (!_isOpposite(chosen, ai.direction)) {
        ai.direction = chosen;
      }
    }

    // --- Player movement ---
    currentDirection = _directionQueue.consume(currentDirection);
    final playerHead = _advance(playerSegments.first, currentDirection);

    // Player death checks
    if (_isWall(playerHead)) {
      _playerDies();
      return;
    }
    if (playerSegments.contains(playerHead)) {
      _playerDies();
      return;
    }
    for (final ai in _aiOpponents) {
      if (ai.segments.contains(playerHead)) {
        _playerDies();
        return;
      }
    }

    // Move player
    final playerAte =
        playerHead.x == _foodPos.x && playerHead.y == _foodPos.y;
    playerSegments.insert(0, playerHead);
    if (!playerAte) playerSegments.removeLast();
    if (playerAte) {
      score += mode.pointsPerFood(score);
      onScoreChanged(score);
    }

    // --- AI movement ---
    final deadAi = <_AiOpponent>[];
    for (final ai in _aiOpponents) {
      final newHead = _advance(ai.segments.first, ai.direction);

      // AI death checks
      if (_isWall(newHead)) {
        deadAi.add(ai);
        continue;
      }
      if (ai.segments.contains(newHead)) {
        deadAi.add(ai);
        continue;
      }
      if (playerSegments.contains(newHead)) {
        deadAi.add(ai);
        continue;
      }
      // Head-to-head with player
      if (newHead.x == playerHead.x && newHead.y == playerHead.y) {
        deadAi.add(ai);
        continue;
      }
      // Collision with other AI
      bool hitOther = false;
      for (final other in _aiOpponents) {
        if (other == ai) continue;
        if (other.segments.contains(newHead)) {
          hitOther = true;
          break;
        }
      }
      if (hitOther) {
        deadAi.add(ai);
        continue;
      }

      // Move AI
      final aiFood = splitArena ? _aiFoodPos : _foodPos;
      final aiAte =
          aiFood != null && newHead.x == aiFood.x && newHead.y == aiFood.y;
      ai.segments.insert(0, newHead);
      if (!aiAte) ai.segments.removeLast();

      if (aiAte) {
        ai.score += mode.pointsPerFood(ai.score);
        if (splitArena) {
          _spawnAiFood();
        } else if (!playerAte) {
          // AI ate the food — respawn
          _spawnFood();
        }
      }
    }

    for (final ai in deadAi) {
      _fallenAiScores.add((ai.color, ai.score));
      _aiOpponents.remove(ai);
    }

    // Respawn food if player ate it (after AI processing)
    if (playerAte) {
      _spawnFood();
    }

    // Win condition
    if (_aiOpponents.isEmpty) {
      playerWon = true;
      gameState = GameState.gameOver;
      onGameOver();
    }
  }

  Point<int> _advance(Point<int> head, Direction dir) {
    return gridStep(head, dir);
  }

  /// True if [p] is outside the grid or on the divider wall (split arena).
  bool _isWall(Point<int> p) {
    if (p.x < 0 || p.x >= gridWidth || p.y < 0 || p.y >= gridHeight) {
      return true;
    }
    if (splitArena && p.x == _dividerX) return true;
    return false;
  }

  void _playerDies() {
    playerWon = false;
    gameState = GameState.gameOver;
    onGameOver();
  }

  // ------------------------------------------------------------------
  // AI brain — flood-fill survival + food seeking + path cutting
  // ------------------------------------------------------------------

  /// Chance the AI plays a random (but non-suicidal) move instead of the
  /// best one — keeps it beatable.
  double get _mistakeChance {
    switch (aiDifficulty) {
      case AiDifficulty.easy:
        return 0.22;
      case AiDifficulty.medium:
        return 0.12;
      case AiDifficulty.hard:
        return 0.06;
      case AiDifficulty.expert:
        return 0.03;
    }
  }

  /// How aggressively the AI tries to squeeze the player's space.
  double get _offenseWeight {
    switch (aiDifficulty) {
      case AiDifficulty.easy:
        return 0.0;
      case AiDifficulty.medium:
        return 0.5;
      case AiDifficulty.hard:
        return 1.0;
      case AiDifficulty.expert:
        return 1.5;
    }
  }

  Direction _decideAiDirection(
    _AiOpponent ai,
    Point<int>? food,
    Point<int> playerNext,
    Direction playerDir,
    int basePlayerSpace,
  ) {
    final head = ai.segments.first;
    final ownLength = ai.segments.length;
    final playerHead = playerSegments.first;

    Direction? bestDir;
    double bestScore = double.negativeInfinity;
    // Directions that don't lead into a pocket smaller than the snake —
    // candidates for the occasional deliberate "mistake".
    final survivors = <Direction>[];

    for (final d in Direction.values) {
      if (_isOpposite(d, ai.direction)) continue;
      final next = _advance(head, d);

      // Instantly lethal moves are never taken.
      if (_isWall(next) || _search.isOccupied(next)) continue;

      double score = 0;

      // --- Survival: flood-fill reachable space from the candidate cell.
      // Own tail moves away next tick, so treat it as free.
      final space = _search.floodFill(next, free: ai.segments.last);
      score += min(space, 80) * 3.0;
      if (space < ownLength + 2) {
        // Pocket smaller than own body — near-certain death.
        score -= 600;
      } else {
        survivors.add(d);
      }

      // --- Avoid head-on collisions with the player's likely next cell
      // (a contested cell always kills the AI).
      if (next == playerNext) {
        score -= 500;
      } else if ((next.x - playerHead.x).abs() +
              (next.y - playerHead.y).abs() ==
          1) {
        // Adjacent to the player's head: they might turn into us.
        score -= 90;
      }

      // --- Base drive: seek food via BFS distance.
      if (food != null) {
        final dist = _search.distance(next, food, free: ai.segments.last);
        if (dist >= 0) {
          score += (100 - dist * 3).clamp(0, 100).toDouble();
        } else {
          score -= 40;
        }
      }

      // --- Offense (shared arena only): squeeze the player's reachable
      // space and cut across their path — but never at the cost of our
      // own breathing room.
      if (!splitArena &&
          _offenseWeight > 0 &&
          space >= ownLength + 6 &&
          next != playerNext) {
        if (basePlayerSpace > 0) {
          final pSpace = _search.floodFill(
            playerNext, free: playerSegments.last, extra: next,
          );
          final squeeze = (basePlayerSpace - pSpace).toDouble();
          if (squeeze > 0) {
            score += _offenseWeight * min(squeeze, 40) * 4;
          }
        }
        // Bonus for claiming a cell 2-4 steps ahead of the player's head.
        if (_cutsPlayerPath(next, playerHead, playerDir)) {
          score += _offenseWeight * 30;
        }
      }

      // Small jitter so play doesn't look robotic.
      score += _random.nextDouble() * 6;

      if (score > bestScore) {
        bestScore = score;
        bestDir = d;
      }
    }

    if (bestDir == null) return ai.direction; // boxed in — doomed
    if (survivors.length > 1 && _random.nextDouble() < _mistakeChance) {
      return survivors[_random.nextInt(survivors.length)];
    }
    return bestDir;
  }

  /// True if [cell] lies 2-4 steps directly ahead of the player's head
  /// along [playerDir] — occupying it cuts across the player's path.
  bool _cutsPlayerPath(
      Point<int> cell, Point<int> playerHead, Direction playerDir) {
    var probe = playerHead;
    for (int i = 0; i < 4; i++) {
      probe = _advance(probe, playerDir);
      if (i >= 1 && probe.x == cell.x && probe.y == cell.y) return true;
    }
    return false;
  }

  // ------------------------------------------------------------------
  // Rendering
  // ------------------------------------------------------------------

  Vector2 _gridToScreen(Point<int> pos) {
    return Vector2(
      boardOffset.x + pos.x * cellSize,
      boardOffset.y + pos.y * cellSize,
    );
  }

  final _aiScoreTexts = CachedTextList();

  @override
  void onRemove() {
    _aiScoreTexts.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderBoard(canvas);
    if (splitArena) _renderDivider(canvas);
    _renderSnake(canvas, playerSegments, mode.snakeColor, currentDirection);
    for (final ai in _aiOpponents) {
      _renderSnake(canvas, ai.segments, ai.color, ai.direction);
    }
    _renderFood(canvas, _foodPos);
    if (splitArena && _aiFoodPos != null) {
      _renderFood(canvas, _aiFoodPos!);
    }
    _renderAiScores(canvas);
  }

  /// Draws each AI snake's score as a compact pill near the top of the
  /// board (dead AIs stay visible, dimmed), colored per snake so the
  /// player can compare against their own score in the app's score bar.
  final Paint _pillPaint = Paint();

  void _renderAiScores(Canvas canvas) {
    final entries = <(Color, int, bool)>[
      for (final ai in _aiOpponents) (ai.color, ai.score, true),
      for (final (color, aiScore) in _fallenAiScores)
        (color, aiScore, false),
    ];
    if (entries.isEmpty) return;

    double x = boardOffset.x + cellSize * 0.4;
    final y = boardOffset.y + cellSize * 0.3;

    var slot = 0;
    for (final (color, aiScore, alive) in entries) {
      final textPainter = _aiScoreTexts[slot++].painter(
        'AI: $aiScore',
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: alive ? color : color.withValues(alpha: 0.5),
        ),
      );

      // Dark pill behind the text so every AI color reads on the bright
      // river-blue board.
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, textPainter.width + 14, textPainter.height + 6),
        const Radius.circular(10),
      );
      _pillPaint.color = Colors.black.withValues(alpha: alive ? 0.45 : 0.25);
      canvas.drawRRect(pill, _pillPaint);
      textPainter.paint(canvas, Offset(x + 7, y + 3));
      x += pill.width + 8;
    }
  }

  void _renderBoard(Canvas canvas) {
    final cs = cellSize;
    final offset = boardOffset;
    final gw = gridWidth;
    final gh = gridHeight;

    final bg = mode.backgroundColor;
    final light = Color.lerp(bg, Colors.white, 0.05)!;
    final lightPaint = Paint()..color = light;
    final darkPaint = Paint()..color = bg;

    for (int y = 0; y < gh; y++) {
      for (int x = 0; x < gw; x++) {
        final isLight = (x + y) % 2 == 0;
        final rect = Rect.fromLTWH(
          offset.x + x * cs,
          offset.y + y * cs,
          cs,
          cs,
        );
        canvas.drawRect(rect, isLight ? lightPaint : darkPaint);
      }
    }

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.x, offset.y, cs * gw, cs * gh),
        const Radius.circular(4),
      ),
      borderPaint,
    );
  }

  /// Draws the impassable divider wall down the middle (split arena).
  void _renderDivider(Canvas canvas) {
    final cs = cellSize;
    final x = boardOffset.x + _dividerX * cs;
    final rect = Rect.fromLTWH(x, boardOffset.y, cs, cs * gridHeight);

    // Deep-blue wall column, clearly darker than the river background.
    final wallPaint = Paint()..color = const Color(0xFF01579B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(cs * 0.08),
        Radius.circular(cs * 0.25),
      ),
      wallPaint,
    );

    // Light edge highlight so the wall pops on the bright board.
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(cs * 0.08),
        Radius.circular(cs * 0.25),
      ),
      edgePaint,
    );

    // Bamboo-style segment notches.
    final notchPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 2;
    for (int y = 2; y < gridHeight; y += 3) {
      final ny = boardOffset.y + y * cs;
      canvas.drawLine(
        Offset(x + cs * 0.18, ny),
        Offset(x + cs * 0.82, ny),
        notchPaint,
      );
    }
  }

  void _renderSnake(
    Canvas canvas,
    List<Point<int>> segments,
    Color color,
    Direction headDirection,
  ) {
    if (segments.isEmpty) return;
    final cs = cellSize;
    final paint = Paint()..color = color;
    final darkerPaint = Paint()
      ..color = Color.lerp(color, Colors.black, 0.2)!;

    for (int i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i];
      final sp = _gridToScreen(seg);
      final cx = sp.x + cs / 2;
      final cy = sp.y + cs / 2;

      if (i == 0) {
        _drawHead(canvas, segments, cx, cy, cs, paint, darkerPaint,
            headDirection);
      } else if (i == segments.length - 1) {
        _drawTail(canvas, segments, i, cx, cy, cs, paint);
      } else {
        _drawBody(canvas, segments, i, cx, cy, cs, paint, darkerPaint);
      }
    }
  }

  void _drawHead(
    Canvas canvas,
    List<Point<int>> segments,
    double cx,
    double cy,
    double cs,
    Paint paint,
    Paint darkerPaint,
    Direction direction,
  ) {
    final radius = cs * 0.45;
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    if (segments.length > 1) {
      final next = segments[1];
      final head = segments[0];
      final dx = head.x - next.x;
      final dy = head.y - next.y;
      final extendX = cx - dx * cs * 0.3;
      final extendY = cy - dy * cs * 0.3;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset((cx + extendX) / 2, (cy + extendY) / 2),
          width: dx != 0 ? cs * 0.6 : cs * 0.9,
          height: dy != 0 ? cs * 0.6 : cs * 0.9,
        ),
        paint,
      );
    }

    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;
    final eyeR = cs * 0.13;
    final pupilR = cs * 0.07;

    double e1x, e1y, e2x, e2y;
    double px1, py1, px2, py2;
    switch (direction) {
      case Direction.right:
        e1x = cx + cs * 0.12; e1y = cy - cs * 0.14;
        e2x = cx + cs * 0.12; e2y = cy + cs * 0.14;
        px1 = e1x + cs * 0.04; py1 = e1y;
        px2 = e2x + cs * 0.04; py2 = e2y;
      case Direction.left:
        e1x = cx - cs * 0.12; e1y = cy - cs * 0.14;
        e2x = cx - cs * 0.12; e2y = cy + cs * 0.14;
        px1 = e1x - cs * 0.04; py1 = e1y;
        px2 = e2x - cs * 0.04; py2 = e2y;
      case Direction.up:
        e1x = cx - cs * 0.14; e1y = cy - cs * 0.12;
        e2x = cx + cs * 0.14; e2y = cy - cs * 0.12;
        px1 = e1x; py1 = e1y - cs * 0.04;
        px2 = e2x; py2 = e2y - cs * 0.04;
      case Direction.down:
        e1x = cx - cs * 0.14; e1y = cy + cs * 0.12;
        e2x = cx + cs * 0.14; e2y = cy + cs * 0.12;
        px1 = e1x; py1 = e1y + cs * 0.04;
        px2 = e2x; py2 = e2y + cs * 0.04;
    }

    canvas.drawCircle(Offset(e1x, e1y), eyeR, eyePaint);
    canvas.drawCircle(Offset(e2x, e2y), eyeR, eyePaint);
    canvas.drawCircle(Offset(px1, py1), pupilR, pupilPaint);
    canvas.drawCircle(Offset(px2, py2), pupilR, pupilPaint);
  }

  void _drawBody(
    Canvas canvas,
    List<Point<int>> segments,
    int i,
    double cx,
    double cy,
    double cs,
    Paint paint,
    Paint darkerPaint,
  ) {
    final prev = segments[i - 1];
    final curr = segments[i];
    final next = segments[i + 1];

    final dxPrev = curr.x - prev.x;
    final dyPrev = curr.y - prev.y;
    final dxNext = next.x - curr.x;
    final dyNext = next.y - curr.y;

    final isStraight = (dxPrev == dxNext && dyPrev == dyNext);
    final bodyWidth = cs * 0.88;

    if (isStraight) {
      final isHorizontal = dyPrev == 0;
      if (isHorizontal) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, cy), width: cs, height: bodyWidth),
            Radius.circular(cs * 0.08),
          ),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, cy), width: bodyWidth, height: cs),
            Radius.circular(cs * 0.08),
          ),
          paint,
        );
      }
    } else {
      if (dxPrev != 0) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, cy), width: cs, height: bodyWidth),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, cy), width: bodyWidth, height: cs),
          paint,
        );
      }
      if (dxNext != 0) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, cy), width: cs, height: bodyWidth),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, cy), width: bodyWidth, height: cs),
          paint,
        );
      }
      final halfBody = bodyWidth / 2;
      canvas.drawCircle(Offset(cx, cy), halfBody, paint);
    }

    canvas.drawCircle(Offset(cx, cy), cs * 0.12, darkerPaint);
  }

  void _drawTail(
    Canvas canvas,
    List<Point<int>> segments,
    int i,
    double cx,
    double cy,
    double cs,
    Paint paint,
  ) {
    final prev = segments[i - 1];
    final curr = segments[i];
    final dx = prev.x - curr.x;
    final dy = prev.y - curr.y;

    final tipX = cx - dx * cs * 0.4;
    final tipY = cy - dy * cs * 0.4;

    final path = Path();
    if (dx != 0) {
      path.moveTo(cx + dx * cs * 0.3, cy - cs * 0.4);
      path.lineTo(cx + dx * cs * 0.3, cy + cs * 0.4);
      path.lineTo(tipX, tipY);
      path.close();
    } else {
      path.moveTo(cx - cs * 0.4, cy + dy * cs * 0.3);
      path.lineTo(cx + cs * 0.4, cy + dy * cs * 0.3);
      path.lineTo(tipX, tipY);
      path.close();
    }
    canvas.drawPath(path, paint);

    final bodyWidth = cs * 0.88;
    if (dx != 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + dx * cs * 0.15, cy),
            width: cs * 0.5,
            height: bodyWidth,
          ),
          Radius.circular(cs * 0.08),
        ),
        paint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy + dy * cs * 0.15),
            width: bodyWidth,
            height: cs * 0.5,
          ),
          Radius.circular(cs * 0.08),
        ),
        paint,
      );
    }
  }

  void _renderFood(Canvas canvas, Point<int> foodPos) {
    final cs = cellSize;
    final sp = _gridToScreen(foodPos);
    final x = sp.x;
    final y = sp.y;

    final pulse = 0.85 + 0.15 * sin(_foodPulse * 3);
    final radius = (cs / 2) * 0.55 * pulse;
    final cx = x + cs / 2;
    final cy = y + cs / 2;

    final glowPaint = Paint()
      ..color = mode.foodColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cx, cy), radius * 1.8, glowPaint);

    final paint = Paint()..color = mode.foodColor;
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawCircle(
      Offset(cx - radius * 0.25, cy - radius * 0.25),
      radius * 0.3,
      highlightPaint,
    );
  }
}

/// Allocation-free searches over the decision-time board. A padded wall border
/// makes neighbor lookup safe without allocating Points or checking coordinates
/// in the inner loop. Each cell is enqueued at most once per search.
class _AiSearchGrid {
  final int width;
  final int height;
  final int stride;
  final Uint8List _walls;
  final Uint8List _occupied;
  final Uint32List _visited;
  final Int32List _queue;
  final Int32List _distance;
  late final List<int> _offsets = [-stride, stride, -1, 1];
  int _epoch = 0;

  _AiSearchGrid(this.width, this.height, bool split)
      : stride = width + 2,
        _walls = Uint8List((width + 2) * (height + 2)),
        _occupied = Uint8List((width + 2) * (height + 2)),
        _visited = Uint32List((width + 2) * (height + 2)),
        _queue = Int32List((width + 2) * (height + 2)),
        _distance = Int32List((width + 2) * (height + 2)) {
    _walls.fillRange(0, _walls.length, 1);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!split || x != width ~/ 2) _walls[(y + 1) * stride + x + 1] = 0;
      }
    }
  }

  int _cell(Point<int> p) =>
      p.x < 0 || p.x >= width || p.y < 0 || p.y >= height
          ? 0 // guaranteed sentinel wall
          : (p.y + 1) * stride + p.x + 1;

  void clearOccupancy() => _occupied.fillRange(0, _occupied.length, 0);

  void occupy(Iterable<Point<int>> body) {
    for (final cell in body) {
      _occupied[_cell(cell)] = 1;
    }
  }

  bool isOccupied(Point<int> p) => _occupied[_cell(p)] != 0;

  int _nextEpoch() {
    // Keep stamps valid on both the VM and JS typed arrays after long sessions.
    if (_epoch == 0xffffffff) {
      _visited.fillRange(0, _visited.length, 0);
      _epoch = 0;
    }
    return ++_epoch;
  }

  bool _blocked(int cell, int free, int extra) =>
      _walls[cell] != 0 || cell == extra ||
      (_occupied[cell] != 0 && cell != free);

  // The old Set.remove(tail) frees that cell even when bodies overlap. Preserve
  // that behavior; 'extra' wins over 'free', like remove(tail)..add(candidate).
  int floodFill(Point<int> start, {required Point<int> free, Point<int>? extra}) {
    final first = _cell(start);
    final freeCell = _cell(free);
    final extraCell = extra == null ? -1 : _cell(extra);
    if (_blocked(first, freeCell, extraCell)) return 0;
    final epoch = _nextEpoch();
    var read = 0;
    var write = 1;
    _queue[0] = first;
    _visited[first] = epoch;
    while (read < write) {
      final cell = _queue[read++];
      // Only the capped connected-component size affects scoring, not traversal
      // order: FIFO and the old DFS return exactly min(component size, 300).
      if (read == 300) return 300;
      for (final offset in _offsets) {
        final next = cell + offset;
        if (_visited[next] == epoch || _blocked(next, freeCell, extraCell)) {
          continue;
        }
        _visited[next] = epoch;
        _queue[write++] = next;
      }
    }
    return read;
  }

  int distance(Point<int> start, Point<int> target, {required Point<int> free}) {
    if (start == target) return 0;
    final first = _cell(start);
    final goal = _cell(target);
    final freeCell = _cell(free);
    if (_walls[first] != 0 || _blocked(goal, freeCell, -1)) return -1;
    final epoch = _nextEpoch();
    var read = 0;
    var write = 1;
    _queue[0] = first;
    _visited[first] = epoch;
    _distance[first] = 0;
    while (read < write) {
      final cell = _queue[read++];
      final distance = _distance[cell] + 1;
      for (final offset in _offsets) {
        final next = cell + offset;
        if (_visited[next] == epoch || _blocked(next, freeCell, -1)) continue;
        if (next == goal) return distance;
        _visited[next] = epoch;
        _distance[next] = distance;
        _queue[write++] = next;
      }
    }
    return -1;
  }
}

/// Internal representation of one AI-controlled opponent.
class _AiOpponent {
  List<Point<int>> segments;
  Direction direction;
  final Color color;

  /// Points this AI has gathered from food (shown in the HUD).
  int score = 0;

  _AiOpponent({
    required this.segments,
    required this.direction,
    required this.color,
  });
}
