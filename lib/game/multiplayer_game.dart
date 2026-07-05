import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modes/multiplayer_mode.dart';
import 'snake_game.dart' show Direction;

/// Result of the multiplayer match.
enum MatchResult { player1Wins, player2Wins, draw }

/// A self-contained 2-player local multiplayer snake game.
///
/// Both snakes share the same grid and compete for the same food.
/// Collision with the other snake's body kills the collider.
/// The game ends when at least one player dies.
class MultiplayerGame extends FlameGame with KeyboardEvents {
  final MultiplayerMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onP1ScoreChanged;
  final ValueChanged<int> onP2ScoreChanged;

  // Grid
  late final int gridWidth;
  late final int gridHeight;
  late double cellSize;
  late Vector2 boardOffset;

  // State
  bool _isGameOver = false;
  MatchResult? matchResult;
  int p1Score = 0;
  int p2Score = 0;
  double _tickTimer = 0;
  final Random _random = Random();

  // Player 1
  List<Point<int>> _p1Segments = [];
  Direction _p1Direction = Direction.right;
  Direction _p1NextDirection = Direction.right;
  bool p1Alive = true;

  // Player 2
  List<Point<int>> _p2Segments = [];
  Direction _p2Direction = Direction.left;
  Direction _p2NextDirection = Direction.left;
  bool p2Alive = true;

  // Food
  late Point<int> _foodPos;
  double _foodPulse = 0;

  MultiplayerGame({
    required this.mode,
    required this.onGameOver,
    required this.onP1ScoreChanged,
    required this.onP2ScoreChanged,
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
    final availableWidth = size.x;
    final availableHeight = size.y;
    cellSize = min(availableWidth / gridWidth, availableHeight / gridHeight);
    final boardWidth = cellSize * gridWidth;
    final boardHeight = cellSize * gridHeight;
    boardOffset = Vector2(
      (availableWidth - boardWidth) / 2,
      (availableHeight - boardHeight) / 2,
    );
  }

  void _startNewGame() {
    p1Score = 0;
    p2Score = 0;
    _tickTimer = 0;
    _isGameOver = false;
    matchResult = null;
    p1Alive = true;
    p2Alive = true;

    // Player 1 starts left side going right
    final p1X = gridWidth ~/ 4;
    final p1Y = gridHeight ~/ 2;
    _p1Segments = [
      Point(p1X, p1Y),
      Point(p1X - 1, p1Y),
      Point(p1X - 2, p1Y),
    ];
    _p1Direction = Direction.right;
    _p1NextDirection = Direction.right;

    // Player 2 starts right side going left
    final p2X = (gridWidth * 3) ~/ 4;
    final p2Y = gridHeight ~/ 2;
    _p2Segments = [
      Point(p2X, p2Y),
      Point(p2X + 1, p2Y),
      Point(p2X + 2, p2Y),
    ];
    _p2Direction = Direction.left;
    _p2NextDirection = Direction.left;

    _spawnFood();
  }

  void restart() {
    _startNewGame();
    onP1ScoreChanged(0);
    onP2ScoreChanged(0);
  }

  // ------------------------------------------------------------------
  // Food
  // ------------------------------------------------------------------

  void _spawnFood() {
    Point<int> pos;
    do {
      pos = Point(_random.nextInt(gridWidth), _random.nextInt(gridHeight));
    } while (_occupies(pos, _p1Segments) || _occupies(pos, _p2Segments));
    _foodPos = pos;
  }

  bool _occupies(Point<int> pos, List<Point<int>> segs) {
    return segs.any((s) => s.x == pos.x && s.y == pos.y);
  }

  // ------------------------------------------------------------------
  // Direction changes (public API for external controls)
  // ------------------------------------------------------------------

  void changeDirectionP1(Direction dir) {
    if (_isOpposite(dir, _p1Direction)) return;
    _p1NextDirection = dir;
    _maybeEarlyTick();
  }

  void changeDirectionP2(Direction dir) {
    if (_isOpposite(dir, _p2Direction)) return;
    _p2NextDirection = dir;
    _maybeEarlyTick();
  }

  bool _isOpposite(Direction a, Direction b) {
    return (a == Direction.up && b == Direction.down) ||
        (a == Direction.down && b == Direction.up) ||
        (a == Direction.left && b == Direction.right) ||
        (a == Direction.right && b == Direction.left);
  }

  void _maybeEarlyTick() {
    final interval = mode.tickInterval(max(p1Score, p2Score));
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

    // Player 1: WASD
    if (event.logicalKey == LogicalKeyboardKey.keyW) {
      changeDirectionP1(Direction.up);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      changeDirectionP1(Direction.down);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      changeDirectionP1(Direction.left);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyD) {
      changeDirectionP1(Direction.right);
      return KeyEventResult.handled;
    }

    // Player 2: Arrow keys
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      changeDirectionP2(Direction.up);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      changeDirectionP2(Direction.down);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      changeDirectionP2(Direction.left);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      changeDirectionP2(Direction.right);
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
    if (_isGameOver) return;

    _foodPulse += dt;
    _tickTimer += dt;
    final interval = mode.tickInterval(max(p1Score, p2Score));
    if (_tickTimer >= interval) {
      _tickTimer = 0;
      _tick();
    }
  }

  void _tick() {
    _p1Direction = _p1NextDirection;
    _p2Direction = _p2NextDirection;

    final p1NewHead = _advance(_p1Segments.first, _p1Direction);
    final p2NewHead = _advance(_p2Segments.first, _p2Direction);

    // Check deaths
    bool p1Dies = false;
    bool p2Dies = false;

    // Wall collision
    if (_outOfBounds(p1NewHead)) p1Dies = true;
    if (_outOfBounds(p2NewHead)) p2Dies = true;

    // Self collision
    if (!p1Dies && _occupies(p1NewHead, _p1Segments)) p1Dies = true;
    if (!p2Dies && _occupies(p2NewHead, _p2Segments)) p2Dies = true;

    // Head-to-head collision
    if (!p1Dies && !p2Dies && p1NewHead.x == p2NewHead.x && p1NewHead.y == p2NewHead.y) {
      p1Dies = true;
      p2Dies = true;
    }

    // Collision with other snake's body
    if (!p1Dies && _occupies(p1NewHead, _p2Segments)) p1Dies = true;
    if (!p2Dies && _occupies(p2NewHead, _p1Segments)) p2Dies = true;

    if (p1Dies || p2Dies) {
      p1Alive = !p1Dies;
      p2Alive = !p2Dies;
      if (p1Dies && p2Dies) {
        matchResult = MatchResult.draw;
      } else if (p1Dies) {
        matchResult = MatchResult.player2Wins;
      } else {
        matchResult = MatchResult.player1Wins;
      }
      _isGameOver = true;
      onGameOver();
      return;
    }

    // Check food
    final p1Ate =
        p1NewHead.x == _foodPos.x && p1NewHead.y == _foodPos.y;
    final p2Ate =
        p2NewHead.x == _foodPos.x && p2NewHead.y == _foodPos.y;

    // Move snakes
    _p1Segments.insert(0, p1NewHead);
    if (!p1Ate) _p1Segments.removeLast();

    _p2Segments.insert(0, p2NewHead);
    if (!p2Ate) _p2Segments.removeLast();

    // Score & respawn food
    if (p1Ate || p2Ate) {
      if (p1Ate) {
        p1Score += mode.pointsPerFood(p1Score);
        onP1ScoreChanged(p1Score);
      }
      if (p2Ate) {
        p2Score += mode.pointsPerFood(p2Score);
        onP2ScoreChanged(p2Score);
      }
      _spawnFood();
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
    _renderSnake(canvas, _p1Segments, mode.snakeColor, _p1Direction);
    _renderSnake(canvas, _p2Segments, mode.player2Color, _p2Direction);
    _renderFood(canvas);
    if (_isGameOver) {
      _renderGameOver(canvas);
    }
  }

  void _renderBoard(Canvas canvas) {
    final cs = cellSize;
    final offset = boardOffset;
    final gw = gridWidth;
    final gh = gridHeight;

    // Checkerboard
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

    // Border
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
    final darkerPaint = Paint()..color = Color.lerp(color, Colors.black, 0.2)!;

    for (int i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i];
      final sp = _gridToScreen(seg);
      final cx = sp.x + cs / 2;
      final cy = sp.y + cs / 2;

      if (i == 0) {
        _drawHead(canvas, segments, cx, cy, cs, paint, darkerPaint, headDirection);
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

    // Extend body backward
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

    // Eyes
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
            Rect.fromCenter(center: Offset(cx, cy), width: cs, height: bodyWidth),
            Radius.circular(cs * 0.08),
          ),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: bodyWidth, height: cs),
            Radius.circular(cs * 0.08),
          ),
          paint,
        );
      }
    } else {
      if (dxPrev != 0) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: cs, height: bodyWidth),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: bodyWidth, height: cs),
          paint,
        );
      }
      if (dxNext != 0) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: cs, height: bodyWidth),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: bodyWidth, height: cs),
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

    // Glow
    final glowPaint = Paint()
      ..color = mode.foodColor.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cx, cy), radius * 1.8, glowPaint);

    // Main body
    final paint = Paint()..color = mode.foodColor;
    canvas.drawCircle(Offset(cx, cy), radius, paint);

    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4);
    canvas.drawCircle(
      Offset(cx - radius * 0.25, cy - radius * 0.25),
      radius * 0.3,
      highlightPaint,
    );
  }

  void _renderGameOver(Canvas canvas) {
    // Semi-transparent overlay
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.6);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      overlayPaint,
    );

    // Winner text
    String resultText;
    Color resultColor;
    switch (matchResult!) {
      case MatchResult.player1Wins:
        resultText = 'PLAYER 1 WINS!';
        resultColor = mode.snakeColor;
      case MatchResult.player2Wins:
        resultText = 'PLAYER 2 WINS!';
        resultColor = mode.player2Color;
      case MatchResult.draw:
        resultText = 'DRAW!';
        resultColor = Colors.amber;
    }

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
      Offset(
        (size.x - textPainter.width) / 2,
        size.y * 0.35,
      ),
    );

    // Scores
    final scorePainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'P1: $p1Score',
            style: TextStyle(
              fontSize: 22,
              color: mode.snakeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const TextSpan(
            text: '    ',
            style: TextStyle(fontSize: 22),
          ),
          TextSpan(
            text: 'P2: $p2Score',
            style: TextStyle(
              fontSize: 22,
              color: mode.player2Color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    scorePainter.layout();
    scorePainter.paint(
      canvas,
      Offset(
        (size.x - scorePainter.width) / 2,
        size.y * 0.35 + 50,
      ),
    );
  }
}
