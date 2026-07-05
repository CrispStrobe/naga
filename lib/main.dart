import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'generated/l10n.dart';
import 'services/settings_service.dart';
import 'services/high_score_service.dart';
import 'services/audio_service.dart';
import 'services/achievements_service.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  final settingsService = await SettingsService.instance();
  final highScoreService = await HighScoreService.instance();
  final audioService = await AudioService.instance();
  final achievementsService = await AchievementsService.instance();

  runApp(NagaApp(
    settingsService: settingsService,
    highScoreService: highScoreService,
    audioService: audioService,
    achievementsService: achievementsService,
  ));
}

class NagaApp extends StatelessWidget {
  final SettingsService settingsService;
  final HighScoreService highScoreService;
  final AudioService audioService;
  final AchievementsService achievementsService;

  const NagaApp({
    super.key,
    required this.settingsService,
    required this.highScoreService,
    required this.audioService,
    required this.achievementsService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naga',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'monospace',
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: HomeScreen(
        settingsService: settingsService,
        highScoreService: highScoreService,
        audioService: audioService,
        achievementsService: achievementsService,
      ),
    );
  }
}
