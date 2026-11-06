import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/appearance_store.dart';
import 'package:sakuramedia/theme/app_theme_color.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

part 'appearance_providers.g.dart';

/// 外观偏好存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。
@Riverpod(keepAlive: true)
AppearanceStore appearanceStore(Ref ref) => InMemoryAppearanceStore();

/// 当前外观偏好（明暗模式 + 主题色），供 `MaterialApp` 与设置页读写。
@Riverpod(keepAlive: true)
class Appearance extends _$Appearance {
  @override
  AppearanceSettings build() => ref.watch(appearanceStoreProvider).read();

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (state.themeMode == themeMode) {
      return;
    }
    await _save(state.copyWith(themeMode: themeMode));
  }

  Future<void> setThemeColor(AppThemeColor themeColor) async {
    if (state.themeColor.id == themeColor.id) {
      return;
    }
    await _save(state.copyWith(themeColor: themeColor));
  }

  Future<void> setSurfaceStyle(AppSurfaceStyle surfaceStyle) async {
    if (state.surfaceStyle == surfaceStyle) {
      return;
    }
    await _save(state.copyWith(surfaceStyle: surfaceStyle));
  }

  Future<void> _save(AppearanceSettings settings) async {
    state = settings;
    await ref.read(appearanceStoreProvider).save(settings);
  }
}
