import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/appearance_store.dart';
import 'package:sakuramedia/app/providers/appearance_providers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/appearance_settings_content.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

import '../../../../../support/pump_with_providers.dart';

void main() {
  testWidgets('切换界面风格会更新并持久化外观偏好', (tester) async {
    final store = InMemoryAppearanceStore();

    await pumpWithProviders(
      tester,
      home: const SingleChildScrollView(child: AppearanceSettingsContent()),
      overrides: [appearanceStoreProvider.overrideWithValue(store)],
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(1100, 1600),
    );

    expect(find.byKey(const Key('appearance-surface-liquid')), findsOneWidget);
    expect(find.byKey(const Key('appearance-surface-flat')), findsOneWidget);

    await tester.tap(find.byKey(const Key('appearance-surface-flat')));
    await tester.pumpAndSettle();

    expect(store.read().surfaceStyle, AppSurfaceStyle.flat);

    await tester.tap(find.byKey(const Key('appearance-surface-liquid')));
    await tester.pumpAndSettle();

    expect(store.read().surfaceStyle, AppSurfaceStyle.liquid);
  });

  testWidgets('macOS 显示独立的窗口毛玻璃开关并持久化', (tester) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final store = InMemoryAppearanceStore();

      await pumpWithProviders(
        tester,
        home: const SingleChildScrollView(child: AppearanceSettingsContent()),
        overrides: [appearanceStoreProvider.overrideWithValue(store)],
        theme: sakuraDesktopThemeData,
        physicalSize: const Size(1100, 1800),
      );

      final cell = find.byKey(const Key('appearance-window-vibrancy'));
      expect(cell, findsOneWidget);
      expect(store.read().windowVibrancy, isTrue);

      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pumpAndSettle();

      expect(store.read().windowVibrancy, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });

  testWidgets('非 macOS 不显示窗口毛玻璃开关', (tester) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await pumpWithProviders(
        tester,
        home: const SingleChildScrollView(child: AppearanceSettingsContent()),
        theme: sakuraDesktopThemeData,
        physicalSize: const Size(1100, 1800),
      );

      expect(find.byKey(const Key('appearance-window-vibrancy')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });
}
