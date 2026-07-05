import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';

class GridBoard extends Component with HasGameReference<SnakeGame> {
  final SnakeGame _game;
  ui.Picture? _cachedPicture;
  double _cachedCellSize = 0;

  GridBoard({required SnakeGame game}) : _game = game;

  void invalidateCache() {
    _cachedPicture?.dispose();
    _cachedPicture = null;
  }

  @override
  void render(Canvas canvas) {
    final cs = _game.cellSize;
    final offset = _game.boardOffset;
    final gw = _game.gridWidth;
    final gh = _game.gridHeight;
    final isClassic = _game.mode.name == 'Classic';

    // Rebuild cache if cell size changed (e.g. resize)
    if (_cachedPicture == null || _cachedCellSize != cs) {
      _cachedCellSize = cs;
      final recorder = ui.PictureRecorder();
      final recCanvas = Canvas(recorder);

      if (isClassic) {
        _renderClassicGrid(recCanvas, cs, offset, gw, gh);
      } else {
        _renderCheckerboard(recCanvas, cs, offset, gw, gh);
      }

      // Border
      if (_game.mode.showBorder) {
        final borderPaint = Paint()
          ..color = _game.mode.snakeColor.withOpacity(isClassic ? 1.0 : 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isClassic ? 2 : 1.5;

        recCanvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(offset.x, offset.y, cs * gw, cs * gh),
            Radius.circular(isClassic ? 0 : 4),
          ),
          borderPaint,
        );
      }

      _cachedPicture?.dispose();
      _cachedPicture = recorder.endRecording();
    }

    canvas.drawPicture(_cachedPicture!);
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

  @override
  void onRemove() {
    _cachedPicture?.dispose();
    super.onRemove();
  }
}
