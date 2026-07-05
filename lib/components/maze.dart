import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Pac-Man style maze layout.
///
/// The maze is defined on a 20x28 grid where:
///   1 = wall
///   0 = corridor with dot
///   E = empty corridor (no dot)
///   3 = power pellet position
///   4 = ghost house (passable, no dot)
///   5 = snake start position
class Maze extends Component {
  static const int gridWidth = 20;
  static const int gridHeight = 28;

  late List<List<int>> layout;
  final Set<Point<int>> dots = {};
  final Set<Point<int>> powerPellets = {};
  Point<int> snakeStart = const Point(10, 21);
  final List<Point<int>> ghostStarts = [];

  final Color wallColor;
  final Color dotColor;
  final Color powerPelletColor;
  final double Function() getCellSize;
  final Vector2 Function() getBoardOffset;

  double _pelletPulse = 0;

  int _currentLevel = 0;

  Maze({
    required this.wallColor,
    required this.dotColor,
    required this.powerPelletColor,
    required this.getCellSize,
    required this.getBoardOffset,
  });

  void setLevel(int level) {
    _currentLevel = level;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildLayout();
    _populateDots();
  }

  static const List<List<String>> _layouts = [
    // Level 1 — Classic open maze, gentle intro
    [
      '11111111111111111111',
      '1P................P1',
      '1..111111..111111..1',
      '1..111111..111111..1',
      '1..................1',
      '1..................1',
      '1..1111......1111..1',
      '1..1111......1111..1',
      '1......EEEEEE......1',
      '1..11.EEEEEEEE.11..1',
      '1.....EEG..GEE.....1',
      '1..11.EEEEEEEE.11..1',
      '1......EEEEEE......1',
      '1..................1',
      '1..................1',
      '1..1111......1111..1',
      '1..1111......1111..1',
      '1..................1',
      '1..................1',
      '1..111..1111..111..1',
      '1..111..1111..111..1',
      '1......ESSSSE......1',
      '1......ESSSSE......1',
      '1..111..1111..111..1',
      '1..111........111..1',
      '1..................1',
      '1P................P1',
      '11111111111111111111',
    ],
    // Level 2 — Diamond corridors
    [
      '11111111111111111111',
      '1P................P1',
      '1.................P1',
      '1..1111......1111..1',
      '1..1111......1111..1',
      '1......1111........1',
      '1......1111........1',
      '1..11........11....1',
      '1..11..EEEE..11....1',
      '1......EG.GE.......1',
      '1......EG.GE.......1',
      '1..11..EEEE..11....1',
      '1..11........11....1',
      '1........1111......1',
      '1........1111......1',
      '1..1111......1111..1',
      '1..1111......1111..1',
      '1..................1',
      '1..................1',
      '1....11......11....1',
      '1....11......11....1',
      '1.......SSSS.......1',
      '1.......EEEE.......1',
      '1....11......11....1',
      '1....11......11....1',
      '1..................1',
      '1P................P1',
      '11111111111111111111',
    ],
    // Level 3 — Winding corridors, more walls
    [
      '11111111111111111111',
      '1P......1111......P1',
      '1.......1111.......1',
      '1..111........111..1',
      '1..111........111..1',
      '1........1111......1',
      '1........1111......1',
      '1..11..........11..1',
      '1..11..EEEE....11..1',
      '1......EG.GE.......1',
      '1......EG.GE.......1',
      '1..11..EEEE....11..1',
      '1..11..........11..1',
      '1......1111........1',
      '1......1111........1',
      '1..111........111..1',
      '1..111........111..1',
      '1..................1',
      '1..................1',
      '1..11..111111..11..1',
      '1..11..111111..11..1',
      '1......ESSSSE......1',
      '1......ESSSSE......1',
      '1..1111......1111..1',
      '1..1111......1111..1',
      '1..................1',
      '1P................P1',
      '11111111111111111111',
    ],
    // Level 4 — Cross pattern
    [
      '11111111111111111111',
      '1P................P1',
      '1..................1',
      '1..11..1111..11....1',
      '1..11..1111..11....1',
      '1......1111........1',
      '1......1111........1',
      '1..11........11....1',
      '1..11..EEEE..11....1',
      '1......EG.GE.......1',
      '1......EG.GE.......1',
      '1..11..EEEE..11....1',
      '1..11........11....1',
      '1..................1',
      '1..................1',
      '1..111111111111....1',
      '1..111111111111....1',
      '1..................1',
      '1..................1',
      '1....1111..1111....1',
      '1....1111..1111....1',
      '1.......SSSS.......1',
      '1.......EEEE.......1',
      '1..11........11....1',
      '1..11........11....1',
      '1..................1',
      '1P................P1',
      '11111111111111111111',
    ],
    // Level 5 — Tight chambers, harder
    [
      '11111111111111111111',
      '1P................P1',
      '1..................1',
      '1..1111..11..1111..1',
      '1..1111..11..1111..1',
      '1..11..........11..1',
      '1..11..........11..1',
      '1........1111......1',
      '1....11.EEEEE.11...1',
      '1....11.EG.GE.11...1',
      '1.......EG.GE......1',
      '1....11.EEEEE.11...1',
      '1........1111......1',
      '1..11..........11..1',
      '1..11..........11..1',
      '1........1111......1',
      '1........1111......1',
      '1..1111......1111..1',
      '1..1111......1111..1',
      '1..................1',
      '1..................1',
      '1..11..SSSS..11....1',
      '1..11..EEEE..11....1',
      '1......1111........1',
      '1......1111........1',
      '1..................1',
      '1P................P1',
      '11111111111111111111',
    ],
    // Level 6 — Spiral-inspired
    [
      '11111111111111111111',
      '1P................P1',
      '1..................1',
      '1..111111111111....1',
      '1..111111111111....1',
      '1..11..........11..1',
      '1..11..........11..1',
      '1..11..1111..11....1',
      '1..11..EEEE..11....1',
      '1......EG.GE.......1',
      '1......EG.GE.......1',
      '1..11..EEEE..11....1',
      '1..11..1111..11....1',
      '1..11..........11..1',
      '1..11..........11..1',
      '1....111111111111..1',
      '1....111111111111..1',
      '1..................1',
      '1..................1',
      '1..1111......1111..1',
      '1..1111......1111..1',
      '1.......SSSS.......1',
      '1.......EEEE.......1',
      '1..11..........11..1',
      '1..11..........11..1',
      '1..................1',
      '1P................P1',
      '11111111111111111111',
    ],
  ];

  void _buildLayout() {
    // W=1(wall), .=0(dot corridor), E=empty, P=3(power pellet),
    // G=4(ghost house), S=5(snake start)
    // All corridors are 2+ cells wide so the snake can always turn around.
    final rows = _layouts[_currentLevel % _layouts.length];

    layout = List.generate(gridHeight, (y) {
      return List.generate(gridWidth, (x) {
        if (y >= rows.length || x >= rows[y].length) return 1;
        final ch = rows[y][x];
        switch (ch) {
          case '1':
            return 1; // wall
          case '.':
            return 0; // corridor with dot
          case 'E':
            return 6; // empty corridor, no dot
          case 'P':
            return 3; // power pellet
          case 'G':
            return 4; // ghost start
          case 'S':
            return 5; // snake start
          default:
            return 1;
        }
      });
    });
  }

  void _populateDots() {
    dots.clear();
    powerPellets.clear();
    ghostStarts.clear();

    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        final cell = layout[y][x];
        if (cell == 0) {
          dots.add(Point(x, y));
          // keep as 0 in layout (passable)
        } else if (cell == 3) {
          powerPellets.add(Point(x, y));
          layout[y][x] = 0; // passable
        } else if (cell == 4) {
          ghostStarts.add(Point(x, y));
          layout[y][x] = 0; // passable
        } else if (cell == 5) {
          snakeStart = Point(x, y);
          layout[y][x] = 0; // passable
        } else if (cell == 6) {
          layout[y][x] = 0; // passable, no dot
        }
      }
    }

    // Ensure we have 4 ghost start positions
    while (ghostStarts.length < 4) {
      ghostStarts.add(Point(8 + ghostStarts.length, 10));
    }
  }

  bool isWall(int x, int y) {
    if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) return true;
    return layout[y][x] == 1;
  }

  bool isPassable(int x, int y) => !isWall(x, y);

  bool collectDot(Point<int> pos) {
    return dots.remove(pos);
  }

  bool collectPowerPellet(Point<int> pos) {
    return powerPellets.remove(pos);
  }

  bool get allDotsCollected => dots.isEmpty && powerPellets.isEmpty;

  void resetDots() {
    _buildLayout();
    _populateDots();
  }

  List<Point<int>> getPassableNeighbors(Point<int> pos) {
    final neighbors = <Point<int>>[];
    for (final dir in [
      const Point(0, -1),
      const Point(0, 1),
      const Point(-1, 0),
      const Point(1, 0),
    ]) {
      final nx = pos.x + dir.x;
      final ny = pos.y + dir.y;
      if (isPassable(nx, ny)) {
        neighbors.add(Point(nx, ny));
      }
    }
    return neighbors;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pelletPulse += dt;
  }

  @override
  void render(Canvas canvas) {
    final cs = getCellSize();
    final offset = getBoardOffset();

    final wallPaint = Paint()..color = wallColor;
    final dotPaint = Paint()..color = dotColor;
    final pelletPaint = Paint()..color = powerPelletColor;

    // Draw walls
    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        if (layout[y][x] == 1) {
          _drawWallCell(canvas, x, y, cs, offset, wallPaint);
        }
      }
    }

    // Draw dots
    final dotRadius = cs * 0.12;
    for (final dot in dots) {
      final cx = offset.x + dot.x * cs + cs / 2;
      final cy = offset.y + dot.y * cs + cs / 2;
      canvas.drawCircle(Offset(cx, cy), dotRadius, dotPaint);
    }

    // Draw power pellets (pulsing)
    final pulse = 0.7 + 0.3 * sin(_pelletPulse * 4);
    final pelletRadius = cs * 0.35 * pulse;
    for (final pellet in powerPellets) {
      final cx = offset.x + pellet.x * cs + cs / 2;
      final cy = offset.y + pellet.y * cs + cs / 2;
      canvas.drawCircle(Offset(cx, cy), pelletRadius, pelletPaint);
    }
  }

  void _drawWallCell(
      Canvas canvas, int x, int y, double cs, Vector2 offset, Paint paint) {
    final sx = offset.x + x * cs;
    final sy = offset.y + y * cs;

    final inset = cs * 0.08;
    final wallRect = Rect.fromLTWH(
      sx + inset,
      sy + inset,
      cs - inset * 2,
      cs - inset * 2,
    );

    final rrect =
        RRect.fromRectAndRadius(wallRect, Radius.circular(cs * 0.15));
    canvas.drawRRect(rrect, paint);

    final borderPaint = Paint()
      ..color = wallColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, borderPaint);
  }
}
