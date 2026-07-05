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

class GameSettings {
  final GridSize gridSize;
  final WallBehavior wallBehavior;
  final int lives;
  final ControlType controlType;

  const GameSettings({
    this.gridSize = GridSize.medium,
    this.wallBehavior = WallBehavior.die,
    this.lives = 0,
    this.controlType = ControlType.swipe,
  });

  GameSettings copyWith({
    GridSize? gridSize,
    WallBehavior? wallBehavior,
    int? lives,
    ControlType? controlType,
  }) {
    return GameSettings(
      gridSize: gridSize ?? this.gridSize,
      wallBehavior: wallBehavior ?? this.wallBehavior,
      lives: lives ?? this.lives,
      controlType: controlType ?? this.controlType,
    );
  }
}

class SettingsService {
  static const _keyGridSize = 'grid_size';
  static const _keyWallBehavior = 'wall_behavior';
  static const _keyLives = 'lives';
  static const _keyControlType = 'control_type';

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
}
