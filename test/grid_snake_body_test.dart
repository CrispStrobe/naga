import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/shared/grid_snake_body.dart';

void main() {
  test('ring wrap and capacity growth match a List over 4000 edits', () {
    final body = GridSnakeBody();
    final reference = <Point<int>>[];
    final random = Random(44);
    for (var i = 0; i < 4000; i++) {
      final p = Point(random.nextInt(12) - 6, random.nextInt(12) - 6);
      switch (random.nextInt(6)) {
        case 0:
          body.insert(0, p);
          reference.insert(0, p);
        case 1:
          body.add(p);
          reference.add(p);
        case 2:
          if (reference.isNotEmpty) {
            expect(body.removeLast(), reference.removeLast());
          }
        case 3:
          if (reference.isNotEmpty) {
            final index = random.nextInt(reference.length);
            body[index] = p;
            reference[index] = p;
          }
        case 4:
          final index = random.nextInt(reference.length + 1);
          body.insert(index, p);
          reference.insert(index, p);
        case 5:
          if (reference.isNotEmpty) {
            final index = random.nextInt(reference.length);
            expect(body.removeAt(index), reference.removeAt(index));
          }
      }
      expect(body, reference, reason: 'edit $i');
      for (final probe in [p, const Point(0, 0), const Point(-1, -1)]) {
        expect(body.contains(probe), reference.contains(probe));
      }
    }
  });

  test('growth, duplicate tails, reverse, lazy self edits and reset', () {
    final body = GridSnakeBody([const Point(10000, 0), const Point(0, 1)]);
    body.move(const Point(-1, -1), grow: true);
    expect(body.length, 3);
    body.add(body.last);
    body.removeLast();
    expect(body.contains(const Point(0, 1)), isTrue);
    final reversed = GridSnakeBody(body.reversed);
    expect(reversed, body.reversed.toList());
    reversed.move(const Point(1, 1));
    expect(reversed.contains(const Point(-1, -1)), isFalse);
    body.removeAt(0);
    body.removeLast();
    expect(body.contains(const Point(10000, 0)), isTrue);
    expect(body.contains(const Point(0, 1)), isFalse);
    body.addAll(body.reversed);
    expect(body.length, 2);
    body.insertAll(1, body.reversed);
    expect(body.length, 4);
    body.clear();
    body.add(const Point(7, 8));
    expect(body, [const Point(7, 8)]);
    expect(body.contains(const Point(10000, 0)), isFalse);
  });

  test('mutable List operations preserve order and occupancy', () {
    final body = GridSnakeBody([const Point(1, 1), const Point(2, 2)]);
    body.insertAll(1, [const Point(3, 3), const Point(3, 3)]);
    expect(body, [const Point(1, 1), const Point(3, 3), const Point(3, 3), const Point(2, 2)]);
    body.replaceRange(0, 1, [const Point(4, 4), const Point(5, 5)]);
    body.removeAt(2);
    expect(body.contains(const Point(3, 3)), isTrue);
    body.removeWhere((p) => p.x == 3);
    expect(body.contains(const Point(3, 3)), isFalse);
    body.setAll(0, [const Point(7, 7), const Point(7, 7)]);
    body.length = 1;
    expect(body, [const Point(7, 7)]);
    expect(body.contains(const Point(7, 7)), isTrue);
    expect(() => body.length = 3, throwsUnsupportedError);
    expect(() => body[-1], throwsRangeError);
    expect(() => body[body.length] = const Point(0, 0), throwsRangeError);
    body.clear();
    expect(body.contains(const Point(7, 7)), isFalse);
  });
  test('moving onto the departing tail keeps the new head occupied', () {
    final body = GridSnakeBody([const Point(1, 0), const Point(0, 0)]);
    body.move(const Point(0, 0));
    expect(body, [const Point(0, 0), const Point(1, 0)]);
    expect(body.contains(const Point(0, 0)), isTrue);
    body.move(const Point(0, 1));
    expect(body.contains(const Point(1, 0)), isFalse);
  });
}
