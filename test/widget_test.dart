import 'package:flutter_test/flutter_test.dart';
import 'package:naga/services/settings_service.dart';
import 'package:naga/services/high_score_service.dart';
import 'package:naga/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    final settings = await SettingsService.instance();
    final highScores = await HighScoreService.instance();
    await tester.pumpWidget(NagaApp(
      settingsService: settings,
      highScoreService: highScores,
    ));
    await tester.pumpAndSettle();
    expect(find.text('NAGA'), findsOneWidget);
  });
}
