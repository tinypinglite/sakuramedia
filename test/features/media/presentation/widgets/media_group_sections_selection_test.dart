import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/duplicate_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/duplicate_media_section.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/multi_version_movies_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Main',
          'provider_key': 'local',
          'provider_config': <String, dynamic>{},
          'supports_in_place_import': false,
          'created_at': '2026-03-12T10:00:00Z',
          'updated_at': '2026-03-12T10:00:00Z',
        },
      ],
    );
    bundle.adapter.setFallbackJson(
      method: 'POST',
      path: '/batch-operations',
      body: <String, dynamic>{'task_run_id': 1},
    );
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('duplicate sections submit selected media ids in batch', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _page(<Map<String, dynamic>>[
        _duplicateGroup(<int>[101, 102, 103]),
      ]),
    );

    await pumpPreviewApp(
      tester,
      home: DuplicateMediaSection(
        scrollController: ScrollController(),
        kind: MediaListItemKind.jav,
        onKindChanged: (_) {},
        keyPrefix: 'media-test',
        mobile: false,
        onRefresh: () async {},
        onOpenVideoCollectionDetail: (_, _) {},
      ),
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      settle: false,
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('media-test-duplicates-select')));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('media-test-duplicate-row-101')));
    await _pumpFrames(tester);

    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const Key('media-test-duplicate-select-101')),
          )
          .value,
      isTrue,
    );
    expect(
      find.byKey(const Key('media-test-duplicates-selected-count')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('media-test-duplicates-batch-delete')),
    );
    await _pumpFrames(tester);
    expect(
      find.byKey(const Key('media-test-duplicates-batch-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('media-test-duplicates-batch-confirm')),
    );
    await _pumpFrames(tester);

    final request = bundle.adapter.requests.lastWhere(
      (request) => request.path == '/batch-operations',
    );
    expect(request.body['operation'], 'media_delete');
    expect(request.body['ids'], <int>[101]);
    expect(
      find.byKey(const Key('media-test-duplicates-selected-count')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('changed duplicate groups stop the batch delete', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _page(<Map<String, dynamic>>[
        _duplicateGroup(<int>[101, 102]),
      ]),
    );

    await pumpPreviewApp(
      tester,
      home: DuplicateMediaSection(
        scrollController: ScrollController(),
        kind: MediaListItemKind.jav,
        onKindChanged: (_) {},
        keyPrefix: 'media-test',
        mobile: false,
        onRefresh: () async {},
        onOpenVideoCollectionDetail: (_, _) {},
      ),
      size: const Size(1100, 760),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      settle: false,
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('media-test-duplicates-select')));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('media-test-duplicate-row-101')));
    await _pumpFrames(tester);
    await tester.tap(
      find.byKey(const Key('media-test-duplicates-batch-delete')),
    );
    await _pumpFrames(tester);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _page(<Map<String, dynamic>>[
        _duplicateGroup(<int>[103, 104]),
      ]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DuplicateMediaSection)),
    );
    container.invalidate(duplicateMediaProvider(MediaListItemKind.jav));
    await _pumpFrames(tester);

    await tester.tap(
      find.byKey(const Key('media-test-duplicates-batch-confirm')),
    );
    await _pumpFrames(tester);

    expect(bundle.adapter.hitCount('POST', '/batch-operations'), 0);
    expect(
      find.byKey(const Key('media-test-duplicates-selected-count')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('mobile versions section deletes from the bottom bar', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/multi-version-movies',
      body: _page(<Map<String, dynamic>>[
        _versionGroup('A', <int>[201, 202]),
      ]),
    );

    await pumpPreviewApp(
      tester,
      home: MultiVersionMoviesSection(
        scrollController: ScrollController(),
        keyPrefix: 'media-test',
        mobile: true,
        onOpenMovieDetail: (_, _) {},
        includeVr: ValueNotifier<bool>(false),
        includeFc2: ValueNotifier<bool>(false),
        includeProcessed: ValueNotifier<bool>(false),
      ),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      settle: false,
    );
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('media-test-versions-select')));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('media-test-version-row-201')));
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('media-test-versions-batch-delete')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('media-test-versions-batch-delete')));
    await _pumpFrames(tester);
    await tester.tap(
      find.byKey(const Key('media-test-versions-batch-confirm')),
    );
    await _pumpFrames(tester);

    final request = bundle.adapter.requests.lastWhere(
      (request) => request.path == '/batch-operations',
    );
    expect(request.body['operation'], 'media_delete');
    expect(request.body['ids'], <int>[201]);
    expect(
      find.byKey(const Key('media-test-versions-selected-count')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items) {
  return <String, dynamic>{
    'items': items,
    'total': items.length,
    'page': 1,
    'page_size': 20,
  };
}

Map<String, dynamic> _duplicateGroup(List<int> ids) {
  return <String, dynamic>{
    'kind': 'jav',
    'media_count': ids.length,
    'media_items': ids.map(_mediaItem).toList(),
  };
}

Map<String, dynamic> _versionGroup(String movieNumber, List<int> ids) {
  return <String, dynamic>{
    'movie_number': movieNumber,
    'media_count': ids.length,
    'is_processed': false,
    'media_items': ids
        .map((id) => _mediaItem(id)..['movie_number'] = movieNumber)
        .toList(),
  };
}

Map<String, dynamic> _mediaItem(int id) {
  return <String, dynamic>{
    'id': id,
    'kind': 'jav',
    'movie_number': 'DUP-1',
    'library_id': 1,
    'library_name': 'Main',
    'file_name': 'media-$id.mp4',
    'file_size_bytes': 100,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'valid': true,
    'thumbnail_generation_state': 'succeeded',
    'heat': 100,
    'created_at': '2026-03-12T10:00:00Z',
    'updated_at': '2026-03-12T10:00:00Z',
  };
}
