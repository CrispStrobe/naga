import 'dart:collection';
import 'dart:math';

/// Head-first, indexed deque with reference-counted cell occupancy.
///
/// Head insertion, tail removal, indexing and [contains] are O(1) amortized.
/// It is a mutable List so legacy list edits also update occupancy. As with a
/// growable non-nullable Dart List, increasing [length] without values throws.
/// No board encoding is used: negative and arbitrarily wide cells stay distinct.
class GridSnakeBody extends ListBase<Point<int>> {
  List<Point<int>?> _buffer = List.filled(8, null);
  int _start = 0;
  int _length = 0;
  final Map<Point<int>, int> _counts = {};

  GridSnakeBody([Iterable<Point<int>> cells = const []]) {
    addAll(cells);
  }

  @override
  int get length => _length;

  @override
  set length(int value) {
    if (value < 0) throw RangeError.value(value, 'length');
    if (value > _length) {
      throw UnsupportedError('Cannot extend a non-nullable body without cells');
    }
    while (_length > value) {
      removeLast();
    }
  }

  int _slot(int index) => (_start + index) % _buffer.length;

  @override
  Point<int> operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', _length);
    return _buffer[_slot(index)]!;
  }

  @override
  void operator []=(int index, Point<int> cell) {
    final previous = this[index];
    _decrement(previous);
    _buffer[_slot(index)] = cell;
    _increment(cell);
  }

  void _increment(Point<int> cell) =>
      _counts.update(cell, (count) => count + 1, ifAbsent: () => 1);

  void _decrement(Point<int> cell) {
    final count = _counts[cell]!;
    if (count == 1) {
      _counts.remove(cell);
    } else {
      _counts[cell] = count - 1;
    }
  }

  void _ensureCapacity() {
    if (_length < _buffer.length) return;
    final next = List<Point<int>?>.filled(_buffer.length * 2, null);
    for (var i = 0; i < _length; i++) {
      next[i] = this[i];
    }
    _buffer = next;
    _start = 0;
  }

  @override
  bool contains(Object? element) => _counts.containsKey(element);

  @override
  void add(Point<int> element) {
    _ensureCapacity();
    _buffer[_slot(_length)] = element;
    _length++;
    _increment(element);
  }

  @override
  void addAll(Iterable<Point<int>> iterable) {
    // Snapshot permits addAll(this) and lazy views of this body.
    for (final cell in iterable.toList()) {
      add(cell);
    }
  }

  @override
  void insert(int index, Point<int> element) {
    RangeError.checkValueInInterval(index, 0, _length, 'index');
    if (index == 0) {
      _ensureCapacity();
      _start = (_start - 1) % _buffer.length;
      _buffer[_start] = element;
      _length++;
      _increment(element);
    } else if (index == _length) {
      add(element);
    } else {
      add(last);
      for (var i = _length - 2; i > index; i--) {
        this[i] = this[i - 1];
      }
      this[index] = element;
    }
  }

  @override
  void insertAll(int index, Iterable<Point<int>> iterable) {
    RangeError.checkValueInInterval(index, 0, _length, 'index');
    final cells = iterable.toList();
    for (var i = 0; i < cells.length; i++) {
      insert(index + i, cells[i]);
    }
  }

  @override
  Point<int> removeLast() {
    if (isEmpty) throw RangeError('Cannot remove from an empty body');
    final index = _slot(_length - 1);
    final cell = _buffer[index]!;
    _buffer[index] = null;
    _length--;
    _decrement(cell);
    return cell;
  }

  /// Commits movement only; collision, walls and growth rules belong to modes.
  void move(Point<int> head, {bool grow = false}) {
    insert(0, head);
    if (!grow) removeLast();
  }
}
