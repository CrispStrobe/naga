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

  static Future<AudioService>? _pendingInit;

  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  String? _currentMusicTrack;

  // SFX player pool — round-robin to avoid allocating per-sound
  static const int _sfxPoolSize = 4;
  final List<AudioPlayer> _sfxPool = [];
  int _sfxPoolIndex = 0;

  // Per-mode music mapping
  static const Map<String, String> _modeMusic = {
    'Classic': 'audio/music/classic.ogg',
    'Arcade': 'audio/music/arcade.ogg',
    'Zen': 'audio/music/zen.ogg',
    'Maze Hunter': 'audio/music/maze.ogg',
    'Trail': 'audio/music/trail.ogg',
    'Fangs': 'audio/music/fangs.ogg',
    'Venom': 'audio/music/venom.ogg',
    'Pit': 'audio/music/pit.ogg',
    'Swarm': 'audio/music/swarm.ogg',
    'Rush': 'audio/music/rush.ogg',
    'Snake II': 'audio/music/classic.ogg',
    'ASCII': 'audio/music/classic.ogg',
    'CGA': 'audio/music/arcade.ogg',
    'Nibbles': 'audio/music/arcade.ogg',
    'Duel': 'audio/music/pit.ogg',
    'Dungeon': 'audio/music/venom.ogg',
  };

  // SFX names
  static const String sfxEat = 'audio/sfx/eat.ogg';
  static const String sfxDie = 'audio/sfx/die.ogg';
  static const String sfxPowerUp = 'audio/sfx/powerup.ogg';
  static const String sfxLevelUp = 'audio/sfx/levelup.ogg';
  static const String sfxClick = 'audio/sfx/click.ogg';

  AudioService._();

  static Future<AudioService> instance() {
    _pendingInit ??= _createInstance();
    return _pendingInit!;
  }

  /// Test-only: a muted service that never touches audio platform channels
  /// (audioplayers futures never complete in the test environment).
  static AudioService silent() {
    final service = AudioService._();
    service._musicEnabled = false;
    service._sfxEnabled = false;
    return service;
  }

  static Future<AudioService> _createInstance() async {
    final service = AudioService._();
    await service._init();
    return service;
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool(_keyMusicEnabled) ?? true;
    _sfxEnabled = prefs.getBool(_keySfxEnabled) ?? true;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.4);
    } catch (_) {
      // audioplayers may not be fully supported on all platforms
    }
    // Initialize SFX player pool
    for (int i = 0; i < _sfxPoolSize; i++) {
      _sfxPool.add(AudioPlayer());
    }
    // Pre-load SFX assets so first play has no latency
    _preloadSfx();
  }

  Future<void> _preloadSfx() async {
    const sfxPaths = [sfxEat, sfxDie, sfxPowerUp, sfxLevelUp, sfxClick];
    for (final path in sfxPaths) {
      try {
        final player = AudioPlayer();
        await player.setSource(AssetSource(path));
        await player.dispose();
      } catch (_) {
        // File might not exist — skip
      }
    }
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

  /// Play a sound effect using pooled players.
  Future<void> playSfx(String sfxPath) async {
    if (!_sfxEnabled) return;
    try {
      final player = _sfxPool[_sfxPoolIndex];
      _sfxPoolIndex = (_sfxPoolIndex + 1) % _sfxPoolSize;
      await player.stop();
      await player.play(AssetSource(sfxPath));
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
    for (final player in _sfxPool) {
      player.dispose();
    }
  }
}
