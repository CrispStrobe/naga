import 'dart:math';

import 'package:flutter/foundation.dart';

import '../modes/daily_mode.dart';
import 'shared/daily_board.dart';
import 'shared/free_cell.dart';
import 'shared/seeded_random.dart';
import 'snake_game.dart';

/// Daily Serpent: Classic rules on a seeded rock layout.
///
/// Food comes from its own seeded stream: each spawn draws candidates in a
/// fixed order and takes the first free one, so everyone meets the same
/// food sequence unless their own body blocks a candidate.
class DailyGame extends SnakeGame {
  final SeededRandom _foodRandom;

  static const int width = 20;
  static const int height = 28;

  DailyGame({
    required DailyMode super.mode,
    required super.onGameOver,
    required super.onScoreChanged,
    super.onVictory,
  }) : _foodRandom = SeededRandom(mode.seed ^ 0x5EED5EED),
       super(
         gridWidth: width,
         gridHeight: height,
         random: SeededRandom(mode.seed ^ 0x0BADCAFE),
         rocks: dailyRocks(seed: mode.seed, width: width, height: height),
       );

  @override
  @protected
  Point<int>? nextFoodCell() {
    for (var attempt = 0; attempt < 64; attempt++) {
      final cell = Point(
        _foodRandom.nextInt(gridWidth),
        _foodRandom.nextInt(gridHeight),
      );
      if (!rocks.contains(cell) && !snake.occupies(cell)) return cell;
    }
    // A crowded board: fall back to a uniform pick among the free cells.
    return randomFreeCell(
      width: gridWidth,
      height: gridHeight,
      occupied: [...snake.segments, ...rocks],
      random: _foodRandom,
    );
  }
}
