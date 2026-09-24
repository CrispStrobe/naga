import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modes/shed_mode.dart';
import 'shared/cached_text.dart';
import 'shared/direction_buffer.dart';
import 'shared/free_cell.dart';
import 'shared/grid_motion.dart';
import 'shared/grid_snake_body.dart';
import 'snake_game.dart' show Direction, GameState;

/// Shed: every [shedEvery] meals the body behind the neck turns into shed
/// skin, a permanent wall. A row filled entirely with skin clears.
class ShedGame extends FlameGame with KeyboardEvents {
  final ShedMode mode;
  final VoidCallback onGameOver;
  final ValueChanged<int> onScoreChanged;

  static const int gridWidth = 14;
  static const int gridHeight = 22;
  static const int shedEvery = 4;
  static const int growthPerFood = 2;

  /// Head and neck stay alive when the rest is shed.
  static const int keptSegments = 3;

  /// Bonus for rows cleared by one shed: 1, 2, 3, 4+ rows.
  static const List<int> rowBonus = [100, 300, 600, 1000];

  late double cellSize;
  late Vector2 boardOffset;

  List<Point<int>> snakeSegments = GridSnakeBody([]);
  Direction currentDirection = Direction.right;
  final _directionQueue = DirectionBuffer(capacity: 4);
  GameState gameState = GameState.playing;
  int score = 0;
  int rowsCleared = 0;
  double _tickTimer = 0;
  int _pendingGrowth = 0;
  int _mealsSinceShed = 0;
  Point<int>? food;

  final Set<Point<int>> _skin = {};
  final Random _random;

  // Rows that just cleared, flashed briefly.
  List<int> _flashRows = const [];
  double _flashTimer = 0;

  ShedGame({
    required this.mode,
    required this.onGameOver,
    required this.onScoreChanged,
    Random? random,
  }) : _random = random ?? Random();

  Set<Point<int>> get skin => _skin;
  int get mealsUntilShed => shedEvery - _mealsSinceShed;

  @override
  Color backgroundColor() => Color.lerp(mode.backgroundColor, Colors.black, 0.3)!;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _calculateGrid();
    _startNewGame();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
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
    rowsCleared = 0;
    _tickTimer = 0;
    _pendingGrowth = 0;
    _mealsSinceShed = 0;
    _skin.clear();
    _skinVersion++;
    _flashRows = const [];
    gameState = GameState.playing;
    currentDirection = Direction.right;
    _directionQueue.clear();
    final y = gridHeight ~/ 2;
    const x = 4;
    snakeSegments = GridSnakeBody([Point(x, y), Point(x - 1, y), Point(x - 2, y)]);
    _spawnFood();
  }

  void restart() {
    _startNewGame();
    onScoreChanged(0);
  }

  void _spawnFood() {
    food = randomFreeCell(
      width: gridWidth,
      height: gridHeight,
      occupied: [...snakeSegments, ..._skin],
      random: _random,
    );
    // No room left for food: the den is full.
    if (food == null) _die();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashTimer > 0) _flashTimer = max(0, _flashTimer - dt);
    if (gameState != GameState.playing) return;
    _tickTimer += dt;
    if (_tickTimer >= mode.tickInterval(score)) {
      _tickTimer = 0;
      _tick();
    }
  }

  void _tick() {
    currentDirection = _directionQueue.consume(currentDirection);
    final newHead = gridStep(snakeSegments.first, currentDirection);
    if (newHead.x < 0 ||
        newHead.x >= gridWidth ||
        newHead.y < 0 ||
        newHead.y >= gridHeight ||
        _skin.contains(newHead) ||
        snakeSegments.contains(newHead)) {
      _die();
      return;
    }

    snakeSegments.insert(0, newHead);
    if (_pendingGrowth > 0) {
      _pendingGrowth--;
    } else {
      snakeSegments.removeLast();
    }

    if (newHead == food) {
      score += mode.pointsPerFood(score);
      _pendingGrowth += growthPerFood;
      _mealsSinceShed++;
      if (_mealsSinceShed >= shedEvery) shedSkin();
      onScoreChanged(score);
      HapticFeedback.selectionClick();
      _spawnFood();
    }
  }

  /// Turns everything behind the neck into skin and clears full rows.
  @visibleForTesting
  void shedSkin() {
    _mealsSinceShed = 0;
    _pendingGrowth = 0;
    var shed = 0;
    while (snakeSegments.length > keptSegments) {
      _skin.add(snakeSegments.removeLast());
      shed++;
    }
    if (shed == 0) return;
    score += shed * 2;

    final full = [
      for (var y = 0; y < gridHeight; y++)
        if (_rowCount(y) == gridWidth) y,
    ];
    if (full.isNotEmpty) {
      _skin.removeWhere((p) => full.contains(p.y));
      rowsCleared += full.length;
      score += rowBonus[min(full.length, rowBonus.length) - 1];
      _flashRows = full;
      _flashTimer = 0.45;
      HapticFeedback.mediumImpact();
    }
    _skinVersion++;
  }

  int _rowCount(int y) {
    var n = 0;
    for (var x = 0; x < gridWidth; x++) {
      if (_skin.contains(Point(x, y))) n++;
    }
    return n;
  }

  void _die() {
    gameState = GameState.gameOver;
    HapticFeedback.heavyImpact();
    onGameOver();
  }

  void changeDirection(Direction dir) {
    if (_directionQueue.enqueue(dir, currentDirection) ==
            DirectionInput.queued &&
        _directionQueue.length == 1) {
      // Pull the first pending turn forward for responsiveness.
      final interval = mode.tickInterval(score);
      if (_tickTimer > interval * 0.3) _tickTimer = interval;
    }
  }

  void togglePause() {
    if (gameState == GameState.playing) {
      gameState = GameState.paused;
    } else if (gameState == GameState.paused) {
      gameState = GameState.playing;
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      togglePause();
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      changeDirection(Direction.up);
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      changeDirection(Direction.down);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      changeDirection(Direction.left);
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      changeDirection(Direction.right);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Offset _cellOrigin(Point<int> p) =>
      Offset(boardOffset.x + p.x * cellSize, boardOffset.y + p.y * cellSize);

  // ─── Rendering ────────────────────────────────────────────────────────
  // The board and the skin change rarely, so each is a cached picture; the
  // skin is re-recorded only when it changes or the layout does.

  ui.Picture? _boardPicture;
  (double, double, double)? _boardLayout;
  ui.Picture? _skinPicture;
  (double, double, double, int)? _skinKey;
  int _skinVersion = 0;

  final _hudText = CachedText();
  final Paint _snakePaint = Paint();
  final Paint _headPaint = Paint();
  final Paint _foodPaint = Paint();
  final Paint _flashPaint = Paint();
  final Paint _eyePaint = Paint()..color = Colors.black;

  @override
  void onRemove() {
    _boardPicture?.dispose();
    _boardPicture = null;
    _skinPicture?.dispose();
    _skinPicture = null;
    _hudText.dispose();
    super.onRemove();
  }

  ui.Picture _recordBoard() {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final cs = cellSize;
    final board = Rect.fromLTWH(boardOffset.x, boardOffset.y, gridWidth * cs, gridHeight * cs);
    c.drawRect(board, Paint()..color = mode.backgroundColor);
    final grid = Paint()..color = mode.gridColor;
    for (var y = 0; y < gridHeight; y++) {
      for (var x = (y.isEven ? 0 : 1); x < gridWidth; x += 2) {
        c.drawRect(Rect.fromLTWH(board.left + x * cs, board.top + y * cs, cs, cs), grid);
      }
    }
    c.drawRect(
      board,
      Paint()
        ..color = mode.skinColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    return recorder.endRecording();
  }

  ui.Picture _recordSkin() {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final cs = cellSize;
    // Rows close to clearing glow faintly, so players can aim for them.
    final near = Paint()..color = mode.nearRowColor.withValues(alpha: 0.12);
    for (var y = 0; y < gridHeight; y++) {
      if (_rowCount(y) >= gridWidth - 4) {
        c.drawRect(
          Rect.fromLTWH(boardOffset.x, boardOffset.y + y * cs, gridWidth * cs, cs),
          near,
        );
      }
    }
    final skin = Paint()..color = mode.skinColor.withValues(alpha: 0.85);
    final scale = Paint()
      ..color = const Color(0x55000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, cs * 0.06);
    for (final p in _skin) {
      final o = _cellOrigin(p);
      final r = Rect.fromLTWH(o.dx + cs * 0.04, o.dy + cs * 0.04, cs * 0.92, cs * 0.92);
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cs * 0.14)), skin);
      // One diamond scale per cell reads as skin, not stone.
      final m = r.center;
      final d = cs * 0.24;
      c.drawPath(
        Path()
          ..moveTo(m.dx, m.dy - d)
          ..lineTo(m.dx + d, m.dy)
          ..lineTo(m.dx, m.dy + d)
          ..lineTo(m.dx - d, m.dy)
          ..close(),
        scale,
      );
    }
    return recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;
    final layout = (cs, boardOffset.x, boardOffset.y);

    if (_boardPicture == null || _boardLayout != layout) {
      _boardLayout = layout;
      _boardPicture?.dispose();
      _boardPicture = _recordBoard();
    }
    canvas.drawPicture(_boardPicture!);

    final skinKey = (cs, boardOffset.x, boardOffset.y, _skinVersion);
    if (_skinPicture == null || _skinKey != skinKey) {
      _skinKey = skinKey;
      _skinPicture?.dispose();
      _skinPicture = _recordSkin();
    }
    canvas.drawPicture(_skinPicture!);

    if (_flashTimer > 0) {
      _flashPaint.color = Colors.white.withValues(alpha: (_flashTimer / 0.45) * 0.7);
      for (final y in _flashRows) {
        canvas.drawRect(
          Rect.fromLTWH(boardOffset.x, boardOffset.y + y * cs, gridWidth * cs, cs),
          _flashPaint,
        );
      }
    }

    final f = food;
    if (f != null) {
      _foodPaint.color = mode.foodColor;
      final o = _cellOrigin(f);
      canvas.drawCircle(Offset(o.dx + cs / 2, o.dy + cs / 2), cs * 0.3, _foodPaint);
    }

    // The part that will be shed next darkens as the shed approaches.
    _snakePaint.color = Color.lerp(
      mode.snakeColor,
      mode.skinColor,
      _mealsSinceShed / shedEvery * 0.6,
    )!;
    _headPaint.color = mode.snakeColor;
    for (var i = snakeSegments.length - 1; i >= 0; i--) {
      final o = _cellOrigin(snakeSegments[i]);
      final r = Rect.fromLTWH(o.dx + cs * 0.06, o.dy + cs * 0.06, cs * 0.88, cs * 0.88);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cs * 0.22)),
        i < keptSegments ? _headPaint : _snakePaint,
      );
    }
    if (snakeSegments.isNotEmpty) {
      final o = _cellOrigin(snakeSegments.first);
      final c = Offset(o.dx + cs / 2, o.dy + cs / 2);
      final (dx, dy) = switch (currentDirection) {
        Direction.up => (0.0, -1.0),
        Direction.down => (0.0, 1.0),
        Direction.left => (-1.0, 0.0),
        Direction.right => (1.0, 0.0),
      };
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(
          c + Offset(dx * cs * 0.18 - dy * side * cs * 0.2, dy * cs * 0.18 + dx * side * cs * 0.2),
          cs * 0.08,
          _eyePaint,
        );
      }
    }

    final hud = _hudText.painter(
      'SHED IN $mealsUntilShed · ROWS $rowsCleared',
      TextStyle(
        color: mode.skinColor.withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
    hud.paint(canvas, Offset(boardOffset.x + 4, boardOffset.y + 2));
  }
}
