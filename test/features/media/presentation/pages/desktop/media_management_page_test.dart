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
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required MediaApi mediaApi,
  required ApiClient apiClient,
  bool switchToMaintenance = false,
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
        home: const OKToast(
          child: Scaffold(body: DesktopMediaManagementPage()),
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

Map<String, dynamic> _duplicateMediaItemJson(int id) {
  return <String, dynamic>{
    'id': id,
    'kind': 'jav',
    'movie_number': 'ABC-$id',
    'video_item_id': null,
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
    'created_at': '2026-05-13T12:00:00Z',
    'updated_at': '2026-05-13T12:00:00Z',
  };
}
