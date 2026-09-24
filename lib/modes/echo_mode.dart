import 'package:flutter/material.dart';
import '../theme/naga_palette.dart';
import 'game_mode.dart';

/// Echo: your previous run replays as a ghost snake. Touch it and you die.
class EchoMode extends GameMode {
  @override
  String get name => 'Echo';

  @override
  String get description => 'Outrun your last run';

  @override
  Color get backgroundColor => const Color(0xFF1C1B29); // dusk mist

  @override
  Color get snakeColor => NagaPalette.parrotLime;

  @override
  Color get foodColor => NagaPalette.flowerPink;

  @override
  Color get gridColor => const Color(0xFF242236);

  /// The echo: a pale violet ghost.
  Color get echoColor => const Color(0xFFB39DDB);

  @override
  bool get wallsKill => true;

  @override
  bool get showGrid => true;

  @override
  bool get hasPowerUps => false;

  @override
  double tickInterval(int score) {
    const baseInterval = 0.17;
    const minInterval = 0.08;
    final speedUp = (score ~/ 50) * 0.01;
    return (baseInterval - speedUp).clamp(minInterval, baseInterval);
  }

  @override
  int pointsPerFood(int score) => 10;
}
