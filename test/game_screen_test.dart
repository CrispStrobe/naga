import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naga/game/maze_hunter_game.dart';
import 'package:naga/game/dungeon_game.dart';
import 'package:naga/game/snake_game.dart';
import 'package:naga/modes/maze_mode.dart';
import 'package:naga/modes/dungeon_mode.dart';
import 'package:naga/modes/game_mode.dart';
import 'package:naga/modes/classic_mode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/generated/l10n.dart';
import 'package:naga/modes/venom_mode.dart';
import 'package:naga/services/audio_service.dart';
import 'package:naga/services/high_score_service.dart';
import 'package:naga/services/settings_service.dart';
import 'package:naga/ui/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SettingsService settings;
late HighScoreService scores;

Future<FlameGame> _mountScreen(WidgetTester tester, GameMode mode) async {
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

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.instance();
    scores = await HighScoreService.instance();
    await settings.setControlType(ControlType.buttons);
  });
  for (final mode in [MazeMode(), ClassicMode(), DungeonMode()]) {
    testWidgets('${mode.name} P cannot resume behind UI pause overlay', (
      tester,
    ) async {
      final game = await _mountScreen(tester, mode);
      GameState state() => switch (game) {
        MazeHunterGame() => game.gameState,
        SnakeGame() => game.gameState,
        DungeonGame() => game.gameState,
        _ => throw StateError('Unexpected game'),
      };
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(state(), GameState.paused);
      expect(find.text('PAUSED'), findsOneWidget);
      await tester.tap(find.text('Tap to resume'));
      await tester.pump();
      expect(state(), GameState.playing);
      expect(find.text('PAUSED'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('Dungeon paused controls cannot spend arrows or take turns', (
    tester,
  ) async {
    final game = await _mountScreen(tester, DungeonMode()) as DungeonGame;
    game.arrows = 10;
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    final body = List.of(game.snakeSegments);
    final direction = game.currentDirection;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.tap(find.text('SHOOT'));
    await tester.pump();
    expect(game.arrows, 10);
    expect(game.snakeSegments, body);
    expect(game.currentDirection, direction);
    expect(find.text('PAUSED'), findsOneWidget);
    await tester.tap(find.text('Tap to resume'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(game.arrows, 9, reason: 'Keyboard focus must be restored on resume');
    await tester.tap(find.text('SHOOT'));
    expect(game.arrows, 8);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('Venom game screen builds and reads its game session', (
    WidgetTester tester,
  ) async {
    final highScores = scores;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: GameScreen(
          mode: VenomMode(),
          settingsService: settings,
          highScoreService: highScores,
          audioService: AudioService.silent(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(GameWidget<FlameGame>), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(AlertDialog, 'Venom'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
