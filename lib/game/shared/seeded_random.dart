import 'dart:math';

/// mulberry32: a small PRNG that yields the same sequence on the Dart VM,
/// dart2js and dart2wasm. `dart:math`'s seeded [Random] makes no such
/// promise across platforms or SDK versions, and a shared daily board needs
/// it. All arithmetic is masked to 32 bits and stays below 2^53.
class SeededRandom implements Random {
  int _state;

  SeededRandom(int seed) : _state = seed & _mask;

  static const int _mask = 0xFFFFFFFF;

  /// 32-bit multiply without exceeding 2^53 (safe on the web).
  static int _imul(int a, int b) {
    final ah = (a >>> 16) & 0xFFFF, al = a & 0xFFFF;
    final bh = (b >>> 16) & 0xFFFF, bl = b & 0xFFFF;
    final cross = ((ah * bl + al * bh) & 0xFFFF) << 16;
    return (al * bl + cross) & _mask;
  }

  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >>> 7), t | 61)) & _mask)) & _mask;
    return (t ^ (t >>> 14)) & _mask;
  }

  @override
  int nextInt(int max) {
    if (max <= 0 || max > 0x100000000) throw RangeError.range(max, 1, 0x100000000);
    return nextUint32() % max;
  }

  @override
  bool nextBool() => nextUint32() & 1 == 1;

  @override
  double nextDouble() => nextUint32() / 0x100000000;
}
