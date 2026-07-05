import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'naga_logo.dart';
import 'snake_animation.dart';
import '../modes/classic_mode.dart';
import '../modes/arcade_mode.dart';
import '../modes/zen_mode.dart';
import '../modes/maze_mode.dart';
import '../modes/trail_mode.dart';
import '../modes/fangs_mode.dart';
import '../modes/venom_mode.dart';
import '../modes/pit_mode.dart';
import '../modes/swarm_mode.dart';
import '../modes/rush_mode.dart';
import '../modes/snake2_mode.dart';
import '../modes/ascii_mode.dart';
import '../modes/cga_mode.dart';
import '../modes/nibbles_mode.dart';
import '../modes/multiplayer_mode.dart';
import '../modes/dungeon_mode.dart';
import '../modes/vs_ai_mode.dart';
import '../modes/stampede_mode.dart';
import '../modes/naga_dive_mode.dart';
import '../modes/game_mode.dart';
import '../generated/l10n.dart';
import '../services/settings_service.dart';
import '../services/high_score_service.dart';
import '../services/audio_service.dart';
import 'game_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import 'high_scores_screen.dart';
import 'achievements_screen.dart';
import '../services/achievements_service.dart';

/// One selectable entry in the home menu (mode button or bottom-bar action).
class _MenuEntry {
  final String? section; // section header printed above this entry
  final String label;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isBottomBar;

  _MenuEntry({
    this.section,
    required this.label,
    this.description = '',
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.isBottomBar = false,
  });
}

class HomeScreen extends StatefulWidget {
  final SettingsService settingsService;
  final HighScoreService highScoreService;
  final AudioService audioService;
  final AchievementsService achievementsService;

  const HomeScreen({
    super.key,
    required this.settingsService,
    required this.highScoreService,
    required this.audioService,
    required this.achievementsService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _focusIndex = -1; // -1: nothing focused until first key press
  final FocusNode _focusNode = FocusNode();
  List<_MenuEntry> _entries = [];
  List<GlobalKey> _itemKeys = [];

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  List<_MenuEntry> _buildEntries(S s) {
    return [
      _MenuEntry(
        section: 'CLASSIC',
        label: s.classic,
        description: s.classicDesc,
        icon: Icons.phone_android,
        accentColor: const Color(0xFF558B2F),
        onTap: () => _startGame(context, ClassicMode()),
      ),
      _MenuEntry(
        label: s.arcade,
        description: s.arcadeDesc,
        icon: Icons.bolt,
        accentColor: const Color(0xFF00873E),
        onTap: () => _startGame(context, ArcadeMode()),
      ),
      _MenuEntry(
        label: s.zen,
        description: s.zenDesc,
        icon: Icons.spa,
        accentColor: const Color(0xFF5A4FB5),
        onTap: () => _startGame(context, ZenMode()),
      ),
      _MenuEntry(
        section: 'CROSSOVER',
        label: s.mazeHunter,
        description: s.mazeHunterDesc,
        icon: Icons.grid_view,
        accentColor: const Color(0xFFB07800),
        onTap: () => _startGame(context, MazeMode()),
      ),
      _MenuEntry(
        label: s.trail,
        description: s.trailDesc,
        icon: Icons.timeline,
        accentColor: const Color(0xFF00838F),
        onTap: () => _startGame(context, TrailMode()),
      ),
      _MenuEntry(
        label: s.fangs,
        description: s.fangsDesc,
        icon: Icons.sports_tennis,
        accentColor: const Color(0xFF9C27B0),
        onTap: () => _startGame(context, FangsMode()),
      ),
      _MenuEntry(
        label: s.venom,
        description: s.venomDesc,
        icon: Icons.local_fire_department,
        accentColor: const Color(0xFF33691E),
        onTap: () => _startGame(context, VenomMode()),
      ),
      _MenuEntry(
        section: 'ACTION',
        label: s.pit,
        description: s.pitDesc,
        icon: Icons.shield,
        accentColor: const Color(0xFFD84315),
        onTap: () => _startGame(context, PitMode()),
      ),
      _MenuEntry(
        label: s.swarm,
        description: s.swarmDesc,
        icon: Icons.bug_report,
        accentColor: const Color(0xFF2E7D32),
        onTap: () => _startGame(context, SwarmMode()),
      ),
      _MenuEntry(
        label: s.rush,
        description: s.rushDesc,
        icon: Icons.speed,
        accentColor: const Color(0xFFE65100),
        onTap: () => _startGame(context, RushMode()),
      ),
      _MenuEntry(
        section: 'LEGACY',
        label: s.snake2,
        description: s.snake2Desc,
        icon: Icons.phone_android,
        accentColor: const Color(0xFF558B2F),
        onTap: () => _startGame(context, Snake2Mode()),
      ),
      _MenuEntry(
        label: s.ascii,
        description: s.asciiDesc,
        icon: Icons.terminal,
        accentColor: const Color(0xFF008A00),
        onTap: () => _startGame(context, AsciiMode()),
      ),
      _MenuEntry(
        label: s.cga,
        description: s.cgaDesc,
        icon: Icons.desktop_windows,
        accentColor: const Color(0xFF006064),
        onTap: () => _startGame(context, CgaMode()),
      ),
      _MenuEntry(
        label: s.nibbles,
        description: s.nibblesDesc,
        icon: Icons.code,
        accentColor: const Color(0xFFB07800),
        onTap: () => _startGame(context, NibblesMode()),
      ),
      _MenuEntry(
        section: 'MINIGAMES',
        label: s.stampede,
        description: s.stampedeDesc,
        icon: Icons.directions_run,
        accentColor: const Color(0xFF689F38),
        onTap: () => _startGame(context, StampedeMode()),
      ),
      _MenuEntry(
        label: s.nagaDive,
        description: s.nagaDiveDesc,
        icon: Icons.water,
        accentColor: const Color(0xFF00838F),
        onTap: () => _startGame(context, NagaDiveMode()),
      ),
      _MenuEntry(
        section: 'ADVENTURE',
        label: s.dungeon,
        description: s.dungeonDesc,
        icon: Icons.castle,
        accentColor: const Color(0xFF8D6E63),
        onTap: () => _startGame(context, DungeonMode()),
      ),
      _MenuEntry(
        section: 'MULTIPLAYER',
        label: s.duel,
        description: s.duelDesc,
        icon: Icons.people,
        accentColor: const Color(0xFFD81B60),
        onTap: () => _startGame(context, MultiplayerMode()),
      ),
      _MenuEntry(
        label: s.vsAi,
        description: s.vsAiDesc,
        icon: Icons.smart_toy,
        accentColor: const Color(0xFFE64A19),
        onTap: () => _startGame(context, VsAiMode()),
      ),
      _MenuEntry(
        label: s.vsAiSplit,
        description: s.vsAiSplitDesc,
        icon: Icons.vertical_split,
        accentColor: const Color(0xFF2962FF),
        onTap: () => _startGame(context, VsAiSplitMode()),
      ),
      // Bottom bar actions — part of the keyboard focus order
      _MenuEntry(
        label: s.settings,
        icon: Icons.settings,
        accentColor: const Color(0xFF2E7D32),
        isBottomBar: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SettingsScreen(
              settingsService: widget.settingsService,
              audioService: widget.audioService,
              onLocaleChanged: () {
                context
                    .findAncestorStateOfType<NagaAppState>()
                    ?.rebuildForLocale();
              },
            ),
          ),
        ),
      ),
      _MenuEntry(
        label: s.highScores,
        icon: Icons.emoji_events,
        accentColor: const Color(0xFF2E7D32),
        isBottomBar: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HighScoresScreen(
              highScoreService: widget.highScoreService,
            ),
          ),
        ),
      ),
      _MenuEntry(
        label: 'Achievements',
        icon: Icons.military_tech,
        accentColor: const Color(0xFF2E7D32),
        isBottomBar: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AchievementsScreen(
              achievementsService: widget.achievementsService,
            ),
          ),
        ),
      ),
      _MenuEntry(
        label: s.about,
        icon: Icons.info_outline,
        accentColor: const Color(0xFF2E7D32),
        isBottomBar: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        ),
      ),
    ];
  }

  void _moveFocus(int delta) {
    setState(() {
      if (_focusIndex < 0) {
        _focusIndex = delta > 0 ? 0 : _entries.length - 1;
      } else {
        _focusIndex = (_focusIndex + delta) % _entries.length;
        if (_focusIndex < 0) _focusIndex += _entries.length;
      }
    });
    final ctx = _itemKeys[_focusIndex].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 120),
      );
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.select) &&
        event is KeyDownEvent) {
      if (_focusIndex >= 0 && _focusIndex < _entries.length) {
        _entries[_focusIndex].onTap();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    _entries = _buildEntries(s);
    if (_itemKeys.length != _entries.length) {
      _itemKeys = List.generate(_entries.length, (_) => GlobalKey());
    }
    if (_focusIndex >= _entries.length) _focusIndex = _entries.length - 1;

    final modeEntries =
        _entries.where((e) => !e.isBottomBar).toList(growable: false);
    final barEntries =
        _entries.where((e) => e.isBottomBar).toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), // bright meadow green-white
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(
                child: SnakeAnimation(),
              ),
              Column(
                children: [
                  const SizedBox(height: 32),
                  // Title — snake-tube logo matching the app icon
                  const NagaLogo(height: 100),
                  const SizedBox(height: 8),
                  Text(
                    s.tagline.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 8,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Scrollable mode list
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      children: [
                        for (int i = 0; i < modeEntries.length; i++) ...[
                          if (modeEntries[i].section != null)
                            _SectionHeader(label: modeEntries[i].section!)
                          else
                            const SizedBox(height: 10),
                          _ModeButton(
                            key: _itemKeys[i],
                            label: modeEntries[i].label,
                            description: modeEntries[i].description,
                            icon: modeEntries[i].icon,
                            accentColor: modeEntries[i].accentColor,
                            focused: _focusIndex == i,
                            onTap: modeEntries[i].onTap,
                          ),
                          if (i < modeEntries.length - 1 &&
                              modeEntries[i + 1].section != null)
                            const SizedBox(height: 20),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  // Bottom bar: Settings, High Scores, Achievements, About
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < barEntries.length; i++) ...[
                          if (i > 0) const SizedBox(width: 24),
                          _BottomBarButton(
                            key: _itemKeys[modeEntries.length + i],
                            icon: barEntries[i].icon,
                            label: barEntries[i].label,
                            focused:
                                _focusIndex == modeEntries.length + i,
                            onTap: barEntries[i].onTap,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, GameMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: mode,
          settingsService: widget.settingsService,
          highScoreService: widget.highScoreService,
          audioService: widget.audioService,
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool focused;
  final VoidCallback onTap;

  const _BottomBarButton({
    super.key,
    required this.icon,
    required this.label,
    this.focused = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: focused
              ? const Color(0xFF2E7D32).withOpacity(0.15)
              : Colors.transparent,
          border: Border.all(
            color: focused
                ? const Color(0xFF2E7D32)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF2E7D32), size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
          color: const Color(0xFFE65100), // warm orange
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color accentColor;
  final bool focused;
  final VoidCallback onTap;

  const _ModeButton({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.focused = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(
              color: accentColor.withOpacity(focused ? 1.0 : 0.6),
              width: focused ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            // Mostly-opaque light card so the row stays readable over the
            // animated habitat background (river, palms, …)
            gradient: LinearGradient(
              colors: [
                Color.lerp(Colors.white, accentColor, focused ? 0.30 : 0.16)!
                    .withOpacity(0.90),
                Color.lerp(Colors.white, accentColor, focused ? 0.16 : 0.06)!
                    .withOpacity(0.78),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 26),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: accentColor.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: accentColor.withOpacity(0.5), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
