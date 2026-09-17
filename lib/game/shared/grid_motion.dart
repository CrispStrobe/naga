import 'dart:math';

/// Shared cardinal directions. Legacy game libraries re-export this type.
enum Direction { up, down, left, right }

Point<int> gridStep(Point<int> from, Direction direction) => switch (direction) {
  Direction.up => Point(from.x, from.y - 1),
  Direction.down => Point(from.x, from.y + 1),
  Direction.left => Point(from.x - 1, from.y),
  Direction.right => Point(from.x + 1, from.y),
};

bool areOpposite(Direction a, Direction b) =>
    (a == Direction.up && b == Direction.down) ||
    (a == Direction.down && b == Direction.up) ||
    (a == Direction.left && b == Direction.right) ||
    (a == Direction.right && b == Direction.left);

/// Wraps into a positive-size board, including negative coordinates.
Point<int> wrapGrid(Point<int> cell, int width, int height) =>
    Point(cell.x % width, cell.y % height);
