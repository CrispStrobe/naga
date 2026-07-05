import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_de.dart';
import 'l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Naga'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'The Snake Game'**
  String get tagline;

  /// No description provided for @classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get classic;

  /// No description provided for @classicDesc.
  ///
  /// In en, this message translates to:
  /// **'Retro phone legacy'**
  String get classicDesc;

  /// No description provided for @arcade.
  ///
  /// In en, this message translates to:
  /// **'Arcade'**
  String get arcade;

  /// No description provided for @arcadeDesc.
  ///
  /// In en, this message translates to:
  /// **'Neon speed run'**
  String get arcadeDesc;

  /// No description provided for @zen.
  ///
  /// In en, this message translates to:
  /// **'Zen'**
  String get zen;

  /// No description provided for @zenDesc.
  ///
  /// In en, this message translates to:
  /// **'No death, just vibes'**
  String get zenDesc;

  /// No description provided for @mazeHunter.
  ///
  /// In en, this message translates to:
  /// **'Maze Hunter'**
  String get mazeHunter;

  /// No description provided for @mazeHunterDesc.
  ///
  /// In en, this message translates to:
  /// **'Pac-Man meets Snake'**
  String get mazeHunterDesc;

  /// No description provided for @trail.
  ///
  /// In en, this message translates to:
  /// **'Trail'**
  String get trail;

  /// No description provided for @trailDesc.
  ///
  /// In en, this message translates to:
  /// **'Tron light cycles'**
  String get trailDesc;

  /// No description provided for @fangs.
  ///
  /// In en, this message translates to:
  /// **'Fangs'**
  String get fangs;

  /// No description provided for @fangsDesc.
  ///
  /// In en, this message translates to:
  /// **'Breakout with a bite'**
  String get fangsDesc;

  /// No description provided for @venom.
  ///
  /// In en, this message translates to:
  /// **'Venom'**
  String get venom;

  /// No description provided for @venomDesc.
  ///
  /// In en, this message translates to:
  /// **'Bomb and blast'**
  String get venomDesc;

  /// No description provided for @pit.
  ///
  /// In en, this message translates to:
  /// **'Pit'**
  String get pit;

  /// No description provided for @pitDesc.
  ///
  /// In en, this message translates to:
  /// **'Last snake standing'**
  String get pitDesc;

  /// No description provided for @swarm.
  ///
  /// In en, this message translates to:
  /// **'Swarm'**
  String get swarm;

  /// No description provided for @swarmDesc.
  ///
  /// In en, this message translates to:
  /// **'Eat the invaders'**
  String get swarmDesc;

  /// No description provided for @rush.
  ///
  /// In en, this message translates to:
  /// **'Rush'**
  String get rush;

  /// No description provided for @rushDesc.
  ///
  /// In en, this message translates to:
  /// **'Endless auto-scroll'**
  String get rushDesc;

  /// No description provided for @snake2.
  ///
  /// In en, this message translates to:
  /// **'Snake II'**
  String get snake2;

  /// No description provided for @snake2Desc.
  ///
  /// In en, this message translates to:
  /// **'Maze levels & wrap-around'**
  String get snake2Desc;

  /// No description provided for @ascii.
  ///
  /// In en, this message translates to:
  /// **'ASCII'**
  String get ascii;

  /// No description provided for @asciiDesc.
  ///
  /// In en, this message translates to:
  /// **'Terminal text mode'**
  String get asciiDesc;

  /// No description provided for @cga.
  ///
  /// In en, this message translates to:
  /// **'CGA'**
  String get cga;

  /// No description provided for @cgaDesc.
  ///
  /// In en, this message translates to:
  /// **'4-color retro PC'**
  String get cgaDesc;

  /// No description provided for @nibbles.
  ///
  /// In en, this message translates to:
  /// **'Nibbles'**
  String get nibbles;

  /// No description provided for @nibblesDesc.
  ///
  /// In en, this message translates to:
  /// **'QBasic classic'**
  String get nibblesDesc;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @scoreValue.
  ///
  /// In en, this message translates to:
  /// **'SCORE: {value}'**
  String scoreValue(int value);

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'GAME OVER'**
  String get gameOver;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'PLAY AGAIN'**
  String get playAgain;

  /// No description provided for @backToMenu.
  ///
  /// In en, this message translates to:
  /// **'BACK TO MENU'**
  String get backToMenu;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @serviceProvider.
  ///
  /// In en, this message translates to:
  /// **'Service provider'**
  String get serviceProvider;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyText.
  ///
  /// In en, this message translates to:
  /// **'Naga runs entirely on-device. Your games, statistics and settings never leave your device — there is no account, no analytics and no contact with remote services.'**
  String get privacyText;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get disclaimer;

  /// No description provided for @disclaimerText.
  ///
  /// In en, this message translates to:
  /// **'Naga is provided \"as is\", without warranty of any kind. Use the app at your own discretion.'**
  String get disclaimerText;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @licenseText.
  ///
  /// In en, this message translates to:
  /// **'Naga is free software, distributed under the GNU Affero General Public License version 3 or later. As the sole copyright holder, the author additionally makes official binary distributions (e.g. via the Apple App Store and Google Play) available under those stores\' standard terms; this does not affect your rights to the source under AGPL-3.0.'**
  String get licenseText;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @highScore.
  ///
  /// In en, this message translates to:
  /// **'High Score'**
  String get highScore;

  /// No description provided for @highScoreValue.
  ///
  /// In en, this message translates to:
  /// **'HIGH SCORE: {value}'**
  String highScoreValue(int value);

  /// No description provided for @newHighScore.
  ///
  /// In en, this message translates to:
  /// **'New High Score!'**
  String get newHighScore;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @gridSize.
  ///
  /// In en, this message translates to:
  /// **'Grid Size'**
  String get gridSize;

  /// No description provided for @gridSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get gridSmall;

  /// No description provided for @gridMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get gridMedium;

  /// No description provided for @gridLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get gridLarge;

  /// No description provided for @wallBehavior.
  ///
  /// In en, this message translates to:
  /// **'Wall Behavior'**
  String get wallBehavior;

  /// No description provided for @wallDie.
  ///
  /// In en, this message translates to:
  /// **'Game Over'**
  String get wallDie;

  /// No description provided for @wallWrap.
  ///
  /// In en, this message translates to:
  /// **'Wrap Around'**
  String get wallWrap;

  /// No description provided for @lives.
  ///
  /// In en, this message translates to:
  /// **'Lives'**
  String get lives;

  /// No description provided for @livesNone.
  ///
  /// In en, this message translates to:
  /// **'None (instant death)'**
  String get livesNone;

  /// No description provided for @livesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} lives'**
  String livesCount(int count);

  /// No description provided for @livesRemaining.
  ///
  /// In en, this message translates to:
  /// **'LIVES: {count}'**
  String livesRemaining(int count);

  /// No description provided for @highScores.
  ///
  /// In en, this message translates to:
  /// **'High Scores'**
  String get highScores;

  /// No description provided for @noHighScores.
  ///
  /// In en, this message translates to:
  /// **'No high scores yet'**
  String get noHighScores;

  /// No description provided for @gameplay.
  ///
  /// In en, this message translates to:
  /// **'Gameplay'**
  String get gameplay;

  /// No description provided for @classicNote.
  ///
  /// In en, this message translates to:
  /// **'Classic mode always uses original retro rules'**
  String get classicNote;

  /// No description provided for @controls.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get controls;

  /// No description provided for @swipeControls.
  ///
  /// In en, this message translates to:
  /// **'Swipe'**
  String get swipeControls;

  /// No description provided for @buttonControls.
  ///
  /// In en, this message translates to:
  /// **'D-Pad Buttons'**
  String get buttonControls;

  /// No description provided for @controlsSwipeDesc.
  ///
  /// In en, this message translates to:
  /// **'Swipe to change direction'**
  String get controlsSwipeDesc;

  /// No description provided for @controlsButtonDesc.
  ///
  /// In en, this message translates to:
  /// **'On-screen directional buttons'**
  String get controlsButtonDesc;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get soundEffects;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @duel.
  ///
  /// In en, this message translates to:
  /// **'Duel'**
  String get duel;

  /// No description provided for @duelDesc.
  ///
  /// In en, this message translates to:
  /// **'Local 2-player'**
  String get duelDesc;

  /// No description provided for @player1Wins.
  ///
  /// In en, this message translates to:
  /// **'Player 1 Wins!'**
  String get player1Wins;

  /// No description provided for @player2Wins.
  ///
  /// In en, this message translates to:
  /// **'Player 2 Wins!'**
  String get player2Wins;

  /// No description provided for @draw.
  ///
  /// In en, this message translates to:
  /// **'Draw!'**
  String get draw;

  /// No description provided for @dungeon.
  ///
  /// In en, this message translates to:
  /// **'Dungeon'**
  String get dungeon;

  /// No description provided for @dungeonDesc.
  ///
  /// In en, this message translates to:
  /// **'Roguelike crawler'**
  String get dungeonDesc;

  /// No description provided for @vsAi.
  ///
  /// In en, this message translates to:
  /// **'VS AI'**
  String get vsAi;

  /// No description provided for @vsAiDesc.
  ///
  /// In en, this message translates to:
  /// **'Challenge the bots'**
  String get vsAiDesc;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hard;

  /// No description provided for @expert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get expert;

  /// No description provided for @startSpeed.
  ///
  /// In en, this message translates to:
  /// **'Start Speed'**
  String get startSpeed;

  /// No description provided for @crawl.
  ///
  /// In en, this message translates to:
  /// **'Crawl'**
  String get crawl;

  /// No description provided for @turtle.
  ///
  /// In en, this message translates to:
  /// **'Turtle'**
  String get turtle;

  /// No description provided for @slow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get slow;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @fast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get fast;

  /// No description provided for @insane.
  ///
  /// In en, this message translates to:
  /// **'Insane'**
  String get insane;

  /// No description provided for @aiOpponents.
  ///
  /// In en, this message translates to:
  /// **'AI Opponents'**
  String get aiOpponents;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return SDe();
    case 'en':
      return SEn();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
