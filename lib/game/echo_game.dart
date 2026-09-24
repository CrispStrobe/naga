import 'dart:math';

import 'package:flutter/material.dart';

import '../modes/echo_mode.dart';
import 'shared/cached_text.dart';
import 'snake_game.dart';

/// One recorded move: where the head was and how long the body was.
typedef EchoStep = (Point<int> head, int length);

/// Classic rules plus an echo: the previous run of this session (a lost
/// life or the last game) replays as a ghost snake, [echoDelay] moves
/// behind, and steering into it kills.
///
/// The ghost is drawn from the recording alone: at replay step t its body
/// is the last `length(t)` recorded head positions. It passes through the
/// player harmlessly; only steering the head into it is fatal.
class EchoGame extends SnakeGame {
  EchoGame({
    required EchoMode super.mode,
    required super.onGameOver,
    required super.onScoreChanged,
    super.onVictory,
    super.gridWidth,
    super.gridHeight,
    super.wallsKillOverride,
    super.speedOverride,
    super.random,
  });

  /// The echo starts this many moves after the run does.
  static const int echoDelay = 8;

  /// Bonus for still being alive when the echo's recording runs out.
  static const int outliveBonus = 50;

  // The screen builds a new game for Play again, so the last run must
  // outlive the instance: this is the recording of the most recent run in
  // this app session, echoed by the next game.
  static List<EchoStep> _sessionRecording = const [];

  /// Forgets the session's last run (tests start from a clean session).
  @visibleForTesting
  static void resetSession() => _sessionRecording = const [];

  List<EchoStep> _recording = [];
  List<EchoStep> _echo = const [];
  int _moves = 0;
  bool _outlived = false;

  /// Cells the echo occupies right now (head first); empty when inactive.
  List<Point<int>> echoBody = const [];

  /// The last full run, which the next run will replay.
  List<EchoStep> get lastRecording => _recording;
  bool get outlivedEcho => _outlived;

  EchoMode get _echoMode => mode as EchoMode;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _startRecording(_sessionRecording);
  }

  @override
  void restart() {
    final previous = _recording;
    super.restart();
    _startRecording(previous);
  }

  @override
  void respawn() {
    final previous = _recording;
    super.respawn();
    _startRecording(previous);
  }

  void _startRecording(List<EchoStep> previous) {
    // A run that barely started is not worth echoing; keep the older echo.
    if (previous.length > echoDelay) _echo = previous;
    _recording = [(snake.segments.first, snake.segments.length)];
    _sessionRecording = _recording;
    _moves = 0;
    _outlived = false;
    echoBody = const [];
  }

  @override
  @protected
  void afterMove() {
    _moves++;
    _recording.add((snake.segments.first, snake.segments.length));
    // Only steering into the echo as it was drawn is fatal. Checking after
    // the echo moves would also kill when the echo's head runs into you,
    // which you cannot see coming; like its body, its head passes through.
    if (echoBody.contains(snake.segments.first)) {
      die();
      return;
    }
    _advanceEcho();
  }

  void _advanceEcho() {
    if (_echo.isEmpty) return;
    final t = _moves - echoDelay;
    if (t < 0) return;
    if (t >= _echo.length) {
      if (!_outlived) {
        _outlived = true;
        echoBody = const [];
        score += outliveBonus;
        onScoreChanged(score);
      }
      return;
    }
    final length = _echo[t].$2;
    echoBody = [
      for (var i = t; i >= 0 && i > t - length; i--) _echo[i].$1,
    ];
  }

  // ─── Rendering ────────────────────────────────────────────────────────
  final Paint _echoPaint = Paint();
  final Paint _echoHeadPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _hudText = CachedText();

  @override
  void onRemove() {
    _hudText.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final cs = cellSize;
    if (echoBody.isNotEmpty) {
      _echoPaint.color = _echoMode.echoColor.withValues(alpha: 0.32);
      for (final cell in echoBody) {
        final p = gridToScreen(cell);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(p.x + cs * 0.1, p.y + cs * 0.1, cs * 0.8, cs * 0.8),
            Radius.circular(cs * 0.25),
          ),
          _echoPaint,
        );
      }
      final h = gridToScreen(echoBody.first);
      _echoHeadPaint.color = _echoMode.echoColor.withValues(alpha: 0.8);
      canvas.drawCircle(Offset(h.x + cs / 2, h.y + cs / 2), cs * 0.38, _echoHeadPaint);
    }

    final label = _echo.isEmpty
        ? 'NO ECHO YET'
        : _outlived
        ? 'ECHO OUTLIVED +$outliveBonus'
        : _moves < echoDelay
        ? 'ECHO IN ${echoDelay - _moves}'
        : 'ECHO';
    final tp = _hudText.painter(
      label,
      TextStyle(
        color: _echoMode.echoColor.withValues(alpha: 0.8),
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
    tp.paint(canvas, Offset(boardOffset.x + 4, boardOffset.y + 2));
  }
}
