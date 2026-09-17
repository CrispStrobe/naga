// Run from the repository root:
// flutter test --no-pub benchmark/ai_benchmark.dart --reporter expanded
// Native Flutter test/JIT microbenchmark, not web/WASM or whole-game FPS.
// Inputs and RNG are seeded; all fixture creation is outside timed regions.
// Reuses one brain per implementation/difficulty/grid, warms all paths, rotates
// measurement order, and prints five samples plus median microseconds/decision.
// Legacy preserves old bugs; corrected reference separates policy from storage.
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/components/snake_ai.dart';
import 'package:naga/game/snake_game.dart' show Direction;
import 'ai_legacy_reference.dart';
import 'ai_corrected_reference.dart';

typedef Decide =
    Direction Function(
      List<Point<int>>,
      List<List<Point<int>>>,
      List<Point<int>>,
      int,
      int,
      bool,
    );

class Fixture {
  final List<Point<int>> body;
  final List<List<Point<int>>> others;
  final List<Point<int>> food;
  Fixture(this.body, this.others, this.food);
}

List<Fixture> fixtures(int w, int h) {
  final random = Random(92417);
  return List.generate(24, (i) {
    final x = 4 + random.nextInt(w - 8);
    final y = 4 + random.nextInt(h - 8);
    final body = List.generate(5, (n) => Point(x - n, y));
    final used = body.toSet();
    final others = <List<Point<int>>>[];
    for (var j = 0; j < 3; j++) {
      final ox = random.nextInt(w);
      final oy = random.nextInt(h - 8);
      final other = <Point<int>>[];
      for (var n = 0; n < 8; n++) {
        final point = Point(ox, oy + n);
        if (used.add(point)) other.add(point);
      }
      others.add(other);
    }
    final food = <Point<int>>[];
    // Include fallback/flood-fill decisions, not just an empty arena food path.
    if (i % 4 != 0) {
      for (var j = 0; j < 2; j++) {
        Point<int> point;
        do {
          point = Point(random.nextInt(w), random.nextInt(h));
        } while (!used.add(point));
        food.add(point);
      }
    }
    return Fixture(body, others, food);
  });
}

int run(Decide decide, List<Fixture> cases, int w, int h, int repeats) {
  var checksum = 0;
  for (var i = 0; i < repeats; i++) {
    for (final f in cases) {
      checksum += decide(f.body, f.others, f.food, w, h, true).index;
    }
  }
  return checksum;
}

void main() {
  test(
    'reproducible AI before / corrected / optimized benchmark',
    () {
      const repetitions = 40;
      const rounds = 5;
      for (final size in [(20, 28), (40, 40)]) {
        final (w, h) = size;
        final cases = fixtures(w, h);
        for (final difficulty in AiDifficulty.values) {
          final legacy = LegacySnakeAI(
            difficulty: difficulty,
            random: Random(123),
          );
          final corrected = CorrectedSnakeAI(
            difficulty: difficulty,
            random: Random(123),
          );
          final optimized = SnakeAI(
            difficulty: difficulty,
            random: Random(123),
          );
          final brains = <Decide>[
            legacy.decideDirection,
            corrected.decideDirection,
            optimized.decideDirection,
          ];
          const names = ['legacy', 'corrected', 'optimized'];
          final samples = List.generate(3, (_) => <double>[]);
          final checksums = List.filled(3, 0);
          final changes = List.filled(2, 0);
          for (final f in cases) {
            final a = brains[0](f.body, f.others, f.food, w, h, true);
            final b = brains[1](f.body, f.others, f.food, w, h, true);
            final c = brains[2](f.body, f.others, f.food, w, h, true);
            if (a != c) changes[0]++;
            if (b != c) changes[1]++;
          }
          expect(
            changes[1],
            0,
            reason: 'optimization must preserve corrected policy',
          );
          for (final brain in brains) {
            run(brain, cases, w, h, 40);
          }
          for (var round = 0; round < rounds; round++) {
            for (var offset = 0; offset < 3; offset++) {
              final index = (round + offset) % 3;
              final timer = Stopwatch()..start();
              final checksum = run(brains[index], cases, w, h, repetitions);
              timer.stop();
              samples[index].add(
                timer.elapsedMicroseconds / (repetitions * cases.length),
              );
              checksums[index] += checksum;
            }
          }
          expect(checksums[1], checksums[2]);
          for (var i = 0; i < 3; i++) {
            final sorted = [...samples[i]]..sort();
            // ignore: avoid_print
            print(
              jsonEncode({
                'grid': '${w}x$h',
                'difficulty': difficulty.name,
                'implementation': names[i],
                'decisions_per_sample': repetitions * cases.length,
                'samples_us_per_decision': samples[i],
                'median_us_per_decision': sorted[rounds ~/ 2],
                'checksum': checksums[i],
                'legacy_decision_changes_out_of_24': changes[0],
                'corrected_decision_changes_out_of_24': changes[1],
              }),
            );
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
