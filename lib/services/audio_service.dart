import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages background music and sound effects for all game modes.
///
/// Music tracks are per-mode: each mode name maps to a music file.
/// SFX are shared across modes (eat, die, power-up, etc.).
///
/// Audio files go in assets/audio/music/ and assets/audio/sfx/.
/// Supported formats: mp3, ogg, wav.
class AudioService {
  static const _keyMusicEnabled = 'music_enabled';
  static const _keySfxEnabled = 'sfx_enabled';

  static AudioService? _instance;
  static Future<AudioService>? _pendingInit;

  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  String? _currentMusicTrack;

  // Per-mode music mapping
  static const Map<String, String> _modeMusic = {
    'Classic': 'music/classic.mp3',
    'Arcade': 'music/arcade.mp3',
    'Zen': 'music/zen.mp3',
    'Maze Hunter': 'music/maze.mp3',
    'Trail': 'music/trail.mp3',
    'Fangs': 'music/fangs.mp3',
    'Venom': 'music/venom.mp3',
    'Pit': 'music/pit.mp3',
    'Swarm': 'music/swarm.mp3',
    'Rush': 'music/rush.mp3',
  };

  // SFX names
  static const String sfxEat = 'sfx/eat.mp3';
  static const String sfxDie = 'sfx/die.mp3';
  static const String sfxPowerUp = 'sfx/powerup.mp3';
  static const String sfxLevelUp = 'sfx/levelup.mp3';
  static const String sfxClick = 'sfx/click.mp3';

  AudioService._();

  static Future<AudioService> instance() {
    _pendingInit ??= _createInstance();
    return _pendingInit!;
  }

  static Future<AudioService> _createInstance() async {
    final service = AudioService._();
    await service._init();
    _instance = service;
    return service;
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool(_keyMusicEnabled) ?? true;
    _sfxEnabled = prefs.getBool(_keySfxEnabled) ?? true;
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.4);
  }

  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMusicEnabled, enabled);
    if (!enabled) {
      await _musicPlayer.stop();
    } else if (_currentMusicTrack != null) {
      await playMusicForMode(_currentMusicTrack!);
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySfxEnabled, enabled);
  }

  /// Start playing background music for a game mode.
  Future<void> playMusicForMode(String modeName) async {
    _currentMusicTrack = modeName;
    if (!_musicEnabled) return;

    final track = _modeMusic[modeName];
    if (track == null) return;

    try {
      await _musicPlayer.stop();
      await _musicPlayer.play(AssetSource(track));
    } catch (_) {
      // Audio file might not exist yet — silently ignore
    }
  }

  /// Stop background music.
  Future<void> stopMusic() async {
    await _musicPlayer.stop();
    _currentMusicTrack = null;
  }

  /// Play a sound effect.
  Future<void> playSfx(String sfxPath) async {
    if (!_sfxEnabled) return;
    try {
      final player = AudioPlayer();
      await player.play(AssetSource(sfxPath));
      // Auto-dispose after playing
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {
      // Audio file might not exist yet — silently ignore
    }
  }

  /// Convenience methods
  Future<void> playEat() => playSfx(sfxEat);
  Future<void> playDie() => playSfx(sfxDie);
  Future<void> playPowerUp() => playSfx(sfxPowerUp);
  Future<void> playLevelUp() => playSfx(sfxLevelUp);
  Future<void> playClick() => playSfx(sfxClick);

  void dispose() {
    _musicPlayer.dispose();
  }
}
