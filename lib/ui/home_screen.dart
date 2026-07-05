import 'package:flutter/material.dart';
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

class HomeScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
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
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 24),
            // Scrollable mode list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                children: [
                  _SectionHeader(label: 'CLASSIC'),
                  _ModeButton(
                    label: s.classic,
                    description: s.classicDesc,
                    icon: Icons.phone_android,
                    accentColor: const Color(0xFF9BBC0F),
                    onTap: () => _startGame(context, ClassicMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.arcade,
                    description: s.arcadeDesc,
                    icon: Icons.bolt,
                    accentColor: const Color(0xFF00FF88),
                    onTap: () => _startGame(context, ArcadeMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.zen,
                    description: s.zenDesc,
                    icon: Icons.spa,
                    accentColor: const Color(0xFF7B68EE),
                    onTap: () => _startGame(context, ZenMode()),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'CROSSOVER'),
                  _ModeButton(
                    label: s.mazeHunter,
                    description: s.mazeHunterDesc,
                    icon: Icons.grid_view,
                    accentColor: const Color(0xFFFFFF00),
                    onTap: () => _startGame(context, MazeMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.trail,
                    description: s.trailDesc,
                    icon: Icons.timeline,
                    accentColor: const Color(0xFF00E5FF),
                    onTap: () => _startGame(context, TrailMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.fangs,
                    description: s.fangsDesc,
                    icon: Icons.sports_tennis,
                    accentColor: const Color(0xFFE040FB),
                    onTap: () => _startGame(context, FangsMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.venom,
                    description: s.venomDesc,
                    icon: Icons.local_fire_department,
                    accentColor: const Color(0xFF76FF03),
                    onTap: () => _startGame(context, VenomMode()),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'ACTION'),
                  _ModeButton(
                    label: s.pit,
                    description: s.pitDesc,
                    icon: Icons.shield,
                    accentColor: const Color(0xFFFF5252),
                    onTap: () => _startGame(context, PitMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.swarm,
                    description: s.swarmDesc,
                    icon: Icons.bug_report,
                    accentColor: const Color(0xFF00FF41),
                    onTap: () => _startGame(context, SwarmMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.rush,
                    description: s.rushDesc,
                    icon: Icons.speed,
                    accentColor: const Color(0xFFFF6F00),
                    onTap: () => _startGame(context, RushMode()),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'LEGACY'),
                  _ModeButton(
                    label: s.snake2,
                    description: s.snake2Desc,
                    icon: Icons.phone_android,
                    accentColor: const Color(0xFF9BBC0F),
                    onTap: () => _startGame(context, Snake2Mode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.ascii,
                    description: s.asciiDesc,
                    icon: Icons.terminal,
                    accentColor: const Color(0xFF00FF00),
                    onTap: () => _startGame(context, AsciiMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.cga,
                    description: s.cgaDesc,
                    icon: Icons.desktop_windows,
                    accentColor: const Color(0xFF00AAAA),
                    onTap: () => _startGame(context, CgaMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.nibbles,
                    description: s.nibblesDesc,
                    icon: Icons.code,
                    accentColor: const Color(0xFFFFFF00),
                    onTap: () => _startGame(context, NibblesMode()),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'MINIGAMES'),
                  _ModeButton(
                    label: s.stampede,
                    description: s.stampedeDesc,
                    icon: Icons.directions_run,
                    accentColor: const Color(0xFF8BC34A),
                    onTap: () => _startGame(context, StampedeMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.nagaDive,
                    description: s.nagaDiveDesc,
                    icon: Icons.water,
                    accentColor: const Color(0xFF00E5FF),
                    onTap: () => _startGame(context, NagaDiveMode()),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'ADVENTURE'),
                  _ModeButton(
                    label: s.dungeon,
                    description: s.dungeonDesc,
                    icon: Icons.castle,
                    accentColor: const Color(0xFFFF8A65),
                    onTap: () => _startGame(context, DungeonMode()),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'MULTIPLAYER'),
                  _ModeButton(
                    label: s.duel,
                    description: s.duelDesc,
                    icon: Icons.people,
                    accentColor: const Color(0xFFFF4081),
                    onTap: () => _startGame(context, MultiplayerMode()),
                  ),
                  const SizedBox(height: 10),
                  _ModeButton(
                    label: s.vsAi,
                    description: s.vsAiDesc,
                    icon: Icons.smart_toy,
                    accentColor: const Color(0xFFFF6E40),
                    onTap: () => _startGame(context, VsAiMode()),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Bottom bar: Settings, High Scores, About
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BottomBarButton(
                    icon: Icons.settings,
                    label: s.settings,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          settingsService: settingsService,
                          audioService: audioService,
                          onLocaleChanged: () {
                            context.findAncestorStateOfType<NagaAppState>()?.rebuildForLocale();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _BottomBarButton(
                    icon: Icons.emoji_events,
                    label: s.highScores,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HighScoresScreen(
                          highScoreService: highScoreService,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _BottomBarButton(
                    icon: Icons.military_tech,
                    label: 'Achievements',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AchievementsScreen(
                          achievementsService: achievementsService,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _BottomBarButton(
                    icon: Icons.info_outline,
                    label: s.about,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ],
          ),
      ),
    );
  }

  void _startGame(BuildContext context, GameMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: mode,
          settingsService: settingsService,
          highScoreService: highScoreService,
          audioService: audioService,
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.green.shade800, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.green.shade800,
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
          color: Colors.green.shade900,
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
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.accentColor,
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
              color: accentColor.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
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
                        color: accentColor.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: accentColor.withOpacity(0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
