// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class SDe extends S {
  SDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Naga';

  @override
  String get tagline => 'Das Schlangenspiel';

  @override
  String get classic => 'Klassisch';

  @override
  String get classicDesc => 'Nokia Retro-Modus';

  @override
  String get arcade => 'Arcade';

  @override
  String get arcadeDesc => 'Neon-Geschwindigkeitsrausch';

  @override
  String get zen => 'Zen';

  @override
  String get zenDesc => 'Kein Tod, nur Stimmung';

  @override
  String get mazeHunter => 'Labyrinth-Jäger';

  @override
  String get mazeHunterDesc => 'Pac-Man trifft Snake';

  @override
  String get trail => 'Lichtspur';

  @override
  String get trailDesc => 'Tron Lichtrennen';

  @override
  String get fangs => 'Fangzähne';

  @override
  String get fangsDesc => 'Breakout mit Biss';

  @override
  String get venom => 'Gift';

  @override
  String get venomDesc => 'Bomben und Explosionen';

  @override
  String get pit => 'Arena';

  @override
  String get pitDesc => 'Die letzte Schlange gewinnt';

  @override
  String get swarm => 'Schwarm';

  @override
  String get swarmDesc => 'Fress die Eindringlinge';

  @override
  String get rush => 'Rausch';

  @override
  String get rushDesc => 'Endlos-Autoscroll';

  @override
  String get score => 'Punkte';

  @override
  String scoreValue(int value) {
    return 'PUNKTE: $value';
  }

  @override
  String get gameOver => 'SPIEL VORBEI';

  @override
  String get playAgain => 'NOCHMAL SPIELEN';

  @override
  String get backToMenu => 'ZURÜCK ZUM MENÜ';

  @override
  String get about => 'Über';

  @override
  String get serviceProvider => 'Dienstanbieter';

  @override
  String get contact => 'Kontakt';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get privacyText =>
      'Naga läuft vollständig auf dem Gerät. Deine Spiele, Statistiken und Einstellungen verlassen niemals dein Gerät — es gibt kein Konto, keine Analyse und keinen Kontakt mit externen Diensten.';

  @override
  String get disclaimer => 'Haftungsausschluss';

  @override
  String get disclaimerText =>
      'Naga wird ohne jegliche Gewährleistung bereitgestellt. Die Nutzung erfolgt auf eigene Verantwortung.';

  @override
  String get license => 'Lizenz';

  @override
  String get licenseText =>
      'Naga ist freie Software und wird unter der GNU Affero General Public License Version 3 oder neuer verteilt. Als alleiniger Urheberrechtsinhaber stellt der Autor offizielle Binärdistributionen (z. B. über den Apple App Store und Google Play) zusätzlich unter den Standardbedingungen dieser Stores zur Verfügung; dies berührt nicht Ihre Rechte an der Quelle unter AGPL-3.0.';

  @override
  String get openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get language => 'Sprache';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get highScore => 'Highscore';

  @override
  String highScoreValue(int value) {
    return 'HIGHSCORE: $value';
  }

  @override
  String get newHighScore => 'Neuer Highscore!';

  @override
  String get version => 'Version';

  @override
  String get gridSize => 'Spielfeldgröße';

  @override
  String get gridSmall => 'Klein';

  @override
  String get gridMedium => 'Mittel';

  @override
  String get gridLarge => 'Groß';

  @override
  String get wallBehavior => 'Wandverhalten';

  @override
  String get wallDie => 'Spiel vorbei';

  @override
  String get wallWrap => 'Andere Seite';

  @override
  String get lives => 'Leben';

  @override
  String get livesNone => 'Keine (sofortiger Tod)';

  @override
  String livesCount(int count) {
    return '$count Leben';
  }

  @override
  String livesRemaining(int count) {
    return 'LEBEN: $count';
  }

  @override
  String get highScores => 'Highscores';

  @override
  String get noHighScores => 'Noch keine Highscores';

  @override
  String get gameplay => 'Spielablauf';

  @override
  String get classicNote =>
      'Klassisch-Modus nutzt immer die original Nokia-Regeln';

  @override
  String get controls => 'Steuerung';

  @override
  String get swipeControls => 'Wischen';

  @override
  String get buttonControls => 'D-Pad Tasten';

  @override
  String get controlsSwipeDesc => 'Wischen zum Richtungswechsel';

  @override
  String get controlsButtonDesc => 'Richtungstasten auf dem Bildschirm';

  @override
  String get audio => 'Audio';

  @override
  String get music => 'Musik';

  @override
  String get soundEffects => 'Soundeffekte';

  @override
  String get on => 'An';

  @override
  String get off => 'Aus';
}
