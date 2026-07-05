import 'package:shared_preferences/shared_preferences.dart';

enum GridSize {
  small(14, 20, 'Small'),
  medium(20, 28, 'Medium'),
  large(26, 36, 'Large');

  final int width;
  final int height;
  final String label;
  const GridSize(this.width, this.height, this.label);
}

enum WallBehavior {
  die,
  wrap;
}

enum ControlType {
  swipe,
  buttons;
}

enum Difficulty {
  easy,
  medium,
  hard,
  expert;
}

enum StartSpeed {
  slow(0.22, 'Slow'),
  normal(0.14, 'Normal'),
  fast(0.09, 'Fast'),
  insane(0.05, 'Insane');

  final double baseInterval;
  final String label;
  const StartSpeed(this.baseInterval, this.label);
}

class GameSettings {
  final GridSize gridSize;
  final WallBehavior wallBehavior;
  final int lives;
  final ControlType controlType;
  final Difficulty difficulty;
  final StartSpeed startSpeed;

  const GameSettings({
    this.gridSize = GridSize.medium,
    this.wallBehavior = WallBehavior.die,
    this.lives = 0,
    this.controlType = ControlType.swipe,
    this.difficulty = Difficulty.medium,
    this.startSpeed = StartSpeed.normal,
  });

  GameSettings copyWith({
    GridSize? gridSize,
    WallBehavior? wallBehavior,
    int? lives,
    ControlType? controlType,
    Difficulty? difficulty,
    StartSpeed? startSpeed,
  }) {
    return GameSettings(
      gridSize: gridSize ?? this.gridSize,
      wallBehavior: wallBehavior ?? this.wallBehavior,
      lives: lives ?? this.lives,
      controlType: controlType ?? this.controlType,
      difficulty: difficulty ?? this.difficulty,
      startSpeed: startSpeed ?? this.startSpeed,
    );
  }
}

class SettingsService {
  static const _keyGridSize = 'grid_size';
  static const _keyWallBehavior = 'wall_behavior';
  static const _keyLives = 'lives';
  static const _keyControlType = 'control_type';
  static const _keyDifficulty = 'difficulty';
  static const _keyStartSpeed = 'start_speed';

  static SettingsService? _instance;
  static Future<SettingsService>? _pendingInit;
  SharedPreferences? _prefs;
  GameSettings _settings = const GameSettings();

  SettingsService._();

  static Future<SettingsService> instance() {
    _pendingInit ??= _createInstance();
    return _pendingInit!;
  }

  static Future<SettingsService> _createInstance() async {
    final service = SettingsService._();
    await service._init();
    _instance = service;
    return service;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;

    final gridIndex = prefs.getInt(_keyGridSize) ?? 1;
    final wallIndex = prefs.getInt(_keyWallBehavior) ?? 0;
    final lives = prefs.getInt(_keyLives) ?? 0;
    final controlIndex = prefs.getInt(_keyControlType) ?? 0;
    final difficultyIndex = prefs.getInt(_keyDifficulty) ?? 1;
    final startSpeedIndex = prefs.getInt(_keyStartSpeed) ?? 1;

    _settings = GameSettings(
      gridSize: (gridIndex >= 0 && gridIndex < GridSize.values.length)
          ? GridSize.values[gridIndex]
          : GridSize.medium,
      wallBehavior: (wallIndex >= 0 && wallIndex < WallBehavior.values.length)
          ? WallBehavior.values[wallIndex]
          : WallBehavior.die,
      lives: lives.clamp(0, 5),
      controlType: (controlIndex >= 0 && controlIndex < ControlType.values.length)
          ? ControlType.values[controlIndex]
          : ControlType.swipe,
      difficulty: (difficultyIndex >= 0 && difficultyIndex < Difficulty.values.length)
          ? Difficulty.values[difficultyIndex]
          : Difficulty.medium,
      startSpeed: (startSpeedIndex >= 0 && startSpeedIndex < StartSpeed.values.length)
          ? StartSpeed.values[startSpeedIndex]
          : StartSpeed.normal,
    );
  }

  GameSettings get settings => _settings;

  Future<void> setGridSize(GridSize size) async {
    _settings = _settings.copyWith(gridSize: size);
    await _prefs!.setInt(_keyGridSize, size.index);
  }

  Future<void> setWallBehavior(WallBehavior behavior) async {
    _settings = _settings.copyWith(wallBehavior: behavior);
    await _prefs!.setInt(_keyWallBehavior, behavior.index);
  }

  Future<void> setLives(int lives) async {
    _settings = _settings.copyWith(lives: lives.clamp(0, 5));
    await _prefs!.setInt(_keyLives, lives.clamp(0, 5));
  }

  Future<void> setControlType(ControlType type) async {
    _settings = _settings.copyWith(controlType: type);
    await _prefs!.setInt(_keyControlType, type.index);
  }

  Future<void> setDifficulty(Difficulty difficulty) async {
    _settings = _settings.copyWith(difficulty: difficulty);
    await _prefs!.setInt(_keyDifficulty, difficulty.index);
  }

  Future<void> setStartSpeed(StartSpeed speed) async {
    _settings = _settings.copyWith(startSpeed: speed);
    await _prefs!.setInt(_keyStartSpeed, speed.index);
  }
}
