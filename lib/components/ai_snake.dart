import 'dart:math';
import '../game/trail_game.dart';
import 'trail_snake.dart';

/// Simple AI opponent for Trail mode.
/// Uses a survival-oriented heuristic: avoid walls, trails, and prefer open space.
class AiSnake {
  final TrailGame game;
  final TrailSnake snake;
  final Random _random = Random();

  AiSnake({required this.game, required this.snake});

  /// Decide the next direction for the AI snake.
  void think() {
    final head = snake.segments.first;
    final current = snake.direction;

    // Evaluate all four directions
    final candidates = <Direction, double>{};

    for (final dir in Direction.values) {
      // Can't reverse
      if (_isOpposite(dir, current)) continue;

      final next = _move(head, dir);

      // Check if this move is immediately fatal
      if (_isFatal(next)) continue;

      // Score based on how much open space is ahead
      candidates[dir] = _evaluate(next, dir);
    }

    if (candidates.isEmpty) {
      // All moves are fatal — just keep going (will die)
      return;
    }

    // Pick the best direction (highest score), with some randomness for variety
    final sorted = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Pick the best, but occasionally pick second-best for unpredictability
    if (sorted.length > 1 &&
        _random.nextDouble() < 0.15 &&
        sorted[1].value > 0) {
      snake.changeDirection(sorted[1].key);
    } else {
      snake.changeDirection(sorted[0].key);
    }
  }

  Point<int> _move(Point<int> from, Direction dir) {
    switch (dir) {
      case Direction.up:
        return Point(from.x, from.y - 1);
      case Direction.down:
        return Point(from.x, from.y + 1);
      case Direction.left:
        return Point(from.x - 1, from.y);
      case Direction.right:
        return Point(from.x + 1, from.y);
    }
  }

  bool _isFatal(Point<int> pos) {
    // Wall check
    if (pos.x < 0 || pos.x >= game.gridWidth || pos.y < 0 || pos.y >= game.gridHeight) {
      return true;
    }
    // Trail collision (player or any AI)
    if (game.isTrailAt(pos)) {
      return true;
    }
    return false;
  }

  /// Evaluate how good a position is by looking ahead in a cone.
  double _evaluate(Point<int> pos, Direction dir) {
    double score = 0;

    // Look ahead several steps in the current direction
    var current = pos;
    for (int i = 0; i < 8; i++) {
      current = _move(current, dir);
      if (_isFatal(current)) break;
      score += (8 - i); // Closer free cells are worth more
    }

    // Also check perpendicular directions for breathing room
    for (final perpDir in _perpendicular(dir)) {
      var side = pos;
      for (int i = 0; i < 4; i++) {
        side = _move(side, perpDir);
        if (_isFatal(side)) break;
        score += (4 - i) * 0.5;
      }
    }

    // Prefer center of the board slightly
    final centerX = game.gridWidth / 2;
    final centerY = game.gridHeight / 2;
    final distFromCenter = (pos.x - centerX).abs() + (pos.y - centerY).abs();
    score += max(0, 10 - distFromCenter) * 0.3;

    // Small random factor
    score += _random.nextDouble() * 2;

    return score;
  }

  List<Direction> _perpendicular(Direction dir) {
    switch (dir) {
      case Direction.up:
      case Direction.down:
        return [Direction.left, Direction.right];
      case Direction.left:
      case Direction.right:
        return [Direction.up, Direction.down];
    }
  }

  bool _isOpposite(Direction a, Direction b) {
    return (a == Direction.up && b == Direction.down) ||
        (a == Direction.down && b == Direction.up) ||
        (a == Direction.left && b == Direction.right) ||
        (a == Direction.right && b == Direction.left);
  }
}
