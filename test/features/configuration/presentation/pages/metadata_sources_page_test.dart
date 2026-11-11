import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/metadata_sources_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
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

  testWidgets('loads metadata sources and saves their order', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'plugin_id': 'source_a', 'display_name': 'Source A'},
        <String, dynamic>{'plugin_id': 'source_b', 'display_name': 'Source B'},
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/system/metadata-sources/order',
      body: <String, dynamic>{'ok': true},
    );

    await pumpPreviewApp(
      tester,
      home: const MetadataSourcesPage(active: true),
      size: const Size(1000, 900),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      wrap: (child) => SingleChildScrollView(child: child),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('metadata-sources-order-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('metadata-source-row-source_a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('metadata-source-row-source_b')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('metadata-source-down-source_a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('metadata-sources-save-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    final request = bundle.adapter.requests.singleWhere(
      (item) =>
          item.method == 'PUT' && item.path == '/system/metadata-sources/order',
    );
    expect(request.body, <String, dynamic>{
      'plugin_ids': <String>['source_b', 'source_a'],
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty state when no metadata plugin is loaded', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[],
    );

    await pumpPreviewApp(
      tester,
      home: const MetadataSourcesPage(active: true),
      size: const Size(1000, 900),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      wrap: (child) => SingleChildScrollView(child: child),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('metadata-sources-empty-state')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile page scrolls through metadata sources and bindings', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[
        for (var index = 0; index < 8; index++)
          <String, dynamic>{
            'plugin_id': 'source_$index',
            'display_name': 'Source $index',
          },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins/bindings',
      body: <String, dynamic>{
        'stats_source': null,
        'review_source': null,
        'stats_source_available': false,
        'review_source_available': false,
        'stats_fields': <Map<String, dynamic>>[],
        'available_stats_sources': <Map<String, dynamic>>[],
        'available_review_sources': <Map<String, dynamic>>[],
      },
    );

    await pumpPreviewApp(
      tester,
      home: const MetadataSourcesPage(active: true, mobile: true),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-settings-metadata-sources')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('plugin-bindings-card')),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('plugin-bindings-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('binds one stats source and one review source', (tester) async {
    bool? bindingsDirty;
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'plugin_id': 'source_a', 'display_name': 'Source A'},
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins/bindings',
      body: <String, dynamic>{
        'stats_source': 'stats_a',
        'review_source': 'review_a',
        'stats_source_available': true,
        'review_source_available': true,
        'stats_fields': <Map<String, dynamic>>[
          <String, dynamic>{
            'key': 'watched_count',
            'label': 'Watched',
            'value_type': 'int',
          },
        ],
        'available_stats_sources': <Map<String, dynamic>>[
          <String, dynamic>{'plugin_id': 'stats_a', 'display_name': 'Stats A'},
          <String, dynamic>{'plugin_id': 'stats_b', 'display_name': 'Stats B'},
        ],
        'available_review_sources': <Map<String, dynamic>>[
          <String, dynamic>{
            'plugin_id': 'review_a',
            'display_name': 'Review A',
          },
          <String, dynamic>{
            'plugin_id': 'review_b',
            'display_name': 'Review B',
          },
        ],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/system/plugins/bindings',
      body: <String, dynamic>{
        'stats_source': 'stats_b',
        'review_source': 'review_b',
        'stats_source_available': true,
        'review_source_available': true,
        'pending_restart': <String>['api', 'aps'],
      },
    );

    await pumpPreviewApp(
      tester,
      home: MetadataSourcesPage(
        active: true,
        onDirtyChanged: (dirty) => bindingsDirty = dirty,
      ),
      size: const Size(1000, 1000),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      wrap: (child) => SingleChildScrollView(child: child),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plugin-bindings-stats-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stats B').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plugin-bindings-review-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review B').last);
    await tester.pumpAndSettle();
    expect(bindingsDirty, isTrue);

    await tester.tap(find.byKey(const Key('plugin-bindings-save-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    final request = bundle.adapter.requests.singleWhere(
      (item) => item.method == 'PUT' && item.path == '/system/plugins/bindings',
    );
    expect(request.body, <String, dynamic>{
      'stats_source': 'stats_b',
      'review_source': 'review_b',
    });
    expect(bindingsDirty, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears unavailable bindings when another source changes', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/metadata-sources',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'plugin_id': 'source_a', 'display_name': 'Source A'},
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/plugins/bindings',
      body: <String, dynamic>{
        'stats_source': 'removed_stats_plugin',
        'review_source': 'review_a',
        'stats_source_available': false,
        'review_source_available': true,
        'stats_fields': <Map<String, dynamic>>[],
        'available_stats_sources': <Map<String, dynamic>>[
          <String, dynamic>{'plugin_id': 'stats_b', 'display_name': 'Stats B'},
        ],
        'available_review_sources': <Map<String, dynamic>>[
          <String, dynamic>{
            'plugin_id': 'review_a',
            'display_name': 'Review A',
          },
          <String, dynamic>{
            'plugin_id': 'review_b',
            'display_name': 'Review B',
          },
        ],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/system/plugins/bindings',
      body: <String, dynamic>{
        'stats_source': null,
        'review_source': 'review_b',
        'pending_restart': <String>['api', 'aps'],
      },
    );

    await pumpPreviewApp(
      tester,
      home: const MetadataSourcesPage(active: true),
      size: const Size(1000, 1000),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      wrap: (child) => SingleChildScrollView(child: child),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plugin-bindings-review-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plugin-bindings-save-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    final request = bundle.adapter.requests.singleWhere(
      (item) => item.method == 'PUT' && item.path == '/system/plugins/bindings',
    );
    expect(request.body, <String, dynamic>{
      'stats_source': null,
      'review_source': 'review_b',
    });
    expect(tester.takeException(), isNull);
  });
}
