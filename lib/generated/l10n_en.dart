// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Naga';

  @override
  String get tagline => 'The Snake Game';

  @override
  String get classic => 'Classic';

  @override
  String get classicDesc => 'Retro phone legacy';

  @override
  String get arcade => 'Arcade';

  @override
  String get arcadeDesc => 'Neon speed run';

  @override
  String get zen => 'Zen';

  @override
  String get zenDesc => 'No death, just vibes';

  @override
  String get mazeHunter => 'Maze Hunter';

  @override
  String get mazeHunterDesc => 'Pac-Man meets Snake';

  @override
  String get trail => 'Trail';

  @override
  String get trailDesc => 'Tron light cycles';

  @override
  String get fangs => 'Fangs';

  @override
  String get fangsDesc => 'Breakout with a bite';

  @override
  String get venom => 'Venom';

  @override
  String get venomDesc => 'Bomb and blast';

  @override
  String get pit => 'Pit';

  @override
  String get pitDesc => 'Last snake standing';

  @override
  String get swarm => 'Swarm';

  @override
  String get swarmDesc => 'Eat the invaders';

  @override
  String get rush => 'Rush';

  @override
  String get rushDesc => 'Endless auto-scroll';

  @override
  String get snake2 => 'Snake II';

  @override
  String get snake2Desc => 'Maze levels & wrap-around';

  @override
  String get ascii => 'ASCII';

  @override
  String get asciiDesc => 'Terminal text mode';

  @override
  String get cga => 'CGA';

  @override
  String get cgaDesc => '4-color retro PC';

  @override
  String get nibbles => 'Nibbles';

  @override
  String get nibblesDesc => 'QBasic classic';

  @override
  String get score => 'Score';

  @override
  String scoreValue(int value) {
    return 'SCORE: $value';
  }

  @override
  String get gameOver => 'GAME OVER';

  @override
  String get playAgain => 'PLAY AGAIN';

  @override
  String get backToMenu => 'BACK TO MENU';

  @override
  String get about => 'About';

  @override
  String get serviceProvider => 'Service provider';

  @override
  String get contact => 'Contact';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyText =>
      'Naga runs entirely on-device. Your games, statistics and settings never leave your device — there is no account, no analytics and no contact with remote services.';

  @override
  String get disclaimer => 'Disclaimer';

  @override
  String get disclaimerText =>
      'Naga is provided \"as is\", without warranty of any kind. Use the app at your own discretion.';

  @override
  String get license => 'License';

  @override
  String get licenseText =>
      'Naga is free software, distributed under the GNU Affero General Public License version 3 or later. As the sole copyright holder, the author additionally makes official binary distributions (e.g. via the Apple App Store and Google Play) available under those stores\' standard terms; this does not affect your rights to the source under AGPL-3.0.';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get highScore => 'High Score';

  @override
  String highScoreValue(int value) {
    return 'HIGH SCORE: $value';
  }

  @override
  String get newHighScore => 'New High Score!';

  @override
  String get version => 'Version';

  @override
  String get gridSize => 'Grid Size';

  @override
  String get gridSmall => 'Small';

  @override
  String get gridMedium => 'Medium';

  @override
  String get gridLarge => 'Large';

  @override
  String get wallBehavior => 'Wall Behavior';

  @override
  String get wallDie => 'Game Over';

  @override
  String get wallWrap => 'Wrap Around';

  @override
  String get lives => 'Lives';

  @override
  String get livesNone => 'None (instant death)';

  @override
  String livesCount(int count) {
    return '$count lives';
  }

  @override
  String livesRemaining(int count) {
    return 'LIVES: $count';
  }

  @override
  String get highScores => 'High Scores';

  @override
  String get noHighScores => 'No high scores yet';

  @override
  String get gameplay => 'Gameplay';

  @override
  String get classicNote => 'Classic mode always uses original retro rules';

  @override
  String get controls => 'Controls';

  @override
  String get swipeControls => 'Swipe';

  @override
  String get buttonControls => 'D-Pad Buttons';

  @override
  String get controlsSwipeDesc => 'Swipe to change direction';

  @override
  String get controlsButtonDesc => 'On-screen directional buttons';

  @override
  String get audio => 'Audio';

  @override
  String get music => 'Music';

  @override
  String get soundEffects => 'Sound Effects';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get duel => 'Duel';

  @override
  String get duelDesc => 'Local 2-player';

  @override
  String get player1Wins => 'Player 1 Wins!';

  @override
  String get player2Wins => 'Player 2 Wins!';

  @override
  String get draw => 'Draw!';

  @override
  String get dungeon => 'Dungeon';

  @override
  String get dungeonDesc => 'Roguelike crawler';

  @override
  String get vsAi => 'VS AI';

  @override
  String get vsAiDesc => 'Challenge the bots';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get easy => 'Easy';

  @override
  String get medium => 'Medium';

  @override
  String get hard => 'Hard';

  @override
  String get expert => 'Expert';

  @override
  String get startSpeed => 'Start Speed';

  @override
  String get crawl => 'Crawl';

  @override
  String get turtle => 'Turtle';

  @override
  String get slow => 'Slow';

  @override
  String get normal => 'Normal';

  @override
  String get fast => 'Fast';

  @override
  String get insane => 'Insane';

  @override
  String get aiOpponents => 'AI Opponents';

  @override
  String get stampede => 'Stampede';

  @override
  String get stampedeDesc => 'Animal race track';

  @override
  String get nagaDive => 'Naga Dive';

  @override
  String get nagaDiveDesc => 'Underwater swim';

  @override
  String get vsAiSplit => 'VS AI Split';

  @override
  String get vsAiSplitDesc => 'Separate lanes duel';

  @override
  String get gameOverQuip1 => 'Even a Naga must watch where it slithers!';

  @override
  String get gameOverQuip2 => 'The jungle claims another tail…';

  @override
  String get gameOverQuip3 => 'Ouch! Right on the fangs.';

  @override
  String get gameOverQuip4 => 'That apple was SO worth it.';

  @override
  String get gameOverQuip5 => 'Shed your skin and try again!';

  @override
  String get gameOverQuip6 =>
      'A wise serpent naps after a feast. You… crashed.';

  @override
  String get gameOverQuip7 => 'The river spirits saw everything.';

  @override
  String get gameOverQuip8 => 'Knotted! Try slithering, not tangling.';
}
