import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_test_content.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/logged_in_session_store.dart';
import '../../../support/test_api_bundle.dart';
import '../support/plugin_test_data.dart';

void main() {
  testWidgets('runs every declared capability and renders each result', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    final session = await buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(session);
    addTearDown(bundle.dispose);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/demo_plugin/test',
      body: _metadataResult(),
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/demo_plugin/test',
      body: _statsResult(),
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/demo_plugin/test',
      body: _reviewsResult(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bundle.riverpodOverrides(),
          pluginsApiProvider.overrideWithValue(
            PluginsApi(apiClient: bundle.apiClient),
          ),
        ],
        child: MaterialApp(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          home: Scaffold(
            body: SizedBox(
              height: 720,
              child: PluginTestContent(
                plugin: pluginSummaryDto(
                  id: 'demo_plugin',
                  enabled: true,
                  testMovieNumber: 'SSIS-001',
                  testCapabilities: const <PluginTestCapability>[
                    PluginTestCapability.metadata,
                    PluginTestCapability.stats,
                    PluginTestCapability.reviews,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('plugin-test-run-metadata')), findsOneWidget);
    expect(find.byKey(const Key('plugin-test-run-stats')), findsOneWidget);
    expect(find.byKey(const Key('plugin-test-run-reviews')), findsOneWidget);

    final runAll = find.byKey(const Key('plugin-test-run-all-button'));
    await tester.ensureVisible(runAll);
    await tester.tap(runAll);
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount('POST', '/system/plugins/demo_plugin/test'),
      3,
    );
    expect(
      bundle.adapter.requests.map(
        (request) => (request.body as Map)['capability'],
      ),
      <String>['metadata', 'stats', 'reviews'],
    );
    expect(
      find.byKey(const Key('plugin-test-result-metadata')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('plugin-test-result-stats')), findsOneWidget);
    expect(find.byKey(const Key('plugin-test-result-reviews')), findsOneWidget);
  });
}

Map<String, dynamic> _metadataResult() {
  return <String, dynamic>{
    'capability': 'metadata',
    'status': 'ok',
    'movie_number': 'SSIS-001',
    'duration_ms': 320,
    'metadata': <String, dynamic>{
      'movie_number': 'SSIS-001',
      'title': '测试影片',
      'release_date': '2024-01-01',
      'duration_minutes': 120,
      'actor_count': 2,
      'tag_count': 6,
      'image_count': 4,
    },
  };
}

Map<String, dynamic> _statsResult() {
  return <String, dynamic>{
    'capability': 'stats',
    'status': 'empty',
    'movie_number': 'SSIS-001',
    'duration_ms': 180,
  };
}

Map<String, dynamic> _reviewsResult() {
  return <String, dynamic>{
    'capability': 'reviews',
    'status': 'failed',
    'movie_number': 'SSIS-001',
    'duration_ms': 210,
    'error_type': 'RuntimeError',
    'error_message': 'upstream unavailable',
  };
}
