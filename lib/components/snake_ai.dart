import 'dart:collection';
import 'dart:math';
import '../game/snake_game.dart' show Direction;

/// AI difficulty levels for computer-controlled snakes.
enum AiDifficulty { easy, medium, hard, expert }

/// A reusable AI brain that decides the next direction for a snake.
///
/// Each [AiDifficulty] level uses a progressively smarter algorithm:
/// - **Easy** — random direction changes, 30% chance of a bad move.
/// - **Medium** — seeks nearest food via BFS, avoids walls, looks 1 cell ahead.
/// - **Hard** — BFS to food, avoids walls & other snakes, looks 3 cells ahead,
///   tries to cut off the opponent.
/// - **Expert** — BFS pathfinding, tail-reachability verification (Hawstein
///   technique), flood-fill space evaluation, opponent trapping. Falls back to
///   longest-path tail-following when no safe food path exists.
class SnakeAI {
  final AiDifficulty difficulty;
  final Random _random = Random();

  SnakeAI({required this.difficulty});

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
    for (final s in self) set.add(s);
    for (final snake in others) {
      for (final s in snake) set.add(s);
    }
    return set;
  }

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

  // ---------------------------------------------------------------------------
  // BFS — shortest path between two points avoiding obstacles
  // ---------------------------------------------------------------------------

  /// Returns the first direction to take on the BFS shortest path from [start]
  /// to [target], or null if unreachable. [blocked] cells are impassable.
  Direction? _bfsDirection(
    Point<int> start,
    Point<int> target,
    Set<Point<int>> blocked,
    int w,
    int h,
  ) {
    if (start.x == target.x && start.y == target.y) return null;
    final visited = <int>{};
    // Queue entries: (point, firstDirection)
    final queue = Queue<_BfsNode>();

    for (final d in Direction.values) {
      final next = _move(start, d);
      if (_outOfBounds(next, w, h)) continue;
      if (blocked.contains(next)) continue;
      if (next.x == target.x && next.y == target.y) return d;
      queue.add(_BfsNode(next, d));
      visited.add(next.x * 10000 + next.y);
    }

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      for (final d in Direction.values) {
        final next = _move(node.point, d);
        if (_outOfBounds(next, w, h)) continue;
        final key = next.x * 10000 + next.y;
        if (visited.contains(key)) continue;
        if (blocked.contains(next)) continue;
        if (next.x == target.x && next.y == target.y) return node.firstDir;
        visited.add(key);
        queue.add(_BfsNode(next, node.firstDir));
      }
    }
    return null; // unreachable
  }

  /// Returns BFS distance from [start] to [target], or -1 if unreachable.
  int _bfsDistance(
    Point<int> start,
    Point<int> target,
    Set<Point<int>> blocked,
    int w,
    int h,
  ) {
    if (start.x == target.x && start.y == target.y) return 0;
    final visited = <int>{};
    final queue = Queue<_BfsDistNode>();
    visited.add(start.x * 10000 + start.y);
    queue.add(_BfsDistNode(start, 0));

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      for (final d in Direction.values) {
        final next = _move(node.point, d);
        if (_outOfBounds(next, w, h)) continue;
        final key = next.x * 10000 + next.y;
        if (visited.contains(key)) continue;
        if (blocked.contains(next)) continue;
        if (next.x == target.x && next.y == target.y) return node.dist + 1;
        visited.add(key);
        queue.add(_BfsDistNode(next, node.dist + 1));
      }
    }
    return -1;
  }

  /// Check if [target] is reachable from [start] via BFS.
  bool _isReachable(
    Point<int> start,
    Point<int> target,
    Set<Point<int>> blocked,
    int w,
    int h,
  ) {
    return _bfsDistance(start, target, blocked, w, h) >= 0;
  }

  // ---------------------------------------------------------------------------
  // Flood fill — count reachable cells (uncapped for Expert, capped for others)
  // ---------------------------------------------------------------------------

  int _floodFill(Point<int> start, Set<Point<int>> blocked, int w, int h,
      {int cap = 999999}) {
    final visited = <int>{};
    final stack = <Point<int>>[start];
    int count = 0;
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final key = p.x * 10000 + p.y;
      if (visited.contains(key)) continue;
      if (p.x < 0 || p.x >= w || p.y < 0 || p.y >= h) continue;
      if (blocked.contains(p)) continue;
      visited.add(key);
      count++;
      if (count >= cap) return count;
      stack.add(Point(p.x + 1, p.y));
      stack.add(Point(p.x - 1, p.y));
      stack.add(Point(p.x, p.y + 1));
      stack.add(Point(p.x, p.y - 1));
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Easy: Random with 30% bad-move chance
  // ---------------------------------------------------------------------------

  Direction _decideEasy(
    List<Point<int>> segments,
    List<List<Point<int>>> others,
    List<Point<int>> food,
    int w, int h, bool wallsKill,
  ) {
    final cur = _currentDirection(segments);
    final safe = _safeDirs(segments, others, w, h, wallsKill);
    if (safe.isEmpty) return cur;

    if (_random.nextDouble() < 0.30) {
      final candidates =
          Direction.values.where((d) => !_isOpposite(d, cur)).toList();
      return candidates[_random.nextInt(candidates.length)];
    }
    return safe[_random.nextInt(safe.length)];
  }

  // ---------------------------------------------------------------------------
  // Medium: BFS to food, basic avoidance
  // ---------------------------------------------------------------------------

  Direction _decideMedium(
    List<Point<int>> segments,
    List<List<Point<int>>> others,
    List<Point<int>> food,
    int w, int h, bool wallsKill,
  ) {
    final cur = _currentDirection(segments);
    final head = segments.first;
    final safe = _safeDirs(segments, others, w, h, wallsKill);
    if (safe.isEmpty) return cur;

    // BFS to nearest food
    final blocked = _allOccupied(segments, others);
    blocked.remove(head);
    final target = _nearestFood(head, food);
    if (target != null) {
      final dir = _bfsDirection(head, target, blocked, w, h);
      if (dir != null && safe.contains(dir)) return dir;
    }

    // Fallback: prefer directions toward food by Manhattan distance
    if (target != null) {
      for (final d in safe) {
        final next = _move(head, d);
        if (_manhattan(next, target) < _manhattan(head, target)) return d;
      }
    }

    return safe[_random.nextInt(safe.length)];
  }

  // ---------------------------------------------------------------------------
  // Hard: BFS + 3-cell lookahead + cut-off
  // ---------------------------------------------------------------------------

  Direction _decideHard(
    List<Point<int>> segments,
    List<List<Point<int>>> others,
    List<Point<int>> food,
    int w, int h, bool wallsKill,
  ) {
    final cur = _currentDirection(segments);
    final head = segments.first;
    final safe = _safeDirs(segments, others, w, h, wallsKill);
    if (safe.isEmpty) return cur;

    final occupied = _allOccupied(segments, others);
    occupied.remove(head);

    int bestScore = -999999;
    Direction bestDir = safe.first;

    for (final d in safe) {
      int score = 0;
      final next = _move(head, d);

      // Look 3 cells ahead in same direction
      Point<int> probe = next;
      for (int step = 0; step < 3; step++) {
        probe = _move(probe, d);
        if (wallsKill && _outOfBounds(probe, w, h)) {
          score -= 50;
          break;
        }
        if (occupied.contains(probe)) {
          score -= 50;
          break;
        }
      }

      // BFS distance to food (better than Manhattan)
      final target = _nearestFood(next, food);
      if (target != null) {
        final dist = _bfsDistance(next, target, occupied, w, h);
        if (dist >= 0) {
          score += (100 - dist).clamp(0, 100);
        } else {
          score -= 30; // food unreachable from this direction
        }
      }

      // Cut-off bonus
      for (final other in others) {
        if (other.isEmpty) continue;
        final oppHead = other.first;
        final distToOpp = _manhattan(next, oppHead);
        if (distToOpp <= 3) score += (4 - distToOpp) * 10;
      }

      // Wall avoidance
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
  // Expert: BFS pathfinding + tail-reachability + flood fill + trapping
  //
  // Uses the Hawstein technique: after finding shortest path to food, simulate
  // the move and verify the tail is still reachable. If not, follow own tail
  // via longest path to buy time. Falls back to maximizing available space.
  // ---------------------------------------------------------------------------

  Direction _decideExpert(
    List<Point<int>> segments,
    List<List<Point<int>>> others,
    List<Point<int>> food,
    int w, int h, bool wallsKill,
  ) {
    final cur = _currentDirection(segments);
    final head = segments.first;
    final tail = segments.last;
    final safe = _safeDirs(segments, others, w, h, wallsKill);
    if (safe.isEmpty) return cur;

    final occupied = _allOccupied(segments, others);
    occupied.remove(head);

    // --- Strategy 1: Try BFS to food with tail-reachability check ---
    final target = _nearestFood(head, food);
    if (target != null) {
      final foodDir = _bfsDirection(head, target, occupied, w, h);
      if (foodDir != null && safe.contains(foodDir)) {
        // Simulate taking this step: head moves to next, tail pops
        final next = _move(head, foodDir);
        final simOccupied = Set<Point<int>>.from(occupied);
        simOccupied.add(next);
        // After moving, tail cell becomes free (unless we eat food)
        final willEat = next.x == target.x && next.y == target.y;
        if (!willEat) {
          simOccupied.remove(tail);
        }
        // Check: can we still reach our own tail from the new head?
        final tailTarget = willEat ? segments[segments.length - 1] : segments[segments.length - 2];
        if (_isReachable(next, tailTarget, simOccupied, w, h)) {
          // Safe to go for food — tail is reachable
          return foodDir;
        }
        // Food path exists but tail becomes unreachable — risky, skip
      }
    }

    // --- Strategy 2: Follow own tail (longest path / buy time) ---
    // Try to move toward tail while maximizing available space
    final tailDir = _bfsDirection(head, tail, occupied, w, h);

    // --- Strategy 3: Score all safe directions ---
    double bestScore = double.negativeInfinity;
    Direction bestDir = safe.first;

    for (final d in safe) {
      final next = _move(head, d);
      double score = 0;

      // Flood fill: available space (uncapped)
      final ffBlocked = Set<Point<int>>.from(occupied);
      ffBlocked.add(next);
      ffBlocked.remove(tail); // tail will move
      final space = _floodFill(next, ffBlocked, w, h);
      score += space * 3;

      // Severely penalize moves that trap us
      if (space < segments.length + 2) {
        score -= 500;
      }

      // Tail-following bonus: prefer directions toward our tail
      if (d == tailDir) {
        score += 80;
      }

      // BFS distance to food
      if (target != null) {
        final dist = _bfsDistance(next, target, occupied, w, h);
        if (dist >= 0) {
          score += (60 - dist).clamp(0, 60).toDouble();
        }
      }

      // Opponent trapping
      for (final other in others) {
        if (other.isEmpty) continue;
        final oppHead = other.first;
        final distToOpp = _manhattan(next, oppHead);

        if (distToOpp <= 2) {
          // Count opponent's safe moves
          int oppSafeMoves = 0;
          for (final od in Direction.values) {
            final op = _move(oppHead, od);
            if (!_outOfBounds(op, w, h) && !ffBlocked.contains(op)) {
              oppSafeMoves++;
            }
          }
          score += (4 - oppSafeMoves) * 30;
        }

        if (distToOpp <= 5) {
          score += (6 - distToOpp) * 5;
        }
      }

      // Wall avoidance
      if (next.x == 0 || next.x == w - 1) score -= 20;
      if (next.y == 0 || next.y == h - 1) score -= 20;

      // Center preference (slight)
      final centerDist = _manhattan(next, Point(w ~/ 2, h ~/ 2));
      score -= centerDist * 0.5;

      if (score > bestScore) {
        bestScore = score;
        bestDir = d;
      }
    }

    return bestDir;
  }
}

class _BfsNode {
  final Point<int> point;
  final Direction firstDir;
  _BfsNode(this.point, this.firstDir);
}

class _BfsDistNode {
  final Point<int> point;
  final int dist;
  _BfsDistNode(this.point, this.dist);
}
