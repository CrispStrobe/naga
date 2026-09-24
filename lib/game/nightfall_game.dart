import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../modes/nightfall_mode.dart';
import 'snake_game.dart';

/// Classic rules with the board hidden in darkness except around the head.
///
/// The dark is one layer per frame: a filled rect with holes punched out
/// (BlendMode.dstOut) for the lantern and a faint firefly glimmer at the
/// food, so walls, body and food are only visible where it is lit.
class NightfallGame extends SnakeGame {
  NightfallGame({
    required NightfallMode super.mode,
    required super.onGameOver,
    required super.onScoreChanged,
    super.onVictory,
    super.gridWidth,
    super.gridHeight,
    super.wallsKillOverride,
    super.speedOverride,
  });

  NightfallMode get _night => mode as NightfallMode;

  double _time = 0;
  final Paint _layerPaint = Paint();
  final Paint _darkPaint = Paint();
  final Paint _lanternPaint = Paint()..blendMode = BlendMode.dstOut;
  final Paint _glimmerPaint = Paint()..blendMode = BlendMode.dstOut;
  final Paint _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  static const _opaque = Color(0xFF000000);
  static const _clear = Color(0x00000000);

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  Offset _cellCenter(Point<int> cell) {
    final p = gridToScreen(cell);
    return Offset(p.x + cellSize / 2, p.y + cellSize / 2);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;
    final board = Rect.fromLTWH(
      boardOffset.x,
      boardOffset.y,
      gridWidth * cs,
      gridHeight * cs,
    );

    canvas.saveLayer(board, _layerPaint);
    _darkPaint.color = _night.nightColor;
    canvas.drawRect(board, _darkPaint);

    // A slight flicker keeps the lantern feeling alive.
    final flicker = 1 + sin(_time * 9) * 0.02 + sin(_time * 23) * 0.01;
    final radius = _night.lanternCells(score) * cs * flicker;
    final head = _cellCenter(snake.segments.first);
    _lanternPaint.shader = ui.Gradient.radial(
      head,
      radius,
      const [_opaque, _opaque, _clear],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(head, radius, _lanternPaint);

    // The food glimmers like a firefly, bright enough to find, not to see by.
    final pulse = 0.35 + 0.25 * (0.5 + 0.5 * sin(_time * 4));
    final glow = _cellCenter(food.gridPosition);
    _glimmerPaint.shader = ui.Gradient.radial(
      glow,
      cs * 0.9,
      [_opaque.withValues(alpha: pulse), _clear],
    );
    canvas.drawCircle(glow, cs * 0.9, _glimmerPaint);
    canvas.restore();

    // The walls are never fully dark: a faint edge shows where the board ends.
    _edgePaint.color = mode.snakeColor.withValues(alpha: 0.18);
    canvas.drawRect(board, _edgePaint);
  }
}
