import 'package:flutter/painting.dart';

/// A laid-out [TextPainter] that is rebuilt only when its span changes.
///
/// HUD text is painted every frame but changes rarely; text layout is far
/// more expensive than comparing spans, which [TextSpan] does by value.
class CachedText {
  TextPainter? _painter;
  InlineSpan? _span;

  TextPainter painterFor(InlineSpan span) {
    final painter = _painter;
    if (painter != null && _span == span) return painter;
    painter?.dispose();
    _span = span;
    return _painter = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();
  }

  /// Shorthand for a single-style span.
  TextPainter painter(String text, TextStyle style) =>
      painterFor(TextSpan(text: text, style: style));

  void dispose() {
    _painter?.dispose();
    _painter = null;
    _span = null;
  }
}

/// A growable set of [CachedText] slots for text drawn in a loop.
class CachedTextList {
  final List<CachedText> _slots = [];

  CachedText operator [](int index) {
    while (_slots.length <= index) {
      _slots.add(CachedText());
    }
    return _slots[index];
  }

  void dispose() {
    for (final slot in _slots) {
      slot.dispose();
    }
    _slots.clear();
  }
}
