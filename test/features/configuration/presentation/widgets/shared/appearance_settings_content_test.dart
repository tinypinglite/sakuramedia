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
}
