import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final AudioService audioService;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.audioService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late GameSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsService.settings;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: Text(s.settings),
        backgroundColor: const Color(0xFF0A0A1A),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Grid Size
          _SectionTitle(label: s.gridSize),
          _buildGridSizeSelector(s),
          const SizedBox(height: 24),

          // Wall Behavior
          _SectionTitle(label: s.wallBehavior),
          _buildWallBehaviorSelector(s),
          const SizedBox(height: 24),

          // Lives
          _SectionTitle(label: s.lives),
          _buildLivesSelector(s),
          const SizedBox(height: 16),

          // Audio
          _SectionTitle(label: s.audio),
          _buildAudioToggles(s),
          const SizedBox(height: 24),

          // Difficulty
          _SectionTitle(label: s.difficulty),
          _buildDifficultySelector(s),
          const SizedBox(height: 24),

          // Start Speed
          _SectionTitle(label: s.startSpeed),
          _buildStartSpeedSelector(s),
          const SizedBox(height: 24),

          // Controls
          _SectionTitle(label: s.controls),
          _buildControlTypeSelector(s),
          const SizedBox(height: 24),

          // Classic mode note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.green.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.classicNote,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSizeSelector(S s) {
    final labels = {
      GridSize.small: s.gridSmall,
      GridSize.medium: s.gridMedium,
      GridSize.large: s.gridLarge,
    };
    final descriptions = {
      GridSize.small: '14 × 20',
      GridSize.medium: '20 × 28',
      GridSize.large: '26 × 36',
    };

    return Column(
      children: GridSize.values.map((size) {
        final selected = _settings.gridSize == size;
        return _OptionTile(
          label: labels[size]!,
          subtitle: descriptions[size]!,
          selected: selected,
          onTap: () async {
            await widget.settingsService.setGridSize(size);
            setState(() => _settings = widget.settingsService.settings);
          },
        );
      }).toList(),
    );
  }

  Widget _buildWallBehaviorSelector(S s) {
    return Column(
      children: [
        _OptionTile(
          label: s.wallDie,
          subtitle: '💀',
          selected: _settings.wallBehavior == WallBehavior.die,
          onTap: () async {
            await widget.settingsService.setWallBehavior(WallBehavior.die);
            setState(() => _settings = widget.settingsService.settings);
          },
        ),
        _OptionTile(
          label: s.wallWrap,
          subtitle: '🔄',
          selected: _settings.wallBehavior == WallBehavior.wrap,
          onTap: () async {
            await widget.settingsService.setWallBehavior(WallBehavior.wrap);
            setState(() => _settings = widget.settingsService.settings);
          },
        ),
      ],
    );
  }

  Widget _buildAudioToggles(S s) {
    return Column(
      children: [
        _OptionTile(
          label: s.music,
          subtitle: widget.audioService.musicEnabled ? s.on : s.off,
          selected: widget.audioService.musicEnabled,
          onTap: () async {
            await widget.audioService
                .setMusicEnabled(!widget.audioService.musicEnabled);
            setState(() {});
          },
        ),
        _OptionTile(
          label: s.soundEffects,
          subtitle: widget.audioService.sfxEnabled ? s.on : s.off,
          selected: widget.audioService.sfxEnabled,
          onTap: () async {
            await widget.audioService
                .setSfxEnabled(!widget.audioService.sfxEnabled);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildControlTypeSelector(S s) {
    return Column(
      children: [
        _OptionTile(
          label: s.swipeControls,
          subtitle: s.controlsSwipeDesc,
          selected: _settings.controlType == ControlType.swipe,
          onTap: () async {
            await widget.settingsService.setControlType(ControlType.swipe);
            setState(() => _settings = widget.settingsService.settings);
          },
        ),
        _OptionTile(
          label: s.buttonControls,
          subtitle: s.controlsButtonDesc,
          selected: _settings.controlType == ControlType.buttons,
          onTap: () async {
            await widget.settingsService.setControlType(ControlType.buttons);
            setState(() => _settings = widget.settingsService.settings);
          },
        ),
      ],
    );
  }

  Widget _buildDifficultySelector(S s) {
    final labels = {
      Difficulty.easy: s.easy,
      Difficulty.medium: s.medium,
      Difficulty.hard: s.hard,
      Difficulty.expert: s.expert,
    };

    return Column(
      children: Difficulty.values.map((d) {
        final selected = _settings.difficulty == d;
        return _OptionTile(
          label: labels[d]!,
          subtitle: '',
          selected: selected,
          onTap: () async {
            await widget.settingsService.setDifficulty(d);
            setState(() => _settings = widget.settingsService.settings);
          },
        );
      }).toList(),
    );
  }

  Widget _buildStartSpeedSelector(S s) {
    final labels = {
      StartSpeed.slow: s.slow,
      StartSpeed.normal: s.normal,
      StartSpeed.fast: s.fast,
      StartSpeed.insane: s.insane,
    };

    return Column(
      children: StartSpeed.values.map((sp) {
        final selected = _settings.startSpeed == sp;
        return _OptionTile(
          label: labels[sp]!,
          subtitle: '',
          selected: selected,
          onTap: () async {
            await widget.settingsService.setStartSpeed(sp);
            setState(() => _settings = widget.settingsService.settings);
          },
        );
      }).toList(),
    );
  }

  Widget _buildLivesSelector(S s) {
    return Column(
      children: [
        _OptionTile(
          label: s.livesNone,
          subtitle: '',
          selected: _settings.lives == 0,
          onTap: () async {
            await widget.settingsService.setLives(0);
            setState(() => _settings = widget.settingsService.settings);
          },
        ),
        ...List.generate(5, (i) {
          final count = i + 1;
          return _OptionTile(
            label: s.livesCount(count),
            subtitle: '❤️' * count,
            selected: _settings.lives == count,
            onTap: () async {
              await widget.settingsService.setLives(count);
              setState(() => _settings = widget.settingsService.settings);
            },
          );
        }),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
          color: Colors.green.shade500,
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Colors.green.shade400
                  : Colors.green.withOpacity(0.1),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: selected ? Colors.green.withOpacity(0.08) : null,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? Colors.green.shade400 : Colors.green.shade900,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.green.shade300
                        : Colors.green.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
