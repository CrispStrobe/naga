import 'package:flutter/material.dart';
import 'game_mode.dart';

/// CGA mode — 4-color IBM PC palette 1, chunky blocky pixels.
class CgaMode extends GameMode {
  // CGA palette 1
  static const Color _black = Color(0xFF000000);
  static const Color _cyan = Color(0xFF00AAAA);
  static const Color _magenta = Color(0xFFAA00AA);
  static const Color _white = Color(0xFFAAAAAA);

  @override
  String get name => 'CGA';

  @override
  String get description => '4-color retro PC';

  @override
  Color get backgroundColor => _black;

  @override
  Color get snakeColor => _cyan;

  @override
  Color get foodColor => _magenta;

  @override
  Color get gridColor => _black;

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.22;
    const minInterval = 0.08;
    final speedUp = (score ~/ 50) * 0.02;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;

  /// CGA white for borders.
  Color get borderColor => _white;
}
