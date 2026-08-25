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
import 'package:sakuramedia/features/media/presentation/pages/mobile/media_management_page.dart';
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
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders mobile list and supported tabs', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    expect(
      find.byKey(const Key('mobile-media-management-row-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-tab-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-tab-maintenance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-tab-batches')),
      findsNothing,
    );
  });

  testWidgets('long press exposes only batch delete action', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );

    await tester.longPress(
      find.byKey(const Key('mobile-media-management-row-long-press-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
      findsOneWidget,
    );
  });

  testWidgets('mobile filter opens bottom drawer', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: const []),
    );
    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      mediaApi: mediaApi,
      apiClient: apiClient,
    );
    await tester.tap(
      find.byKey(const Key('mobile-media-management-filter-trigger')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-filter-scroll-view')),
      findsOneWidget,
    );
    expect(find.text('缩略图状态'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required MediaApi mediaApi,
  required ApiClient apiClient,
}) async {
  tester.view.physicalSize = const Size(390, 844);
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
        home: const OKToast(child: Scaffold(body: MobileMediaManagementPage())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _EmptyMediaLibrariesApi extends MediaLibrariesApi {
  const _EmptyMediaLibrariesApi({required super.apiClient});

  @override
  Future<List<MediaLibraryDto>> getLibraries() async =>
      const <MediaLibraryDto>[];
}

Map<String, dynamic> _mediaPage({required List<Map<String, dynamic>> items}) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': 30,
    'total': items.length,
  };
}

Map<String, dynamic> _mediaItemJson(int id) {
  return <String, dynamic>{
    'id': id,
    'kind': 'jav',
    'movie_number': 'ABC-$id',
    'video_item_id': null,
    'title': 'Movie $id',
    'cover_image': null,
    'thin_cover_image': null,
    'library_id': 1,
    'library_name': 'Main',
    'file_name': 'abc-$id.mp4',
    'file_size_bytes': 100,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'special_tags': '普通',
    'valid': true,
    'thumbnail_generation_state': 'succeeded',
    'thumbnail_last_error_code': null,
    'heat': 100,
    'created_at': '2026-03-12T10:00:00Z',
    'updated_at': '2026-03-12T10:00:00Z',
  };
}
