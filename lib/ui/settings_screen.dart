import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../generated/l10n.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final AudioService audioService;
  final VoidCallback? onLocaleChanged;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.audioService,
    this.onLocaleChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late GameSettings _settings;

  // Keyboard navigation: every option tile registers itself during build,
  // arrows move the focus, Space/Enter activates the focused tile.
  int _focusIndex = -1;
  final FocusNode _focusNode = FocusNode();
  final List<VoidCallback> _actions = [];
  final List<GlobalKey> _tileKeys = [];
  int _buildCounter = 0;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsService.settings;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Builds an option tile registered for keyboard navigation.
  Widget _tile({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final idx = _buildCounter++;
    while (_tileKeys.length <= idx) {
      _tileKeys.add(GlobalKey());
    }
    _actions.add(onTap);
    return _OptionTile(
      key: _tileKeys[idx],
      label: label,
      subtitle: subtitle,
      selected: selected,
      focused: _focusIndex == idx,
      onTap: onTap,
    );
  }

  void _moveFocus(int delta) {
    if (_actions.isEmpty) return;
    setState(() {
      if (_focusIndex < 0) {
        _focusIndex = delta > 0 ? 0 : _actions.length - 1;
      } else {
        _focusIndex = (_focusIndex + delta) % _actions.length;
        if (_focusIndex < 0) _focusIndex += _actions.length;
      }
    });
    final ctx = _tileKeys[_focusIndex].currentContext;
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
      if (_focusIndex >= 0 && _focusIndex < _actions.length) {
        _actions[_focusIndex]();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    _buildCounter = 0;
    _actions.clear();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text(s.settings, style: const TextStyle(color: Color(0xFF2E7D32))),
        backgroundColor: const Color(0xFFF1F8E9),
        iconTheme: const IconThemeData(color: Color(0xFF2E7D32)),
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          // Language
          _SectionTitle(label: s.language),
          _buildLanguageSelector(s),
          const SizedBox(height: 24),

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
              border: Border.all(color: const Color(0xFFA5D6A7)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.classicNote,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF388E3C),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(S s) {
    final current = widget.settingsService.localeCode;
    return Column(
      children: [
        _tile(
          label: 'System',
          subtitle: '',
          selected: current == null,
          onTap: () async {
            await widget.settingsService.setLocale(null);
            widget.onLocaleChanged?.call();
          },
        ),
        _tile(
          label: s.languageEnglish,
          subtitle: 'EN',
          selected: current == 'en',
          onTap: () async {
            await widget.settingsService.setLocale('en');
            widget.onLocaleChanged?.call();
          },
        ),
        _tile(
          label: s.languageGerman,
          subtitle: 'DE',
          selected: current == 'de',
          onTap: () async {
            await widget.settingsService.setLocale('de');
            widget.onLocaleChanged?.call();
          },
        ),
      ],
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
        return _tile(
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
        _tile(
          label: s.wallDie,
          subtitle: '💀',
          selected: _settings.wallBehavior == WallBehavior.die,
          onTap: () async {
            await widget.settingsService.setWallBehavior(WallBehavior.die);
            setState(() => _settings = widget.settingsService.settings);
          },
        ),
        _tile(
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
        _tile(
          label: s.music,
          subtitle: widget.audioService.musicEnabled ? s.on : s.off,
          selected: widget.audioService.musicEnabled,
          onTap: () async {
            await widget.audioService
                .setMusicEnabled(!widget.audioService.musicEnabled);
            setState(() {});
          },
        ),
        _tile(
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
        _tile(
          label: s.swipeControls,
          subtitle: s.controlsSwipeDesc,
          selected: _settings.controlType == ControlType.swipe,
          onTap: () async {
            await widget.settingsService.setControlType(ControlType.swipe);
            setState(() => _settings = widget.settingsService.settings);
          },
        ),
        _tile(
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
        return _tile(
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
      StartSpeed.crawl: s.crawl,
      StartSpeed.turtle: s.turtle,
      StartSpeed.slow: s.slow,
      StartSpeed.normal: s.normal,
      StartSpeed.fast: s.fast,
      StartSpeed.insane: s.insane,
    };

    return Column(
      children: StartSpeed.values.map((sp) {
        final selected = _settings.startSpeed == sp;
        return _tile(
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
        _tile(
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
          return _tile(
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
          color: const Color(0xFFE65100), // warm orange
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;

  const _OptionTile({
    super.key,
    required this.label,
    required this.subtitle,
    required this.selected,
    this.focused = false,
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
              color: focused
                  ? const Color(0xFFE65100)
                  : selected
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFA5D6A7),
              width: focused ? 2.5 : (selected ? 2 : 1),
            ),
            borderRadius: BorderRadius.circular(8),
            color: selected ? const Color(0xFFC8E6C9) : Colors.white.withOpacity(0.5),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: const Color(0xFFE65100).withOpacity(0.25),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF558B2F),
                    fontSize: 14,
                  ),
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: const Color(0xFF689F38),
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
