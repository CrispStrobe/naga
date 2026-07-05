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

class NagaApp extends StatefulWidget {
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
  State<NagaApp> createState() => NagaAppState();
}

class NagaAppState extends State<NagaApp> {
  void rebuildForLocale() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final localeCode = widget.settingsService.localeCode;
    return MaterialApp(
      title: 'Naga',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: localeCode != null ? Locale(localeCode) : null,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'monospace',
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: HomeScreen(
        settingsService: widget.settingsService,
        highScoreService: widget.highScoreService,
        audioService: widget.audioService,
        achievementsService: widget.achievementsService,
      ),
    );
  }
}
