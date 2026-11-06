import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sakuramedia/app/appearance_store.dart';
import 'package:sakuramedia/app/providers/appearance_providers.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认外观为跟随系统 + 绛红', () {
    final container = ProviderContainer(retry: (_, _) => null);
    addTearDown(container.dispose);

    final appearance = container.read(appearanceProvider);
    expect(appearance.themeMode, ThemeMode.system);
    expect(appearance.themeColor.id, AppThemeColor.crimsonId);
    expect(appearance.surfaceStyle, AppSurfaceStyle.liquid);
  });

  test('effectiveBrightness 按模式解析平台亮度', () {
    AppearanceSettings settings(ThemeMode mode) =>
        AppearanceSettings(themeMode: mode, themeColor: AppThemeColor.crimson);

    expect(
      effectiveBrightness(settings(ThemeMode.system), Brightness.dark),
      Brightness.dark,
    );
    expect(
      effectiveBrightness(settings(ThemeMode.system), Brightness.light),
      Brightness.light,
    );
    expect(
      effectiveBrightness(settings(ThemeMode.light), Brightness.dark),
      Brightness.light,
    );
    expect(
      effectiveBrightness(settings(ThemeMode.dark), Brightness.light),
      Brightness.dark,
    );
  });

  test('切换主题模式与主题色会更新状态并写入存储', () async {
    final store = InMemoryAppearanceStore();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [appearanceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container
        .read(appearanceProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    expect(container.read(appearanceProvider).themeMode, ThemeMode.dark);
    expect(store.read().themeMode, ThemeMode.dark);

    await container
        .read(appearanceProvider.notifier)
        .setThemeColor(AppThemeColor.silhouette);
    expect(
      container.read(appearanceProvider).themeColor.id,
      AppThemeColor.silhouetteId,
    );
    expect(store.read().themeColor.id, AppThemeColor.silhouetteId);

    await container
        .read(appearanceProvider.notifier)
        .setSurfaceStyle(AppSurfaceStyle.flat);
    expect(
      container.read(appearanceProvider).surfaceStyle,
      AppSurfaceStyle.flat,
    );
    expect(store.read().surfaceStyle, AppSurfaceStyle.flat);
  });

  test('SharedPreferences 实现落盘并回读主题模式', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesAppearanceStore(
      await SharedPreferences.getInstance(),
    );
    expect(store.read().themeMode, ThemeMode.system);

    await store.save(
      const AppearanceSettings(
        themeMode: ThemeMode.dark,
        themeColor: AppThemeColor.silhouette,
      ),
    );

    final reloaded = SharedPreferencesAppearanceStore(
      await SharedPreferences.getInstance(),
    );
    expect(reloaded.read().themeMode, ThemeMode.dark);
    expect(reloaded.read().themeColor.id, AppThemeColor.silhouetteId);
    expect(reloaded.read().surfaceStyle, AppSurfaceStyle.liquid);

    await reloaded.save(
      reloaded.read().copyWith(surfaceStyle: AppSurfaceStyle.flat),
    );
    final flatReloaded = SharedPreferencesAppearanceStore(
      await SharedPreferences.getInstance(),
    );
    expect(flatReloaded.read().surfaceStyle, AppSurfaceStyle.flat);
  });

  test('旧值 light/dark 兼容，未知主题模式回退跟随系统', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesAppearanceStore.themeModeKey: 'light',
    });
    var store = SharedPreferencesAppearanceStore(
      await SharedPreferences.getInstance(),
    );
    expect(store.read().themeMode, ThemeMode.light);

    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesAppearanceStore.themeModeKey: 'not-a-mode',
    });
    store = SharedPreferencesAppearanceStore(
      await SharedPreferences.getInstance(),
    );
    expect(store.read().themeMode, ThemeMode.system);
  });

  test('未知主题色 id 回退到绛红', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesAppearanceStore.themeColorKey: 'not-a-color',
      SharedPreferencesAppearanceStore.themeModeKey: 'dark',
    });
    final store = SharedPreferencesAppearanceStore(
      await SharedPreferences.getInstance(),
    );

    expect(store.read().themeColor.id, AppThemeColor.crimsonId);
    expect(store.read().themeMode, ThemeMode.dark);
  });

  test('缺失或未知表面风格回退液态玻璃', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var store = SharedPreferencesAppearanceStore(
      await SharedPreferences.getInstance(),
    );
    expect(store.read().surfaceStyle, AppSurfaceStyle.liquid);

    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesAppearanceStore.surfaceStyleKey: 'not-a-style',
    });
    store = SharedPreferencesAppearanceStore(
      await SharedPreferences.getInstance(),
    );
    expect(store.read().surfaceStyle, AppSurfaceStyle.liquid);
  });
}
