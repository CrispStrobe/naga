import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';

class GridBoard extends Component with HasGameReference<SnakeGame> {
  final SnakeGame _game;

  GridBoard({required SnakeGame game}) : _game = game;

  @override
  void render(Canvas canvas) {
    final cs = _game.cellSize;
    final offset = _game.boardOffset;
    final gw = _game.gridWidth;
    final gh = _game.gridHeight;

    // Draw board border
    final borderPaint = Paint()
      ..color = _game.mode.snakeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(
      Rect.fromLTWH(
        offset.x,
        offset.y,
        cs * gw,
        cs * gh,
      ),
      borderPaint,
    );

    if (!_game.mode.showGrid) return;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = _game.mode.gridColor
      ..strokeWidth = 0.5;

    for (int x = 0; x <= gw; x++) {
      canvas.drawLine(
        Offset(offset.x + x * cs, offset.y),
        Offset(offset.x + x * cs, offset.y + gh * cs),
        gridPaint,
      );
    }

    for (int y = 0; y <= gh; y++) {
      canvas.drawLine(
        Offset(offset.x, offset.y + y * cs),
        Offset(offset.x + gw * cs, offset.y + y * cs),
        gridPaint,
      );
    }
  }
}
