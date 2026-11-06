import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/providers/app_update_check_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/app_sidebar_account_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/logged_in_session_store.dart';
import '../../support/preview_helpers.dart';
import '../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shared account card opens versions and exposes logout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sessionStore = await buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    var logoutCount = 0;
    await pumpPreviewApp(
      tester,
      home: AppSidebarAccountCard(
        onLogout: () => logoutCount += 1,
        onOpenPluginUpdates: () {},
      ),
      size: const Size(304, 160),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      extraOverrides: [
        pluginsProvider.overrideWith(_EmptyPlugins.new),
        appUpdateCheckProvider.overrideWith(_NoUpdates.new),
      ],
    );

    await tester.tap(find.byKey(const Key('sidebar-logout-button')));
    await tester.pump();
    expect(logoutCount, 1);

    await tester.tap(find.byKey(const Key('sidebar-version-info')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sidebar-version-popover')), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-theme-color-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('sidebar-theme-color-${AppThemeColor.values.first.id}')),
      findsOneWidget,
    );
  });
}

class _EmptyPlugins extends Plugins {
  @override
  Future<PluginsState> build() async => const PluginsState(plugins: []);
}

class _NoUpdates extends AppUpdateCheck {
  @override
  AppUpdateCheckState build() => AppUpdateCheckState.initial;
}
