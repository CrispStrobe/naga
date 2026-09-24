import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naga/generated/l10n.dart';
import 'package:naga/services/achievements_service.dart';
import 'package:naga/services/audio_service.dart';
import 'package:naga/services/high_score_service.dart';
import 'package:naga/services/settings_service.dart';
import 'package:naga/ui/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mounts the home screen in a phone-height window.
Future<void> mountHome(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  // AudioService.silent() still constructs an AudioPlayer, and audioplayers
  // talks to channels (one per player, with a random id) that have no
  // plugin under flutter_tester. The MissingPluginExceptions arrive
  // asynchronously and would fail whichever test is running, so answer
  // every audioplayers message with success and pass the rest through.
  final messenger = tester.binding.defaultBinaryMessenger;
  final ok = const StandardMethodCodec().encodeSuccessEnvelope(null);
  messenger.allMessagesHandler = (channel, handler, message) =>
      channel.startsWith('xyz.luan/audioplayers')
          ? Future.value(ok)
          : handler?.call(message);
  addTearDown(() => messenger.allMessagesHandler = null);
  final (settings, scores, achievements) = (await tester.runAsync(() async => (
    await SettingsService.instance(),
    await HighScoreService.instance(),
    await AchievementsService.instance(),
  )))!;
  // Wide enough for the test font's square glyphs in the bottom bar; the
  // height is a phone's, so deep entries start offscreen.
  tester.view.physicalSize = const Size(900, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: HomeScreen(
      settingsService: settings,
      highScoreService: scores,
      audioService: AudioService.silent(),
      achievementsService: achievements,
    ),
  ));
  // Let the saved section state load. The background animation never
  // settles, so pump fixed frames instead of pumpAndSettle.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key, [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.sendKeyEvent(key);
    // Held-key speed: faster than the 120 ms scroll animation.
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void expectOnScreen(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(844));
}

void main() {
  testWidgets('a first launch opens only Daily and Classic', (tester) async {
    await mountHome(tester);
    expect(find.text('DAILY SERPENT'), findsOneWidget);
    expect(find.text('NIGHTFALL'), findsOneWidget);
    expect(find.text('MAZE HUNTER'), findsNothing);
    expect(find.text('TERRITORY'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Section ACTION, 6 modes, collapsed$')), findsOneWidget);
  });

  testWidgets('Enter on a section header toggles it, and it is remembered', (tester) async {
    await mountHome(tester);
    // Entries: DAILY header, Daily, CLASSIC header, 5 Classic modes, then the
    // collapsed CROSSOVER header at index 8.
    await press(tester, LogicalKeyboardKey.arrowDown, 9);
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('MAZE HUNTER'), findsOneWidget);
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    expect(prefs.getStringList('menu_collapsed_sections'), isNot(contains('CROSSOVER')));
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('MAZE HUNTER'), findsNothing);
  });

  testWidgets('keys pressed right after a toggle act on the new list', (tester) async {
    await mountHome(tester);
    // Enter on the collapsed CROSSOVER header (index 8), then at once Down
    // to its first mode and Enter, with no frame in between.
    await press(tester, LogicalKeyboardKey.arrowDown, 9);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Maze Hunter opened, not whatever sat at index 9 of the collapsed list
    // (the ACTION header).
    expect(find.text('MAZE HUNTER'), findsNothing, reason: 'left the menu');
    expect(find.bySemanticsLabel(RegExp(r'^Section ACTION')), findsNothing);
  });

  testWidgets('keyboard focus scrolls deep menu entries into view', (tester) async {
    // Everything open: the longest list, with Territory far below the fold.
    await mountHome(tester, prefs: {'flutter.menu_collapsed_sections': <String>[]});
    expect(find.text('TERRITORY'), findsOneWidget);
    // Headers are entries too: DAILY(0) Daily CLASSIC(2) +5, CROSSOVER(8) +5,
    // ACTION(14) Pit Swarm Rush Ouroboros Echo Territory(20).
    await press(tester, LogicalKeyboardKey.arrowDown, 21);
    await settle(tester);
    expectOnScreen(tester, find.text('TERRITORY'));
  });
}
