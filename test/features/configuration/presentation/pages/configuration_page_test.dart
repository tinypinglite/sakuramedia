import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/configuration_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/downloaders_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/indexers_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/media_libraries_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/metadata_sources_page.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_settings_content.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugins_section.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/pump_with_providers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('configuration pages are disposed after switching away', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      _stubConfigurationRequests(bundle);

      await pumpWithProviders(
        tester,
        home: const Scaffold(body: DesktopConfigurationPage()),
        bundle: bundle,
        theme: sakuraDesktopThemeData,
        physicalSize: const Size(1200, 900),
      );
      await tester.pump();

      final targets = <Key, Type>{
        Key('configuration-tab-media-libraries'): MediaLibrariesPage,
        Key('configuration-tab-metadata-sources'): MetadataSourcesPage,
        Key('configuration-tab-downloads'): DownloadersPage,
        Key('configuration-tab-indexers'): IndexersPage,
        Key('configuration-tab-external-player'): ExternalPlayerSettingsContent,
        Key('configuration-tab-plugins'): DesktopPluginsSection,
      };

      for (final target in targets.entries) {
        await tester.ensureVisible(find.byKey(target.key));
        await tester.tap(find.byKey(target.key));
        await tester.pump();

        final state = tester.state(find.byType(target.value));
        expect(state.mounted, isTrue);

        await tester.tap(
          find.byKey(const Key('configuration-tab-appearance')),
        );
        await tester.pump();

        expect(state.mounted, isFalse);
      }
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void _stubConfigurationRequests(TestApiBundle bundle) {
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/media-libraries',
    body: const <dynamic>[],
  );
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/media-libraries/providers',
    body: const <dynamic>[],
  );
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/download-clients',
    body: const <dynamic>[],
  );
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/indexer-settings',
    body: const <String, dynamic>{'indexers': <dynamic>[]},
  );
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/system/metadata-sources',
    body: const <dynamic>[],
  );
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/system/plugins',
    body: const <dynamic>[],
  );
}
