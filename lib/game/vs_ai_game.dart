import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/snake_ai.dart';
import '../modes/vs_ai_mode.dart';
import 'snake_game.dart' show Direction, GameState;

/// Player vs 1-3 AI snakes — same grid, same food competition.
///
/// Score = player's food count.  Game over when the player dies.
/// Win condition: all AI snakes are dead.
class VsAiGame extends FlameGame with KeyboardEvents {
  final VsAiMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;
  final AiDifficulty aiDifficulty;
  final int aiCount; // 1-3

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
  Direction _nextDirection = Direction.right;

  // AI opponents
  late List<_AiOpponent> _aiOpponents;

  // Food
  late Point<int> _foodPos;

  VsAiGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
    this.aiDifficulty = AiDifficulty.medium,
    this.aiCount = 1,
    int? gridWidth,
    int? gridHeight,
  })  : gridWidth = gridWidth ?? 20,
        gridHeight = gridHeight ?? 28;

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
    _nextDirection = Direction.right;

    // Player starts centre-left
    final px = gridWidth ~/ 4;
    final py = gridHeight ~/ 2;
    playerSegments = [
      Point(px, py),
      Point(px - 1, py),
      Point(px - 2, py),
    ];

    // Spawn AI opponents at different positions
    final spawnConfigs = <(Point<int>, Direction)>[
      (Point((gridWidth * 3) ~/ 4, gridHeight ~/ 2), Direction.left),
      (Point(gridWidth ~/ 2, gridHeight ~/ 4), Direction.down),
      (Point(gridWidth ~/ 2, (gridHeight * 3) ~/ 4), Direction.up),
    ];

    final count = aiCount.clamp(1, 3);
    _aiOpponents = [];
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
        brain: SnakeAI(difficulty: aiDifficulty),
      ));
    }

    _spawnFood();
  }

  void restart() {
    _startNewGame();
    onScoreChanged(0);
  }

  // ------------------------------------------------------------------
  // Food
  // ------------------------------------------------------------------

  void _spawnFood() {
    Point<int> pos;
    int attempts = 0;
    do {
      pos = Point(_random.nextInt(gridWidth), _random.nextInt(gridHeight));
      attempts++;
      if (attempts > 200) break;
    } while (_isOccupied(pos));
    _foodPos = pos;
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
    if (_isOpposite(dir, currentDirection)) return;
    _nextDirection = dir;
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
    for (final ai in _aiOpponents) {
      final otherSnakes = <List<Point<int>>>[playerSegments];
      for (final other in _aiOpponents) {
        if (other != ai) otherSnakes.add(other.segments);
      }
      final chosen = ai.brain.decideDirection(
        ai.segments,
        otherSnakes,
        [_foodPos],
        gridWidth,
        gridHeight,
        mode.wallsKill,
      );
      if (!_isOpposite(chosen, ai.direction)) {
        ai.direction = chosen;
      }
    }

    // --- Player movement ---
    currentDirection = _nextDirection;
    final playerHead = _advance(playerSegments.first, currentDirection);

    // Player death checks
    if (_outOfBounds(playerHead)) {
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
      if (_outOfBounds(newHead)) {
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
      final aiAte = newHead.x == _foodPos.x && newHead.y == _foodPos.y;
      ai.segments.insert(0, newHead);
      if (!aiAte) ai.segments.removeLast();

      if (aiAte && !playerAte) {
        // AI ate the food — respawn (no score for AI)
        _spawnFood();
      }
    }

    for (final ai in deadAi) {
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

  bool _outOfBounds(Point<int> p) {
    return p.x < 0 || p.x >= gridWidth || p.y < 0 || p.y >= gridHeight;
  }

  void _playerDies() {
    playerWon = false;
    gameState = GameState.gameOver;
    onGameOver();
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
    _renderSnake(canvas, playerSegments, mode.snakeColor, currentDirection);
    for (final ai in _aiOpponents) {
      _renderSnake(canvas, ai.segments, ai.color, ai.direction);
    }
    _renderFood(canvas);
    if (gameState == GameState.gameOver) {
      _renderGameOver(canvas);
    }
  }

  void _renderBoard(Canvas canvas) {
    final cs = cellSize;
    final offset = boardOffset;
    final gw = gridWidth;
    final gh = gridHeight;

    final bg = mode.backgroundColor;
    final light = Color.lerp(bg, Colors.white, 0.03)!;
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
      ..color = mode.snakeColor.withOpacity(0.4)
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

  void _renderFood(Canvas canvas) {
    final cs = cellSize;
    final sp = _gridToScreen(_foodPos);
    final x = sp.x;
    final y = sp.y;

    final pulse = 0.85 + 0.15 * sin(_foodPulse * 3);
    final radius = (cs / 2) * 0.55 * pulse;
    final cx = x + cs / 2;
    final cy = y + cs / 2;

    final glowPaint = Paint()
      ..color = mode.foodColor.withOpacity(0.15)
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

  void _renderGameOver(Canvas canvas) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.6);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), overlayPaint);

    final resultText = playerWon ? 'YOU WIN!' : 'GAME OVER';
    final resultColor = playerWon ? mode.snakeColor : Colors.red;

    final textPainter = TextPainter(
      text: TextSpan(
        text: resultText,
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: resultColor,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.x - textPainter.width) / 2, size.y * 0.35),
    );

    final scorePainter = TextPainter(
      text: TextSpan(
        text: 'SCORE: $score',
        style: TextStyle(
          fontSize: 22,
          color: mode.snakeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    scorePainter.layout();
    scorePainter.paint(
      canvas,
      Offset((size.x - scorePainter.width) / 2, size.y * 0.35 + 50),
    );
  }
}

/// Internal representation of one AI-controlled opponent.
class _AiOpponent {
  List<Point<int>> segments;
  Direction direction;
  final Color color;
  final SnakeAI brain;

  _AiOpponent({
    required this.segments,
    required this.direction,
    required this.color,
    required this.brain,
  });
}
