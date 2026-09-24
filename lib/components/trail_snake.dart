import 'dart:math';
import 'dart:ui' as ui;
import '../game/shared/grid_motion.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/trail_game.dart';
import '../game/shared/grid_snake_body.dart';

/// A snake that leaves a permanent light trail behind it.
/// Used for both the player and AI in Trail mode.
class TrailSnake extends Component {
  final TrailGame game;
  final Color color;
  final Color trailColor;

  List<Point<int>> segments;
  Direction direction;
  Direction _nextDirection;

  /// Every cell this snake has ever occupied (the permanent trail).
  final Set<int> trail = {};

  bool alive = true;

  TrailSnake({
    required this.game,
    required List<Point<int>> initialSegments,
    required this.color,
    Color? trailColor,
    required this.direction,
  })  : segments = GridSnakeBody(initialSegments),
        _nextDirection = direction,
        trailColor = trailColor ?? color.withAlpha(100) {
    // Mark initial segments as part of the trail
    for (final seg in initialSegments) {
      trail.add(_key(seg));
    }
  }

  static int _key(Point<int> p) => p.y * 10000 + p.x;

  bool occupiesTrail(Point<int> pos) => trail.contains(_key(pos));

  bool occupiesHead(Point<int> pos) =>
      segments.isNotEmpty && segments.first.x == pos.x && segments.first.y == pos.y;

  void changeDirection(Direction dir) {
    // Prevent 180-degree turns
    if (areOpposite(dir, direction)) return;
    _nextDirection = dir;
  }

  /// Compute where the head would go next, applying the queued direction.
  /// Call this BEFORE advance() to check collisions.
  Point<int> peekNextHead() {
    final dir = _nextDirection;
    final head = segments.first;
    return gridStep(head, dir);
  }

  /// Actually move the snake to [newHead]. Call after collision checks pass.
  void advance(Point<int> newHead) {
    direction = _nextDirection;

    // The snake body stays constant length (3).
    segments.insert(0, newHead);
    if (segments.length > 3) {
      _settled.add(segments.removeLast());
    }

    // Mark position in permanent trail
    trail.add(_key(newHead));
  }

  // Trail cells that have left the body, in the order they left. Recorded
  // into fixed-size pictures so a frame replays a handful of pictures
  // instead of issuing two draws per cell; the trail only ever grows.
  final List<Point<int>> _settled = [];
  final List<ui.Picture> _chunks = [];
  ui.Picture? _openChunk;
  int _openChunkCells = 0;
  (double, double, double)? _layout;
  static const int _chunkSize = 64;

  @visibleForTesting
  int get debugRecordedChunks => _chunks.length + (_openChunk == null ? 0 : 1);

  @override
  void onRemove() {
    _disposeChunks();
    super.onRemove();
  }

  void _disposeChunks() {
    for (final chunk in _chunks) {
      chunk.dispose();
    }
    _chunks.clear();
    _openChunk?.dispose();
    _openChunk = null;
    _openChunkCells = 0;
  }

  Rect _cellRect(Point<int> cell, double cs, double inset) {
    final screenPos = game.gridToScreen(cell);
    return Rect.fromLTWH(
      screenPos.x + inset,
      screenPos.y + inset,
      cs - inset * 2,
      cs - inset * 2,
    );
  }

  late final Paint _trailPaint = Paint()..color = trailColor;
  late final Paint _trailGlowPaint = Paint()
    ..color = color.withAlpha(30)
    ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
  late final Paint _bodyPaint = Paint()..color = color;
  late final Paint _bodyGlowPaint = Paint()
    ..color = color.withAlpha(60)
    ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
  late final Paint _headGlowPaint = Paint()
    ..color = color.withAlpha(80)
    ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);

  void _drawTrailCell(Canvas canvas, Point<int> cell, double cs, double inset) {
    final rect = _cellRect(cell, cs, inset);
    canvas.drawRect(rect, _trailPaint);
    canvas.drawRect(rect, _trailGlowPaint);
  }

  ui.Picture _record(int from, int to, double cs, double inset) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = from; i < to; i++) {
      _drawTrailCell(canvas, _settled[i], cs, inset);
    }
    return recorder.endRecording();
  }

  void _drawSettledTrail(Canvas canvas, double cs, double inset) {
    final origin = game.gridToScreen(const Point(0, 0));
    final layout = (cs, origin.x, origin.y);
    if (layout != _layout) {
      _disposeChunks();
      _layout = layout;
    }
    final settledChunks = _settled.length ~/ _chunkSize;
    while (_chunks.length < settledChunks) {
      final from = _chunks.length * _chunkSize;
      _chunks.add(_record(from, from + _chunkSize, cs, inset));
    }
    final openCells = _settled.length - settledChunks * _chunkSize;
    if (openCells != _openChunkCells) {
      _openChunk?.dispose();
      _openChunk = openCells == 0
          ? null
          : _record(settledChunks * _chunkSize, _settled.length, cs, inset);
      _openChunkCells = openCells;
    }
    for (final chunk in _chunks) {
      canvas.drawPicture(chunk);
    }
    final open = _openChunk;
    if (open != null) canvas.drawPicture(open);
  }

  @override
  void render(Canvas canvas) {
    final cs = game.cellSize;
    final inset = cs * 0.05;

    _drawSettledTrail(canvas, cs, inset);

    // A dead snake's last body cells are still solid trail.
    if (!alive) {
      for (final seg in segments) {
        _drawTrailCell(canvas, seg, cs, inset);
      }
      return;
    }

    // Draw snake body (brighter than trail)
    for (final seg in segments) {
      final rect = _cellRect(seg, cs, inset);
      canvas.drawRect(rect, _bodyPaint);
      canvas.drawRect(rect, _bodyGlowPaint);
    }

    // Draw a bright head
    if (segments.isNotEmpty) {
      final headPos = game.gridToScreen(segments.first);
      canvas.drawRect(
        Rect.fromLTWH(headPos.x, headPos.y, cs, cs),
        _headGlowPaint,
      );
    }
  }
}
