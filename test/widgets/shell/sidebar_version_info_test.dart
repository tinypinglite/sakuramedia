import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/app/providers/app_update_check_provider.dart';
import 'package:sakuramedia/app/providers/external_url_provider.dart';
import 'package:sakuramedia/config/app_release_channels.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/domain/updates/sidebar_version_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/logged_in_session_store.dart';
import '../../support/preview_helpers.dart';
import '../../support/test_api_bundle.dart';

void main() {
  testWidgets('version container wires update state and failed release links', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sessionStore = await buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    final openedUris = <Uri>[];
    var pluginUpdatesCount = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpPreviewApp(
      tester,
      home: SidebarVersionInfo(
        onOpenPluginUpdates: () => pluginUpdatesCount += 1,
      ),
      size: const Size(304, 600),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      extraOverrides: [
        appVersionInfoProvider.overrideWith(_FixedVersionInfo.new),
        pluginsProvider.overrideWith(_PluginsWithUpdates.new),
        appUpdateCheckProvider.overrideWith(_UpdatesAvailable.new),
        externalUrlOpenerProvider.overrideWithValue((uri) async {
          openedUris.add(uri);
          return false;
        }),
      ],
    );

    await tester.tap(find.byKey(const Key('sidebar-version-info')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar-update-notice')), findsOneWidget);
    expect(
      find.byKey(const Key('version-release-link-frontend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('version-release-link-backend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sidebar-version-popover-go-plugins')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('version-release-link-frontend')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    expect(openedUris.single, Uri.parse(AppReleaseChannels.frontendPageUrl));
    expect(find.byType(AppGlassToast), findsOneWidget);
    expect(
      tester.widget<AppGlassToast>(find.byType(AppGlassToast)).tone,
      AppToastTone.error,
    );

    dismissAllToast();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    await tester.tap(find.byKey(const Key('sidebar-version-info')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('sidebar-version-popover-go-plugins')),
    );
    await tester.pumpAndSettle();

    expect(pluginUpdatesCount, 1);
  });
}

class _FixedVersionInfo extends AppVersionInfo {
  @override
  AppVersionInfoState build() => const AppVersionInfoState(
    frontendVersion: '1.2.3',
    backendVersion: 'v1.0.0',
  );
}

class _PluginsWithUpdates extends Plugins {
  @override
  Future<PluginsState> build() async {
    return const PluginsState(
      plugins: <PluginSummaryDto>[],
      updates: <String, PluginReleaseUpdate>{
        'demo_plugin': PluginReleaseUpdate(
          version: '2.0.0',
          notes: '',
          assetUrl: 'https://example.com/demo.zip',
          assetFileName: 'demo.zip',
        ),
        'another_plugin': PluginReleaseUpdate(
          version: '3.0.0',
          notes: '',
          assetUrl: 'https://example.com/another.zip',
          assetFileName: 'another.zip',
        ),
      },
    );
  }
}

class _UpdatesAvailable extends AppUpdateCheck {
  @override
  AppUpdateCheckState build() => const AppUpdateCheckState(
    frontendUpdateVersion: '1.3.0',
    backendUpdateVersion: 'v1.1.0',
  );
}
