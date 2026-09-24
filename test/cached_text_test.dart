import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/shared/cached_text.dart';

void main() {
  const style = TextStyle(fontSize: 12);

  test('reuses the painter while the span is unchanged', () {
    final cache = CachedText();
    final first = cache.painter('LVL 1', style);
    expect(identical(cache.painter('LVL 1', style), first), isTrue);
    cache.dispose();
  });

  test('re-lays out when text or style changes', () {
    final cache = CachedText();
    final first = cache.painter('LVL 1', style);
    final second = cache.painter('LVL 2', style);
    expect(identical(second, first), isFalse);
    final third = cache.painter('LVL 2', style.copyWith(fontSize: 14));
    expect(identical(third, second), isFalse);
    expect(third.height, greaterThan(0));
    cache.dispose();
  });

  test('list slots are stable per index', () {
    final list = CachedTextList();
    expect(identical(list[2], list[2]), isTrue);
    expect(identical(list[0], list[1]), isFalse);
    list.dispose();
  });
}
