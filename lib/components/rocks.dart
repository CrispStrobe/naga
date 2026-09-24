import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/snake_game.dart';
import '../theme/naga_palette.dart';

/// Static rock obstacles, recorded once per layout like [GridBoard].
class Rocks extends Component {
  final SnakeGame _game;
  ui.Picture? _picture;
  (double, double, double)? _layout;

  Rocks(this._game);

  static final Paint _rockPaint = Paint()..color = NagaPalette.templeBrown;
  static final Paint _shadePaint = Paint()..color = const Color(0x40000000);
  static final Paint _highlightPaint = Paint()..color = const Color(0x33FFFFFF);

  @override
  void render(Canvas canvas) {
    final cs = _game.cellSize;
    final offset = _game.boardOffset;
    final layout = (cs, offset.x, offset.y);
    if (_picture == null || _layout != layout) {
      _layout = layout;
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      final inset = cs * 0.06;
      for (final rock in _game.rocks) {
        final sp = _game.gridToScreen(rock);
        final rect = Rect.fromLTWH(
          sp.x + inset,
          sp.y + inset,
          cs - inset * 2,
          cs - inset * 2,
        );
        final radius = Radius.circular(cs * 0.2);
        c.drawRRect(RRect.fromRectAndRadius(rect.shift(Offset(0, cs * 0.06)), radius), _shadePaint);
        c.drawRRect(RRect.fromRectAndRadius(rect, radius), _rockPaint);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + cs * 0.12, rect.top + cs * 0.1, rect.width * 0.45, cs * 0.14),
            Radius.circular(cs * 0.07),
          ),
          _highlightPaint,
        );
      }
      _picture?.dispose();
      _picture = recorder.endRecording();
    }
    canvas.drawPicture(_picture!);
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }
}
