// Run: flutter test benchmark/vs_ai_runtime_benchmark.dart --reporter expanded
// Measures real VsAiGame.update ticks, including decisions, movement, collision,
// food and round restarts. No rendering, loading, snapshots, or setup is timed.
// Flutter's test runner is JIT/debug: these are not web/release frame timings.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naga/modes/ai_difficulty.dart' show AiDifficulty;

import '../test/vs_ai_runtime_test.dart' as runtime;

void main() {
  test('real VS AI runtime benchmark', () {
    for (final split in [false, true]) {
      for (final difficulty in AiDifficulty.values) {
        for (final count in [1, 3]) {
          final warmup = runtime.createRuntimeGame(split, difficulty, count);
          for (var i = 0; i < 300; i++) {
            runtime.runtimeStep(warmup);
          }
          final samples = <double>[];
          var checksum = 2166136261;
          for (var sample = 0; sample < 7; sample++) {
            final game = runtime.createRuntimeGame(
              split,
              difficulty,
              count,
              seed: 991,
            );
            final watch = Stopwatch()..start();
            for (var i = 0; i < 500; i++) {
              runtime.runtimeStep(game);
            }
            watch.stop();
            samples.add(watch.elapsedMicroseconds / 500);
            // ignore: invalid_use_of_visible_for_testing_member
            checksum = runtime.digestState(checksum, game.debugSnapshot());
          }
          samples.sort();
          final key = '${split ? 'split' : 'shared'}/${difficulty.name}/$count';
          final baseline = legacyRuntimeBaseline[key]!;
          expect(checksum, baseline.$2, reason: '$key changed game behavior');
          // ignore: avoid_print
          print(
            jsonEncode({
              'arena': split ? 'split' : 'shared',
              'difficulty': difficulty.name,
              'opponents': count,
              'ticksPerSample': 500,
              'samples': 7,
              'medianUsPerTick': samples[3],
              'minUsPerTick': samples.first,
              'maxUsPerTick': samples.last,
              'checksum': checksum,
              'legacyMedianUsPerTick': baseline.$1,
              'speedupVsRecordedLegacy': baseline.$1 / samples[3],
            }),
          );
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

// Measured before replacing the real game's searches, on macOS with Flutter
// 3.44.4 / Dart 3.12.2 debug/JIT: seven 500-tick samples after 300 warmup ticks.
// Fixed historical numbers are informational, NOT a portable performance gate.
// Re-run the same harness on both revisions for controlled local comparisons.
const legacyRuntimeBaseline = <String, (double, int)>{
  'shared/easy/1': (381.62, 3650420252),
  'shared/easy/3': (773.752, 3199401669),
  'shared/medium/1': (489.266, 1421555040),
  'shared/medium/3': (1525.3, 3254402656),
  'shared/hard/1': (737.754, 1874780583),
  'shared/hard/3': (1616.756, 2708029145),
  'shared/expert/1': (509.836, 3828952967),
  'shared/expert/3': (1256.566, 4283383147),
  'split/easy/1': (249.034, 3377295909),
  'split/easy/3': (440.448, 146370771),
  'split/medium/1': (257.296, 2201159380),
  'split/medium/3': (380.948, 265820478),
  'split/hard/1': (276.106, 3548364755),
  'split/hard/3': (332.756, 1969576285),
  'split/expert/1': (283.784, 3713211884),
  'split/expert/3': (324.546, 82318060),
};
