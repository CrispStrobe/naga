import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/shared/grid_motion.dart';

void main() {
  test('cardinal steps and reversal keep enum ordering', () {
    expect(Direction.values, [Direction.up, Direction.down, Direction.left, Direction.right]);
    expect(gridStep(const Point(2, 3), Direction.up), const Point(2, 2));
    expect(gridStep(const Point(2, 3), Direction.down), const Point(2, 4));
    expect(gridStep(const Point(2, 3), Direction.left), const Point(1, 3));
    expect(gridStep(const Point(2, 3), Direction.right), const Point(3, 3));
    expect(areOpposite(Direction.up, Direction.down), isTrue);
    expect(areOpposite(Direction.right, Direction.left), isTrue);
    expect(areOpposite(Direction.right, Direction.down), isFalse);
    expect(areOpposite(Direction.up, Direction.up), isFalse);
  });
  test('wrapping covers both seams, corners and multi-board offsets', () {
    expect(wrapGrid(const Point(-1, -1), 20, 28), const Point(19, 27));
    expect(wrapGrid(const Point(20, 28), 20, 28), const Point(0, 0));
    expect(wrapGrid(const Point(-41, 57), 20, 28), const Point(19, 1));
    expect(wrapGrid(const Point(2, 3), 20, 28), const Point(2, 3));
  });
}
