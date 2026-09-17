import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:naga/modes/ai_difficulty.dart' show AiDifficulty;
import 'package:naga/game/snake_game.dart' show Direction, GameState;
import 'package:naga/game/vs_ai_game.dart';
import 'package:naga/modes/vs_ai_mode.dart';

VsAiGame createRuntimeGame(
  bool split,
  AiDifficulty difficulty,
  int count, {
  int seed = 42,
}) => VsAiGame(
  mode: VsAiMode(),
  onGameOver: () {},
  onScoreChanged: (_) {},
  random: Random(seed),
  aiDifficulty: difficulty,
  aiCount: count,
  splitArena: split,
)..restart();

/// Deterministic external input, not a replacement AI. The player loops around
/// its left-hand lane; dead rounds restart with the same continuing RNG stream.
void runtimeStep(VsAiGame game) {
  if (game.gameState != GameState.playing) game.restart();
  final head = game.playerSegments.first;
  final right = game.splitArena ? game.gridWidth ~/ 2 - 2 : game.gridWidth - 3;
  if (game.currentDirection == Direction.right && head.x >= right) {
    game.changeDirection(Direction.up);
  } else if (game.currentDirection == Direction.up && head.y <= 2) {
    game.changeDirection(Direction.left);
  } else if (game.currentDirection == Direction.left && head.x <= 2) {
    game.changeDirection(Direction.down);
  } else if (game.currentDirection == Direction.down &&
      head.y >= game.gridHeight - 3) {
    game.changeDirection(Direction.right);
  }
  game.update(0.14);
}

// Stable 32-bit rolling digest (not Object.hash, which varies across runs).
int digestState(int hash, Object state) {
  for (final byte in utf8.encode(jsonEncode(state))) {
    hash = ((hash ^ byte) * 16777619) & 0xffffffff;
  }
  return hash;
}

void main() {
  test('seeded production games expose reproducible complete state', () {
    final first = createRuntimeGame(false, AiDifficulty.expert, 3);
    final second = createRuntimeGame(false, AiDifficulty.expert, 3);
    expect(first.debugSnapshot(), second.debugSnapshot());
    for (var i = 0; i < 50; i++) {
      runtimeStep(first);
      runtimeStep(second);
      expect(first.debugSnapshot(), second.debugSnapshot());
    }
  });

  for (final split in [false, true]) {
    test(
      '${split ? 'divider' : 'outer wall'} death fires once and restart resets',
      () {
        var deaths = 0;
        final scores = <int>[];
        final game = VsAiGame(
          mode: VsAiMode(),
          onGameOver: () => deaths++,
          onScoreChanged: scores.add,
          random: Random(7),
          splitArena: split,
        )..restart();
        final wallX = split ? game.gridWidth ~/ 2 : game.gridWidth;
        game.playerSegments = [Point(wallX - 1, 0)];
        game.currentDirection = Direction.right;
        game.update(0.14);
        expect(game.gameState, GameState.gameOver);
        expect(game.playerWon, false);
        expect(deaths, 1);
        final stopped = game.debugSnapshot();
        game.update(1);
        expect(game.debugSnapshot(), stopped);
        expect(deaths, 1);
        game.restart();
        expect(game.gameState, GameState.playing);
        expect(game.playerSegments.length, 3);
        expect(scores, [0, 0]);
      },
    );

    test('${split ? 'split' : 'shared'} food grows body and reports score', () {
      final scores = <int>[];
      final game = VsAiGame(
        mode: VsAiMode(),
        onGameOver: () {},
        onScoreChanged: scores.add,
        random: Random(42),
        splitArena: split,
      )..restart();
      final food = game.debugSnapshot()['food']! as List<int>;
      final fromLeft = food[0] > 0;
      game.playerSegments = [Point(food[0] + (fromLeft ? -1 : 1), food[1])];
      game.currentDirection = fromLeft ? Direction.right : Direction.left;
      game.update(0.14);
      expect(game.playerSegments.first, Point(food[0], food[1]));
      expect(game.playerSegments.length, 2);
      expect(game.score, 10);
      expect(scores, [0, 10]);
      expect(game.debugSnapshot()['food'], isNot(food));
    });
  }

  test('production tick traces match pre-optimization strategy', () {
    final actual = <String, int>{};
    for (final split in [false, true]) {
      for (final difficulty in AiDifficulty.values) {
        for (final count in [1, 2, 3]) {
          var hash = 2166136261;
          for (final seed in [7, 42, 991]) {
            final game = createRuntimeGame(
              split,
              difficulty,
              count,
              seed: seed,
            );
            hash = digestState(hash, game.debugSnapshot());
            for (var tick = 0; tick < 200; tick++) {
              runtimeStep(game);
              hash = digestState(hash, game.debugSnapshot());
            }
          }
          actual['${split ? 'split' : 'shared'}/${difficulty.name}/$count'] =
              hash;
        }
      }
    }
    expect(actual, legacyTraceDigests);
  });
}

// Recorded by executing the original VS AI brain (not components/SnakeAI),
// with only the RNG injection and detached snapshot seam added.
const legacyTraceDigests = <String, int>{
  'shared/easy/1': 3271716593,
  'shared/easy/2': 1065183348,
  'shared/easy/3': 1645161509,
  'shared/medium/1': 2920200421,
  'shared/medium/2': 159898315,
  'shared/medium/3': 2399337697,
  'shared/hard/1': 3326130021,
  'shared/hard/2': 69570034,
  'shared/hard/3': 3431189532,
  'shared/expert/1': 3933192953,
  'shared/expert/2': 1766077388,
  'shared/expert/3': 2081347290,
  'split/easy/1': 1024922977,
  'split/easy/2': 3257433523,
  'split/easy/3': 758133587,
  'split/medium/1': 2287638355,
  'split/medium/2': 2091470698,
  'split/medium/3': 1211359139,
  'split/hard/1': 2461982407,
  'split/hard/2': 3965182841,
  'split/hard/3': 3432814782,
  'split/expert/1': 896126841,
  'split/expert/2': 3379873844,
  'split/expert/3': 2477000098,
};
