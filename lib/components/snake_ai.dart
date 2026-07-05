import 'dart:math';
import '../game/snake_game.dart' show Direction;

/// AI difficulty levels for computer-controlled snakes.
enum AiDifficulty { easy, medium, hard, expert }

/// A reusable AI brain that decides the next direction for a snake.
///
/// Each [AiDifficulty] level uses a progressively smarter algorithm:
/// - **Easy** — random direction changes, 30 % chance of a bad move.
/// - **Medium** — seeks nearest food, avoids walls, looks 1 cell ahead.
/// - **Hard** — seeks food, avoids walls & other snakes, looks 3 cells ahead,
///   tries to cut off the opponent.
/// - **Expert** — minimax-like evaluation scoring each direction by simulating
///   5+ steps forward, considering food distance, available space (flood fill),
///   and opponent proximity. Actively tries to trap the player.
class SnakeAI {
  final AiDifficulty difficulty;
  final Random _random = Random();

  SnakeAI({required this.difficulty});

  /// Returns the best [Direction] for this AI given the current board state.
  ///
  /// [snakeSegments] — this AI snake's body (head-first).
  /// [otherSnakes] — list of all *other* snakes on the board (head-first each).
  /// [food] — position of the food item(s).
  /// [gridWidth], [gridHeight] — board dimensions.
  /// [wallsKill] — whether hitting walls kills the snake.
  Direction decideDirection(
    List<Point<int>> snakeSegments,
    List<List<Point<int>>> otherSnakes,
    List<Point<int>> food,
    int gridWidth,
    int gridHeight,
    bool wallsKill,
  ) {
    switch (difficulty) {
      case AiDifficulty.easy:
        return _decideEasy(
            snakeSegments, otherSnakes, food, gridWidth, gridHeight, wallsKill);
      case AiDifficulty.medium:
        return _decideMedium(
            snakeSegments, otherSnakes, food, gridWidth, gridHeight, wallsKill);
      case AiDifficulty.hard:
        return _decideHard(
            snakeSegments, otherSnakes, food, gridWidth, gridHeight, wallsKill);
      case AiDifficulty.expert:
        return _decideExpert(
            snakeSegments, otherSnakes, food, gridWidth, gridHeight, wallsKill);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Direction _currentDirection(List<Point<int>> segments) {
    if (segments.length < 2) return Direction.right;
    final head = segments[0];
    final neck = segments[1];
    final dx = head.x - neck.x;
    final dy = head.y - neck.y;
    if (dx == 1) return Direction.right;
    if (dx == -1) return Direction.left;
    if (dy == 1) return Direction.down;
    return Direction.up;
  }

  bool _isOpposite(Direction a, Direction b) {
    return (a == Direction.up && b == Direction.down) ||
        (a == Direction.down && b == Direction.up) ||
        (a == Direction.left && b == Direction.right) ||
        (a == Direction.right && b == Direction.left);
  }

  Point<int> _move(Point<int> p, Direction dir) {
    switch (dir) {
      case Direction.up:
        return Point(p.x, p.y - 1);
      case Direction.down:
        return Point(p.x, p.y + 1);
      case Direction.left:
        return Point(p.x - 1, p.y);
      case Direction.right:
        return Point(p.x + 1, p.y);
    }
  }

  bool _outOfBounds(Point<int> p, int w, int h) {
    return p.x < 0 || p.x >= w || p.y < 0 || p.y >= h;
  }

  bool _hitsBody(Point<int> p, List<Point<int>> body) {
    return body.any((s) => s.x == p.x && s.y == p.y);
  }

  bool _hitsAnySnake(Point<int> p, List<List<Point<int>>> snakes) {
    for (final s in snakes) {
      if (_hitsBody(p, s)) return true;
    }
    return false;
  }

  Set<Point<int>> _allOccupied(
      List<Point<int>> self, List<List<Point<int>>> others) {
    final set = <Point<int>>{};
    for (final s in self) {
      set.add(s);
    }
    for (final snake in others) {
      for (final s in snake) {
        set.add(s);
      }
    }
    return set;
  }

  /// Valid (non-opposite, non-wall, non-body) directions.
  List<Direction> _safeDirs(
    List<Point<int>> segments,
    List<List<Point<int>>> others,
    int w,
    int h,
    bool wallsKill,
  ) {
    final cur = _currentDirection(segments);
    final head = segments.first;
    final safe = <Direction>[];
    for (final d in Direction.values) {
      if (_isOpposite(d, cur)) continue;
      final next = _move(head, d);
      if (wallsKill && _outOfBounds(next, w, h)) continue;
      if (_hitsBody(next, segments)) continue;
      if (_hitsAnySnake(next, others)) continue;
      safe.add(d);
    }
    return safe;
  }

  int _manhattan(Point<int> a, Point<int> b) {
    return (a.x - b.x).abs() + (a.y - b.y).abs();
  }

  Point<int>? _nearestFood(Point<int> head, List<Point<int>> food) {
    if (food.isEmpty) return null;
    Point<int>? best;
    int bestDist = 999999;
    for (final f in food) {
      final d = _manhattan(head, f);
      if (d < bestDist) {
        bestDist = d;
        best = f;
      }
    }
    return best;
  }

  /// Flood-fill to count reachable cells from [start].
  int _floodFill(
    Point<int> start,
    Set<Point<int>> blocked,
    int w,
    int h,
  ) {
    final visited = <String>{};
    final queue = <Point<int>>[start];
    int count = 0;
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      final key = '${p.x},${p.y}';
      if (visited.contains(key)) continue;
      if (p.x < 0 || p.x >= w || p.y < 0 || p.y >= h) continue;
      if (blocked.contains(p)) continue;
      visited.add(key);
      count++;
      // Limit search to avoid perf issues
      if (count > 150) return count;
      queue.add(Point(p.x + 1, p.y));
      queue.add(Point(p.x - 1, p.y));
      queue.add(Point(p.x, p.y + 1));
      queue.add(Point(p.x, p.y - 1));
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Easy: Random with 30 % bad-move chance
  // ---------------------------------------------------------------------------

  Direction _decideEasy(
    List<Point<int>> segments,
    List<List<Point<int>>> others,
    List<Point<int>> food,
    int w,
    int h,
    bool wallsKill,
  ) {
    final cur = _currentDirection(segments);
    final safe = _safeDirs(segments, others, w, h, wallsKill);
    if (safe.isEmpty) return cur;

    // 30 % chance of a random (potentially bad) move
    if (_random.nextDouble() < 0.30) {
      // Pick any non-opposite direction, even if unsafe
      final candidates =
          Direction.values.where((d) => !_isOpposite(d, cur)).toList();
      return candidates[_random.nextInt(candidates.length)];
    }

    // Otherwise pick a random safe direction
    return safe[_random.nextInt(safe.length)];
  }

  // ---------------------------------------------------------------------------
  // Medium: Seek food, avoid walls, look 1 cell ahead
  // ---------------------------------------------------------------------------

  Direction _decideMedium(
    List<Point<int>> segments,
    List<List<Point<int>>> others,
    List<Point<int>> food,
    int w,
    int h,
    bool wallsKill,
  ) {
    final cur = _currentDirection(segments);
    final head = segments.first;
    final safe = _safeDirs(segments, others, w, h, wallsKill);
    if (safe.isEmpty) return cur;

    final target = _nearestFood(head, food);
    if (target != null) {
      // Prefer directions that bring us closer
      final preferred = <Direction>[];
      if (target.x < head.x) preferred.add(Direction.left);
      if (target.x > head.x) preferred.add(Direction.right);
      if (target.y < head.y) preferred.add(Direction.up);
      if (target.y > head.y) preferred.add(Direction.down);

      for (final d in preferred) {
        if (safe.contains(d)) return d;
      }
    }

    return safe[_random.nextInt(safe.length)];
  }

  // ---------------------------------------------------------------------------
  // Hard: Seek food, avoid walls & snakes, look 3 cells ahead, cut off
  // ---------------------------------------------------------------------------

  Direction _decideHard(
    List<Point<int>> segments,
    List<List<Point<int>>> others,
    List<Point<int>> food,
    int w,
    int h,
    bool wallsKill,
  ) {
    final cur = _currentDirection(segments);
    final head = segments.first;
    final safe = _safeDirs(segments, others, w, h, wallsKill);
    if (safe.isEmpty) return cur;

    // Score each safe direction
    int bestScore = -999999;
    Direction bestDir = safe.first;

    for (final d in safe) {
      int score = 0;
      final next = _move(head, d);

      // Look 3 cells ahead: penalise if future path is blocked
      Point<int> probe = next;
      bool blocked = false;
      for (int step = 0; step < 3; step++) {
        probe = _move(probe, d);
        if (wallsKill && _outOfBounds(probe, w, h)) {
          blocked = true;
          break;
        }
        if (_hitsBody(probe, segments) || _hitsAnySnake(probe, others)) {
          blocked = true;
          break;
        }
      }
      if (blocked) score -= 50;

      // Food attraction
      final target = _nearestFood(next, food);
      if (target != null) {
        final distBefore = _manhattan(head, target);
        final distAfter = _manhattan(next, target);
        score += (distBefore - distAfter) * 20;
      }

      // Cut-off bonus: if moving here puts us closer to opponent's head
      for (final other in others) {
        if (other.isEmpty) continue;
        final oppHead = other.first;
        final distToOpp = _manhattan(next, oppHead);
        if (distToOpp <= 3) {
          score += (4 - distToOpp) * 10; // bonus for being near opponent
        }
      }

      // Stay away from walls
      if (next.x <= 1 || next.x >= w - 2) score -= 10;
      if (next.y <= 1 || next.y >= h - 2) score -= 10;

      if (score > bestScore) {
        bestScore = score;
        bestDir = d;
      }
    }

    return bestDir;
  }

  // ---------------------------------------------------------------------------
  // Expert: Minimax-like evaluation with flood fill
  // ---------------------------------------------------------------------------

  Direction _decideExpert(
    List<Point<int>> segments,
    List<List<Point<int>>> others,
    List<Point<int>> food,
    int w,
    int h,
    bool wallsKill,
  ) {
    final cur = _currentDirection(segments);
    final head = segments.first;
    final safe = _safeDirs(segments, others, w, h, wallsKill);
    if (safe.isEmpty) return cur;

    final occupied = _allOccupied(segments, others);

    double bestScore = double.negativeInfinity;
    Direction bestDir = safe.first;

    for (final d in safe) {
      final next = _move(head, d);
      double score = 0;

      // 1. Simulate 5 steps forward in this direction
      final simBlocked = Set<Point<int>>.from(occupied);
      simBlocked.add(next);
      Point<int> probe = next;
      int stepsAlive = 0;
      for (int step = 0; step < 5; step++) {
        // Find best next step greedily
        Direction? bestSim;
        int bestSimScore = -999999;
        for (final sd in Direction.values) {
          if (_isOpposite(sd, step == 0 ? d : _dirFromDelta(probe, _move(probe, sd)))) {
            continue;
          }
          final sp = _move(probe, sd);
          if (_outOfBounds(sp, w, h)) continue;
          if (simBlocked.contains(sp)) continue;
          int ss = 0;
          final ft = _nearestFood(sp, food);
          if (ft != null) ss += 100 - _manhattan(sp, ft);
          if (ss > bestSimScore) {
            bestSimScore = ss;
            bestSim = sd;
          }
        }
        if (bestSim == null) break;
        probe = _move(probe, bestSim);
        simBlocked.add(probe);
        stepsAlive++;
      }
      score += stepsAlive * 15;

      // 2. Food distance
      final target = _nearestFood(next, food);
      if (target != null) {
        final dist = _manhattan(next, target);
        score += (50 - dist).clamp(0, 50).toDouble();
        // Bonus for being on food
        if (dist == 0) score += 100;
      }

      // 3. Available space (flood fill) — most important for survival
      final ffBlocked = Set<Point<int>>.from(occupied);
      ffBlocked.remove(head); // head will move
      final space = _floodFill(next, ffBlocked, w, h);
      score += space * 2;

      // Penalise small areas that could trap us
      if (space < segments.length + 3) {
        score -= 200;
      }

      // 4. Opponent proximity — actively trap
      for (final other in others) {
        if (other.isEmpty) continue;
        final oppHead = other.first;
        final distToOpp = _manhattan(next, oppHead);

        // Try to be adjacent to opponent to limit their options
        if (distToOpp <= 2) {
          // Count opponent's safe moves from their head
          int oppSafeMoves = 0;
          for (final od in Direction.values) {
            final op = _move(oppHead, od);
            if (!_outOfBounds(op, w, h) &&
                !ffBlocked.contains(op) &&
                op.x != next.x || op.y != next.y) {
              oppSafeMoves++;
            }
          }
          // Fewer safe moves for opponent = better for us
          score += (4 - oppSafeMoves) * 25;
        }

        // Moderate attraction to opponent
        if (distToOpp <= 5) {
          score += (6 - distToOpp) * 5;
        }
      }

      // 5. Wall avoidance
      if (next.x == 0 || next.x == w - 1) score -= 15;
      if (next.y == 0 || next.y == h - 1) score -= 15;

      if (score > bestScore) {
        bestScore = score;
        bestDir = d;
      }
    }

    return bestDir;
  }

  Direction _dirFromDelta(Point<int> from, Point<int> to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    if (dx == 1) return Direction.right;
    if (dx == -1) return Direction.left;
    if (dy == 1) return Direction.down;
    return Direction.up;
  }
}
