import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/game/dungeon_game.dart';
import 'package:naga/modes/dungeon_mode.dart';
import 'package:naga/generated/l10n.dart';
import 'package:naga/modes/classic_mode.dart';
import 'package:naga/modes/game_mode.dart';
import 'package:naga/modes/multiplayer_mode.dart';
import 'package:naga/services/audio_service.dart';
import 'package:naga/services/high_score_service.dart';
import 'package:naga/services/settings_service.dart';
import 'package:naga/ui/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// HighScoreService has a private constructor; implement its public boundary to
// hold persistence pending while exercising the real mounted screen callbacks.
class _PendingScores implements HighScoreService {
  final submissions = <Completer<bool>>[];

  @override
  int getHighScore(String modeName) => 0;

  @override
  Map<String, int> getAllHighScores() => {};

  @override
  Future<bool> submitScore(String modeName, int score) {
    final completion = Completer<bool>();
    submissions.add(completion);
    return completion.future;
  }
}

late SettingsService settings;

Future<FlameGame> _mountScreen(
  WidgetTester tester,
  GameMode mode,
  HighScoreService scores,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: GameScreen(
        mode: mode,
        settingsService: settings,
        highScoreService: scores,
        audioService: AudioService.silent(),
      ),
    ),
  );
  await tester.pump();
  final game = tester
      .widget<GameWidget<FlameGame>>(find.byType(GameWidget<FlameGame>))
      .game!;
  await tester.runAsync(() => game.loaded);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  return game;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.instance();
    await settings.setControlType(ControlType.buttons);
  });

  for (final mode in [ClassicMode(), DungeonMode()]) {
    testWidgets('${mode.name} background pause requires explicit resume', (
      tester,
    ) async {
      final game = await _mountScreen(tester, mode, _PendingScores());
      GameState state() => switch (game) {
        SnakeGame() => game.gameState,
        DungeonGame() => game.gameState,
        _ => throw StateError('Unexpected game'),
      };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);
      expect(state(), GameState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);
      expect(state(), GameState.paused);
      await tester.tap(find.text('Tap to resume'));
      await tester.pump();
      expect(state(), GameState.playing);
      await _unmount(tester);
    });
  }

  for (final background in [false, true]) {
    testWidgets(
      'Instructions preserve pause intent (background: $background)',
      (tester) async {
        final game =
            await _mountScreen(tester, ClassicMode(), _PendingScores())
                as SnakeGame;
        if (!background) {
          await tester.tap(find.byIcon(Icons.pause));
          await tester.pump();
        }
        await tester.tap(find.byIcon(Icons.info_outline));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        await tester.tap(find.text('OK'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('PAUSED'), findsOneWidget);
        expect(game.gameState, GameState.paused);
        await _unmount(tester);
      },
    );
  }

  testWidgets('Duel instructions match the real key bindings', (tester) async {
    await _mountScreen(tester, MultiplayerMode(), _PendingScores());
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(AlertDialog, 'Duel'), findsOneWidget);
    expect(
      find.textContaining('Player 1: WASD. Player 2: Arrow keys.'),
      findsOneWidget,
    );
    expect(find.textContaining('Player 1: Arrow keys'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await _unmount(tester);
  });

  testWidgets('Restart does not wait for persistence or accept stale results', (
    tester,
  ) async {
    final scores = _PendingScores();
    final game = await _mountScreen(tester, ClassicMode(), scores) as SnakeGame;
    final s = S.of(tester.element(find.byType(GameScreen)))!;
    game.onGameOver();
    await tester.pump();
    expect(find.text(s.playAgain), findsOneWidget);
    game.onGameOver();
    expect(
      scores.submissions,
      hasLength(1),
      reason: 'A match submits only once',
    );
    await tester.tap(find.text(s.playAgain));
    await tester.pump();
    scores.submissions.single.complete(true);
    await tester.pump();
    expect(find.text(s.playAgain), findsNothing);
    expect(find.text(s.newHighScore), findsNothing);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('Current match shows a completed high score', (tester) async {
    final scores = _PendingScores();
    final game = await _mountScreen(tester, ClassicMode(), scores) as SnakeGame;
    final s = S.of(tester.element(find.byType(GameScreen)))!;
    game.onGameOver();
    await tester.pump();
    expect(find.text(s.newHighScore), findsNothing);
    scores.submissions.single.complete(true);
    await tester.pump();
    expect(find.text(s.newHighScore), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  for (final dispose in [false, true]) {
    testWidgets('Score submission failure is safe (disposed: $dispose)', (
      tester,
    ) async {
      final scores = _PendingScores();
      final game =
          await _mountScreen(tester, ClassicMode(), scores) as SnakeGame;
      final s = S.of(tester.element(find.byType(GameScreen)))!;
      game.onGameOver();
      expect(scores.submissions, hasLength(1));
      if (dispose) await _unmount(tester);
      scores.submissions.single.completeError(StateError('Persistence failed'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (!dispose) {
        expect(find.text(s.playAgain), findsOneWidget);
        expect(find.text(s.newHighScore), findsNothing);
        await _unmount(tester);
      }
    });
  }

  testWidgets('Callbacks from a replaced match are ignored', (tester) async {
    final scores = _PendingScores();
    final game = await _mountScreen(tester, ClassicMode(), scores) as SnakeGame;
    final s = S.of(tester.element(find.byType(GameScreen)))!;
    game.onGameOver();
    await tester.pump();
    await tester.tap(find.text(s.playAgain));
    await tester.pump();
    scores.submissions.single.complete(true);
    await tester.pump();
    game.onGameOver();
    game.onScoreChanged(999);
    await tester.pump();
    expect(find.textContaining('999'), findsNothing);
    expect(
      find.text(s.newHighScore),
      findsNothing,
      reason: 'The new match has no result yet',
    );
    expect(
      scores.submissions,
      hasLength(1),
      reason: 'A callback from the replaced game cannot end the new match',
    );
    expect(find.text(s.playAgain), findsNothing);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('Score submission completion after disposal is ignored', (
    tester,
  ) async {
    final scores = _PendingScores();
    final game = await _mountScreen(tester, ClassicMode(), scores) as SnakeGame;
    game.onGameOver();
    expect(scores.submissions, hasLength(1));
    await _unmount(tester);
    scores.submissions.single.complete(true);
    await tester.pump();
    game.onScoreChanged(999);
    game.onGameOver();
    expect(scores.submissions, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
