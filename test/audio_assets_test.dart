import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naga/services/audio_service.dart';

void main() {
  test('every advertised music and sound asset exists under assets/', () {
    final paths = AudioService.assetPaths.toSet();
    expect(paths, hasLength(15));
    for (final path in paths) {
      expect(path, startsWith('audio/'));
      expect(File('assets/$path').existsSync(), isTrue, reason: path);
    }
    expect(paths, containsAll([
      AudioService.sfxEat,
      AudioService.sfxDie,
      AudioService.sfxPowerUp,
      AudioService.sfxLevelUp,
      AudioService.sfxClick,
    ]));
  });
}
