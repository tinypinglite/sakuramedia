import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/theme/app_theme_color.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

/// 外观偏好：主题模式（跟随系统/浅色/深色） + 主题色 + 表面风格 + 窗口效果。
@immutable
class AppearanceSettings {
  const AppearanceSettings({
    required this.themeMode,
    required this.themeColor,
    this.surfaceStyle = AppSurfaceStyle.liquid,
    this.windowVibrancy = true,
  });

  static const AppearanceSettings defaults = AppearanceSettings(
    themeMode: ThemeMode.system,
    themeColor: AppThemeColor.crimson,
    surfaceStyle: AppSurfaceStyle.liquid,
    windowVibrancy: true,
  );

  final ThemeMode themeMode;
  final AppThemeColor themeColor;
  final AppSurfaceStyle surfaceStyle;

  /// macOS 窗口是否使用系统毛玻璃；独立于界面表面风格。
  final bool windowVibrancy;

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    AppThemeColor? themeColor,
    AppSurfaceStyle? surfaceStyle,
    bool? windowVibrancy,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      surfaceStyle: surfaceStyle ?? this.surfaceStyle,
      windowVibrancy: windowVibrancy ?? this.windowVibrancy,
    );
  }
}

/// 解析当前生效的明暗：跟随系统时取平台亮度，否则取显式模式。
Brightness effectiveBrightness(
  AppearanceSettings settings,
  Brightness platformBrightness,
) {
  return switch (settings.themeMode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => platformBrightness,
  };
}

abstract class AppearanceStore {
  AppearanceSettings read();
  Future<void> save(AppearanceSettings settings);
}

class SharedPreferencesAppearanceStore implements AppearanceStore {
  SharedPreferencesAppearanceStore(this._preferences);

  /// 历史 key 名保留；值域已扩展为 `system/light/dark`，老用户偏好不丢。
  static const String themeModeKey = 'appearance.brightness';
  static const String themeColorKey = 'appearance.theme_color';
  static const String surfaceStyleKey = 'appearance.surface_style';
  static const String windowVibrancyKey = 'appearance.window_vibrancy';

  final SharedPreferences _preferences;

  static Future<AppearanceStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesAppearanceStore(preferences);
  }

  @override
  AppearanceSettings read() {
    return AppearanceSettings(
      themeMode: _themeModeFromId(_preferences.getString(themeModeKey)),
      themeColor: AppThemeColor.fromId(_preferences.getString(themeColorKey)),
      surfaceStyle: _surfaceStyleFromId(
        _preferences.getString(surfaceStyleKey),
      ),
      windowVibrancy: _preferences.getBool(windowVibrancyKey) ?? true,
    );
  }

  @override
  Future<void> save(AppearanceSettings settings) async {
    try {
      await _preferences.setString(themeModeKey, settings.themeMode.name);
      await _preferences.setString(themeColorKey, settings.themeColor.id);
      await _preferences.setString(surfaceStyleKey, settings.surfaceStyle.name);
      await _preferences.setBool(windowVibrancyKey, settings.windowVibrancy);
    } catch (_) {
      // 持久化失败不阻塞切换。
    }
  }
}

ThemeMode _themeModeFromId(String? id) {
  return switch (id) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

AppSurfaceStyle _surfaceStyleFromId(String? id) {
  return switch (id) {
    'flat' => AppSurfaceStyle.flat,
    _ => AppSurfaceStyle.liquid,
  };
}

class InMemoryAppearanceStore implements AppearanceStore {
  InMemoryAppearanceStore([this._settings = AppearanceSettings.defaults]);

  AppearanceSettings _settings;

  @override
  AppearanceSettings read() => _settings;

  @override
  Future<void> save(AppearanceSettings settings) async {
    _settings = settings;
  }
}
