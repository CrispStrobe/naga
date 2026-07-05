import 'dart:collection';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/snake_ai.dart' show AiDifficulty;
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
  final Random _random = Random();

  /// True when the player won (all AI dead).
  bool playerWon = false;

  // Player
  List<Point<int>> playerSegments = [];
  Direction currentDirection = Direction.right;
  final Queue<Direction> _directionQueue = Queue<Direction>();
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
  })  : gridWidth = gridWidth ?? (splitArena ? 21 : 20),
        gridHeight = gridHeight ?? 28;

  /// Column occupied by the divider wall (split arena only).
  int get _dividerX => gridWidth ~/ 2;

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
    playerSegments = [
      Point(px, py),
      Point(px - 1, py),
      Point(px - 2, py),
    ];

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
        segments: [
          pos,
          Point(pos.x + dx, pos.y + dy),
          Point(pos.x + dx * 2, pos.y + dy * 2),
        ],
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
    if (playerSegments.any((s) => s.x == p.x && s.y == p.y)) return true;
    for (final ai in _aiOpponents) {
      if (ai.segments.any((s) => s.x == p.x && s.y == p.y)) return true;
    }
    return false;
  }

  // ------------------------------------------------------------------
  // Direction (public API for external controls)
  // ------------------------------------------------------------------

  void changeDirection(Direction dir) {
    final lastDir = _directionQueue.isNotEmpty
        ? _directionQueue.last
        : currentDirection;
    if (_isOpposite(dir, lastDir)) return;
    if (dir == lastDir) return;
    if (_directionQueue.length < _maxQueuedInputs) {
      _directionQueue.add(dir);
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

    final allOccupied = <Point<int>>{
      ...playerSegments,
      for (final ai in _aiOpponents) ...ai.segments,
    };

    // Baseline of the player's reachable space (for offensive squeeze moves).
    int basePlayerSpace = 0;
    if (!splitArena) {
      final blocked = Set<Point<int>>.from(allOccupied)
        ..remove(playerSegments.last);
      basePlayerSpace = _floodFill(playerNext, blocked);
    }

    for (final ai in _aiOpponents) {
      final food = splitArena ? _aiFoodPos : _foodPos;
      final chosen = _decideAiDirection(
        ai,
        food,
        allOccupied,
        playerNext,
        upcomingDir,
        basePlayerSpace,
      );
      if (!_isOpposite(chosen, ai.direction)) {
        ai.direction = chosen;
      }
    }

    // --- Player movement ---
    if (_directionQueue.isNotEmpty) {
      currentDirection = _directionQueue.removeFirst();
    }
    final playerHead = _advance(playerSegments.first, currentDirection);

    // Player death checks
    if (_isWall(playerHead)) {
      _playerDies();
      return;
    }
    if (playerSegments.any((s) => s.x == playerHead.x && s.y == playerHead.y)) {
      _playerDies();
      return;
    }
    for (final ai in _aiOpponents) {
      if (ai.segments.any((s) => s.x == playerHead.x && s.y == playerHead.y)) {
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
      if (ai.segments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
        deadAi.add(ai);
        continue;
      }
      if (playerSegments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
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
        if (other.segments.any((s) => s.x == newHead.x && s.y == newHead.y)) {
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
    switch (dir) {
      case Direction.up:
        return Point(head.x, head.y - 1);
      case Direction.down:
        return Point(head.x, head.y + 1);
      case Direction.left:
        return Point(head.x - 1, head.y);
      case Direction.right:
        return Point(head.x + 1, head.y);
    }
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
    Set<Point<int>> allOccupied,
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
      if (_isWall(next) || allOccupied.contains(next)) continue;

      double score = 0;

      // --- Survival: flood-fill reachable space from the candidate cell.
      // Own tail moves away next tick, so treat it as free.
      final blocked = Set<Point<int>>.from(allOccupied)
        ..remove(ai.segments.last);
      final space = _floodFill(next, blocked);
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
        final dist = _bfsDistance(next, food, blocked);
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
          final pBlocked = Set<Point<int>>.from(allOccupied)
            ..remove(playerSegments.last)
            ..add(next);
          final pSpace = _floodFill(playerNext, pBlocked);
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

  /// Count of free cells reachable from [start] ([blocked] and walls are
  /// impassable). Capped — the grid is small, this runs per candidate
  /// direction per tick.
  int _floodFill(Point<int> start, Set<Point<int>> blocked, {int cap = 300}) {
    if (_isWall(start) || blocked.contains(start)) return 0;
    final visited = <int>{};
    final stack = <Point<int>>[start];
    int count = 0;
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final key = p.x * 1000 + p.y;
      if (visited.contains(key)) continue;
      if (_isWall(p) || blocked.contains(p)) continue;
      visited.add(key);
      count++;
      if (count >= cap) return count;
      stack.add(Point(p.x + 1, p.y));
      stack.add(Point(p.x - 1, p.y));
      stack.add(Point(p.x, p.y + 1));
      stack.add(Point(p.x, p.y - 1));
    }
    return count;
  }

  /// BFS shortest-path distance from [start] to [target], or -1 if
  /// unreachable. Walls (incl. the divider) and [blocked] are impassable.
  int _bfsDistance(
      Point<int> start, Point<int> target, Set<Point<int>> blocked) {
    if (start.x == target.x && start.y == target.y) return 0;
    final visited = <int>{start.x * 1000 + start.y};
    final queue = Queue<(Point<int>, int)>()..add((start, 0));
    while (queue.isNotEmpty) {
      final (p, dist) = queue.removeFirst();
      for (final d in Direction.values) {
        final next = _advance(p, d);
        if (_isWall(next) || blocked.contains(next)) continue;
        if (next.x == target.x && next.y == target.y) return dist + 1;
        final key = next.x * 1000 + next.y;
        if (visited.contains(key)) continue;
        visited.add(key);
        queue.add((next, dist + 1));
      }
    }
    return -1;
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
  void _renderAiScores(Canvas canvas) {
    final entries = <(Color, int, bool)>[
      for (final ai in _aiOpponents) (ai.color, ai.score, true),
      for (final (color, aiScore) in _fallenAiScores)
        (color, aiScore, false),
    ];
    if (entries.isEmpty) return;

    double x = boardOffset.x + cellSize * 0.4;
    final y = boardOffset.y + cellSize * 0.3;

    for (final (color, aiScore, alive) in entries) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'AI: $aiScore',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: alive ? color : color.withOpacity(0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Dark pill behind the text so every AI color reads on the bright
      // river-blue board.
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, textPainter.width + 14, textPainter.height + 6),
        const Radius.circular(10),
      );
      canvas.drawRRect(
        pill,
        Paint()..color = Colors.black.withOpacity(alive ? 0.45 : 0.25),
      );
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
      ..color = Colors.white.withOpacity(0.5)
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
      ..color = Colors.white.withOpacity(0.35)
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
      ..color = Colors.white.withOpacity(0.25)
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
      ..color = mode.foodColor.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cx, cy), radius * 1.8, glowPaint);

    final paint = Paint()..color = mode.foodColor;
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4);
    canvas.drawCircle(
      Offset(cx - radius * 0.25, cy - radius * 0.25),
      radius * 0.3,
      highlightPaint,
    );
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
