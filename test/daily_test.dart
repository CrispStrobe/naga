import 'dart:collection';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/daily_game.dart';
import 'package:naga/game/game_registry.dart';
import 'package:naga/game/shared/daily_board.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/daily_mode.dart';
import 'package:naga/services/daily_service.dart';
import 'package:naga/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<DailyGame> start(DateTime date, {void Function()? onGameOver}) async {
  final game = DailyGame(
    mode: DailyMode(date),
    onGameOver: onGameOver ?? () {},
    onScoreChanged: (_) {},
  );
  game.onGameResize(Vector2(400, 560));
  await game.onLoad();
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the rock layout for a date is pinned', () {
    // Verified identical on the Dart VM and dart2js; a change here means
    // everyone's board for past and future dates changes too.
    final rocks = dailyRocks(seed: 20260924, width: 20, height: 28).toList()
      ..sort((a, b) => a.y != b.y ? a.y - b.y : a.x - b.x);
    expect(
      rocks.map((p) => '${p.x}:${p.y}').join(' '),
      '4:3 5:3 6:3 16:5 17:5 18:5 12:6 13:6 14:6 18:6 14:7 18:7 14:8 '
      '2:25 14:25 15:25 16:25 2:26',
    );
  });

  test('every layout keeps the start lane clear and the board connected', () {
    for (var day = 0; day < 366; day++) {
      final mode = DailyMode(DateTime(2026).add(Duration(days: day)));
      final rocks = dailyRocks(seed: mode.seed, width: 20, height: 28);
      expect(rocks, isNotEmpty, reason: '${mode.seed}');
      for (var x = 7; x <= 16; x++) {
        expect(rocks.contains(Point(x, 14)), isFalse, reason: '${mode.seed}');
      }
      final seen = <Point<int>>{const Point(10, 14)};
      final queue = Queue<Point<int>>.of(seen);
      while (queue.isNotEmpty) {
        final p = queue.removeFirst();
        for (final n in [Point(p.x + 1, p.y), Point(p.x - 1, p.y), Point(p.x, p.y + 1), Point(p.x, p.y - 1)]) {
          if (n.x < 0 || n.y < 0 || n.x >= 20 || n.y >= 28) continue;
          if (!rocks.contains(n) && seen.add(n)) queue.add(n);
        }
      }
      expect(seen.length, 20 * 28 - rocks.length, reason: '${mode.seed}');
    }
  });

  test('the same date gives the same board and food; another date differs',
      () async {
    final a = await start(DateTime(2026, 9, 24, 8));
    final b = await start(DateTime(2026, 9, 24, 23));
    final c = await start(DateTime(2026, 9, 25));
    expect(a.rocks, b.rocks);
    expect(a.food.gridPosition, b.food.gridPosition);
    expect(a.rocks, isNot(c.rocks));
    expect(a.rocks.contains(a.food.gridPosition), isFalse);
  });

  test('rocks kill', () async {
    var deaths = 0;
    final game = await start(DateTime(2026, 9, 24), onGameOver: () => deaths++);
    // Put the snake just left of a rock, heading right.
    final rock = game.rocks.firstWhere((r) => r.x >= 3 && !game.rocks.contains(Point(r.x - 1, r.y)) && !game.rocks.contains(Point(r.x - 2, r.y)) && !game.rocks.contains(Point(r.x - 3, r.y)));
    game.snake.segments
      ..clear()
      ..addAll([Point(rock.x - 1, rock.y), Point(rock.x - 2, rock.y), Point(rock.x - 3, rock.y)]);
    game.update(1);
    expect(deaths, 1);
    expect(game.gameState, GameState.gameOver);
  });

  test('the registry builds a fixed-rule Daily session without respawn', () {
    final session = GameRegistry.create(
      mode: DailyMode(DateTime(2026, 9, 24)),
      settings: const GameSettings(),
      onGameOver: () {},
      onVictory: () {},
      onScoreChanged: (_) {},
    );
    expect(session.game, isA<DailyGame>());
    expect(session.canRespawn, isFalse);
    expect(DailyMode(DateTime(2026)).fixedRules, isTrue);
    expect(DailyMode(DateTime(2026)).hasPowerUps, isFalse);
  });

  test('best score and streak across days', () async {
    SharedPreferences.setMockInitialValues({});
    final daily = await DailyService.instance();
    final d1 = DateTime(2026, 9, 24, 10);
    expect(daily.bestFor(d1), 0);
    expect(daily.streakOn(d1), 0);

    expect(await daily.recordRun(d1, 50), isTrue);
    expect(await daily.recordRun(d1, 30), isFalse);
    expect(await daily.recordRun(d1.add(const Duration(hours: 5)), 70), isTrue);
    expect(daily.bestFor(d1), 70);
    expect(daily.streakOn(d1), 1);

    final d2 = DateTime(2026, 9, 25, 9);
    expect(daily.bestFor(d2), 0, reason: 'a new day starts fresh');
    expect(daily.streakOn(d2), 1, reason: 'yesterday keeps the streak alive');
    await daily.recordRun(d2, 10);
    expect(daily.streakOn(d2), 2);

    final d4 = DateTime(2026, 9, 27);
    expect(daily.streakOn(d4), 0, reason: 'a missed day breaks it');
    await daily.recordRun(d4, 5);
    expect(daily.streakOn(d4), 1);
    expect(await daily.recordRun(d2, 999), isFalse, reason: 'past days are ignored');
  });
}
