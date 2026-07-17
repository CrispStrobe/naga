import 'package:flutter_test/flutter_test.dart';
import 'package:naga/services/settings_service.dart';
import 'package:naga/services/high_score_service.dart';
import 'package:naga/services/audio_service.dart';
import 'package:naga/services/achievements_service.dart';
import 'package:naga/main.dart';
import 'package:naga/ui/naga_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    // Without mocked prefs the platform channel never answers in tests and
    // the service init below hangs until the 10-minute test timeout.
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.instance();
    final highScores = await HighScoreService.instance();
    // AudioService.instance() awaits audioplayers futures that never
    // complete under flutter_tester — use the muted test constructor.
    final audio = AudioService.silent();
    final achievements = await AchievementsService.instance();
    await tester.pumpWidget(NagaApp(
      settingsService: settings,
      highScoreService: highScores,
      audioService: audio,
      achievementsService: achievements,
    ));
    // The home screen background animation repeats forever, so
    // pumpAndSettle would never settle — pump a fixed duration instead.
    await tester.pump(const Duration(seconds: 1));
    // The title is custom-painted, not a Text widget
    expect(find.byType(NagaLogo), findsOneWidget);
  });
}
