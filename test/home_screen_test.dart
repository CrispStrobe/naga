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

void main() {
  testWidgets('keyboard focus scrolls deep menu entries into view', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final (settings, scores, achievements) = (await tester.runAsync(() async => (
      await SettingsService.instance(),
      await HighScoreService.instance(),
      await AchievementsService.instance(),
    )))!;
    // Wide enough for the test font's square glyphs in the bottom bar; the
    // height is a phone's, which is what makes Territory start offscreen.
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
    await tester.pump(const Duration(milliseconds: 100));

    // Held-key speed: presses arrive faster than the scroll animation.
    // Entry 17 is Territory (Daily, 5 Classic, 5 Crossover, 6 Action).
    for (var i = 0; i < 17; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 10));
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final label = find.text('TERRITORY');
    expect(label, findsOneWidget);
    final rect = tester.getRect(label);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(844));
  });
}
