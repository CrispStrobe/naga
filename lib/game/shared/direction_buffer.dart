import 'dart:collection';

import 'grid_motion.dart';

/// A full buffer differs from a forbidden turn: some modes still accelerate
/// their tick for a valid turn dropped at capacity.
enum DirectionInput { queued, rejected, full }

/// Pure bounded input FIFO. Modes own timing, pause, reversal and reset policy.
/// Validates against the last accepted input, not the last executed movement.
class DirectionBuffer extends IterableBase<Direction> {
  final int capacity;
  final Queue<Direction> _pending = Queue<Direction>();

  DirectionBuffer({required this.capacity}) {
    if (capacity < 1) throw ArgumentError.value(capacity, 'capacity');
  }

  @override
  Iterator<Direction> get iterator => _pending.iterator;
  @override
  int get length => _pending.length;

  DirectionInput enqueue(Direction direction, Direction current) {
    final previous = _pending.isEmpty ? current : _pending.last;
    if (direction == previous || areOpposite(direction, previous)) {
      return DirectionInput.rejected;
    }
    if (_pending.length == capacity) return DirectionInput.full;
    _pending.addLast(direction);
    return DirectionInput.queued;
  }

  void clear() => _pending.clear();

  /// Consume exactly one input per movement tick; empty means keep heading.
  Direction consume(Direction current) =>
      _pending.isEmpty ? current : _pending.removeFirst();
}
