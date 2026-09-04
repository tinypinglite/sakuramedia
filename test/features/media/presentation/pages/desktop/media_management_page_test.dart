import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/pages/desktop/media_management_page.dart';
import 'package:sakuramedia/features/media/presentation/pages/shared/media_management_content.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MediaApi mediaApi;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-05-13T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    mediaApi = MediaApi(apiClient: apiClient);
    adapter.setFallbackJson(method: 'GET', path: '/media', body: _emptyPage());
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders supported tabs and lazy-loads management sections', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _page(total: 0, items: const []),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _page(total: 0, items: const []),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(find.byKey(const Key('media-management-tab-list')), findsOneWidget);
    expect(
      find.byKey(const Key('media-management-tab-maintenance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('media-management-tab-duplicates')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('media-management-tab-batches')), findsNothing);
    expect(adapter.hitCount('GET', '/media/duplicates'), 0);
    expect(adapter.hitCount('GET', '/media/invalid'), 0);

    await tester.tap(find.byKey(const Key('media-management-tab-duplicates')));
    await tester.pumpAndSettle();
    expect(adapter.hitCount('GET', '/media/duplicates'), 1);
    expect(
      find.byKey(const Key('media-management-duplicate-media-section')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('media-management-tab-maintenance')));
    await tester.pumpAndSettle();
    expect(adapter.hitCount('GET', '/media/invalid'), 1);
    expect(
      find.byKey(const Key('media-management-invalid-media-section')),
      findsOneWidget,
    );
  });

  testWidgets('shows duplicate groups and removes the final duplicate copy', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _page(total: 1, items: [_duplicateGroupJson()]),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.tap(find.byKey(const Key('media-management-tab-duplicates')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-duplicate-group-1')),
      findsOneWidget,
    );
    expect(find.text('abc-1.mp4'), findsOneWidget);
    expect(find.text('重复文件组'), findsNothing);
    expect(find.text('以下媒体内容相同，分别来自不同媒体记录。'), findsNothing);
    expect(find.textContaining('hash'), findsNothing);

    await tester.tap(
      find.byKey(const Key('media-management-duplicate-delete-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-management-duplicate-delete-dialog-1')),
      findsOneWidget,
    );
    expect(find.textContaining('不再属于重复媒体'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const Key('media-management-duplicate-delete-confirm-button-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(adapter.hitCount('DELETE', '/media/1'), 1);
    expect(
      find.byKey(const Key('media-management-duplicate-group-1')),
      findsNothing,
    );
    expect(find.text('共 0 组'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows and opens collections for duplicate PornBox media', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _page(total: 1, items: [_duplicateVideoGroupJson()]),
    );
    int? openedCollectionId;
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
      onOpenVideoCollectionDetail: (collectionId) {
        openedCollectionId = collectionId;
      },
    );

    await tester.tap(find.byKey(const Key('media-management-tab-duplicates')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('duplicate-media-collections-title-1')),
      findsOneWidget,
    );
    expect(find.text('系列 A'), findsOneWidget);
    expect(find.text('稍后再看'), findsOneWidget);
    await tester.tap(find.byKey(const Key('video-collection-chip-8')));
    expect(openedCollectionId, 8);
  });

  testWidgets('deletes an invalid media item directly', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _page(total: 1, items: [_invalidMediaJson(1)]),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
      switchToMaintenance: true,
    );

    expect(find.byKey(const Key('invalid-media-delete-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invalid-media-delete-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('invalid-media-delete-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('invalid-media-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(adapter.hitCount('DELETE', '/media/1'), 1);
    expect(find.byKey(const Key('invalid-media-delete-1')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'submits a provider-neutral media transfer from the batch toolbar',
    (tester) async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/media',
        body: _page(total: 1, items: [_duplicateMediaItemJson(1)]),
      );
      adapter.enqueueJson(
        method: 'POST',
        path: '/media-transfers/candidates',
        body: <String, dynamic>{
          'source_library': <String, dynamic>{'id': 1, 'name': '媒体库 A'},
          'targets': <Map<String, dynamic>>[
            <String, dynamic>{'id': 9, 'name': '媒体库 B'},
          ],
        },
      );
      adapter.enqueueJson(
        method: 'POST',
        path: '/media-transfers',
        statusCode: 202,
        body: <String, dynamic>{
          'task_run_id': 88,
          'task_key': 'media_storage_transfer',
          'state': 'pending',
        },
      );
      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        mediaApi: mediaApi,
        apiClient: apiClient,
      );

      await tester.tap(find.byKey(const Key('media-management-row-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('media-management-batch-transfer-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('media-management-transfer-dialog')),
        findsOneWidget,
      );
      expect(find.text('媒体库 B'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('media-management-transfer-confirm-button')),
      );
      await tester.pumpAndSettle();

      final requests = adapter.requests
          .where((request) => request.method == 'POST')
          .toList(growable: false);
      expect(requests[0].path, '/media-transfers/candidates');
      expect(requests[0].body, <String, dynamic>{
        'media_ids': <int>[1],
      });
      expect(requests[1].path, '/media-transfers');
      expect(requests[1].body, <String, dynamic>{
        'media_ids': <int>[1],
        'target_library_id': 9,
      });
      expect(
        find.byKey(const Key('media-management-batch-transfer-button')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required MediaApi mediaApi,
  required ApiClient apiClient,
  bool switchToMaintenance = false,
  void Function(int collectionId)? onOpenVideoCollectionDetail,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        mediaApiProvider.overrideWithValue(mediaApi),
        mediaLibrariesApiProvider.overrideWithValue(
          _EmptyMediaLibrariesApi(apiClient: apiClient),
        ),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: OKToast(
          child: Scaffold(
            body: onOpenVideoCollectionDetail == null
                ? const DesktopMediaManagementPage()
                : MediaManagementContent(
                    keyPrefix: 'media-management',
                    rootKey: const Key('desktop-media-management-page'),
                    onOpenMovieDetail: (_, _) {},
                    onOpenVideoCollectionDetail: (_, collectionId) =>
                        onOpenVideoCollectionDetail(collectionId),
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (switchToMaintenance) {
    await tester.tap(find.byKey(const Key('media-management-tab-maintenance')));
    await tester.pumpAndSettle();
  }
}

class _EmptyMediaLibrariesApi extends MediaLibrariesApi {
  const _EmptyMediaLibrariesApi({required super.apiClient});

  @override
  Future<List<MediaLibraryDto>> getLibraries() async =>
      const <MediaLibraryDto>[];
}

Map<String, dynamic> _emptyPage() => _page(total: 0, items: const []);

Map<String, dynamic> _page({required int total, required List items}) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': 20,
    'total': total,
  };
}

Map<String, dynamic> _invalidMediaJson(int id) {
  return <String, dynamic>{
    'id': id,
    'movie_number': 'ABC-$id',
    'video_item_id': null,
    'movie_title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'file_name': 'ABC-$id.mp4',
    'library_id': 1,
    'library_name': 'Main Library',
    'file_size_bytes': 1024,
    'updated_at': '2026-05-13T12:00:00Z',
  };
}

Map<String, dynamic> _duplicateGroupJson() {
  return <String, dynamic>{
    'kind': 'jav',
    'media_count': 2,
    'media_items': [_duplicateMediaItemJson(1), _duplicateMediaItemJson(2)],
  };
}

Map<String, dynamic> _duplicateVideoGroupJson() {
  return <String, dynamic>{
    'kind': 'video',
    'media_count': 2,
    'media_items': [
      _duplicateMediaItemJson(
        1,
        kind: 'video',
        videoItemId: 101,
        collections: <Map<String, dynamic>>[
          <String, dynamic>{'id': 3, 'name': '系列 A'},
          <String, dynamic>{'id': 8, 'name': '稍后再看'},
        ],
      ),
      _duplicateMediaItemJson(2, kind: 'video', videoItemId: 102),
    ],
  };
}

Map<String, dynamic> _duplicateMediaItemJson(
  int id, {
  String kind = 'jav',
  int? videoItemId,
  List<Map<String, dynamic>> collections = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'id': id,
    'kind': kind,
    'movie_number': kind == 'jav' ? 'ABC-$id' : null,
    'video_item_id': videoItemId,
    'title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'library_id': 1,
    'library_name': 'Main Library',
    'file_name': 'abc-$id.mp4',
    'file_size_bytes': 1024,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'valid': true,
    'thumbnail_generation_state': 'succeeded',
    'thumbnail_last_error_code': null,
    'heat': 100,
    'collections': collections,
    'created_at': '2026-05-13T12:00:00Z',
    'updated_at': '2026-05-13T12:00:00Z',
  };
}
