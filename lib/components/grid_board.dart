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
    final isClassic = _game.mode.name == 'Classic';

    if (isClassic) {
      _renderClassicGrid(canvas, cs, offset, gw, gh);
    } else {
      _renderCheckerboard(canvas, cs, offset, gw, gh);
    }

    // Border
    final borderPaint = Paint()
      ..color = _game.mode.snakeColor.withOpacity(isClassic ? 1.0 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isClassic ? 2 : 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.x, offset.y, cs * gw, cs * gh),
        Radius.circular(isClassic ? 0 : 4),
      ),
      borderPaint,
    );
  }

  void _renderClassicGrid(Canvas canvas, double cs, Vector2 offset, int gw, int gh) {
    if (!_game.mode.showGrid) return;

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

  void _renderCheckerboard(Canvas canvas, double cs, Vector2 offset, int gw, int gh) {
    // Subtle two-tone checkerboard — no grid lines
    final bg = _game.mode.backgroundColor;
    final light = Color.lerp(bg, Colors.white, 0.03)!;
    final dark = bg;
    final lightPaint = Paint()..color = light;
    final darkPaint = Paint()..color = dark;

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
  }
}
