import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/desktop_media_maintenance_page.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

import '../../../support/fake_http_client_adapter.dart';

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

  testWidgets('shows empty state for empty invalid media list', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(total: 0, items: const []),
    );

    await _pumpPage(tester, mediaApi: mediaApi, apiClient: apiClient, sessionStore: sessionStore);

    expect(
      find.byKey(const Key('desktop-media-maintenance-page')),
      findsOneWidget,
    );
    expect(find.text('当前没有失效媒体'), findsOneWidget);
    expect(find.text('共 0 条失效媒体'), findsOneWidget);
  });

  testWidgets('renders fields and cover fallback order', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 3,
        items: [
          _invalidMediaJson(
            id: 1,
            movieNumber: 'ABC-001',
            title: 'Movie 1',
            thinCoverUrl: '/covers/abc-001-thin-large.webp',
            coverUrl: '/covers/abc-001-cover-large.webp',
          ),
          _invalidMediaJson(
            id: 2,
            movieNumber: 'ABC-002',
            title: 'Movie 2',
            coverUrl: '/covers/abc-002-cover-large.webp',
          ),
          _invalidMediaJson(id: 3, movieNumber: 'ABC-003', title: 'Movie 3'),
        ],
      ),
    );

    await _pumpPage(tester, mediaApi: mediaApi, apiClient: apiClient, sessionStore: sessionStore);

    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text('Movie 1'), findsOneWidget);
    expect(find.text('Main Library'), findsNWidgets(3));
    expect(find.text('2.0 GB'), findsNWidgets(3));
    expect(
      find.text(_localDateTimeText('2026-05-13T12:00:00Z')),
      findsNWidgets(3),
    );
    expect(find.byKey(const Key('invalid-media-path-1')), findsOneWidget);

    final thinCover = tester.widget<MaskedImage>(
      find.byKey(const Key('invalid-media-cover-ABC-001')),
    );
    expect(thinCover.url, '/covers/abc-001-thin-large.webp');
    expect(thinCover.fit, BoxFit.cover);

    final coverFallback = tester.widget<MaskedImage>(
      find.byKey(const Key('invalid-media-cover-ABC-002')),
    );
    expect(coverFallback.url, '/covers/abc-002-cover-large.webp');
    expect(coverFallback.fit, BoxFit.contain);

    expect(
      find.byKey(const Key('invalid-media-cover-placeholder-ABC-003')),
      findsOneWidget,
    );
    expect(find.text('先复查'), findsNWidgets(3));
  });

  testWidgets(
      'cloud115 invalid media hides locator prefix and uses cloud wording', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [
          <String, dynamic>{
            ..._invalidMediaJson(id: 115, movieNumber: 'ABC-115'),
            'path': 'cloud115:ABC-115.mp4',
            'library_id': 9,
            'library_name': '115 主库',
          },
        ],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 9,
          'name': '115 主库',
          'backend': 'cloud115',
          'backend_config': <String, dynamic>{
            'root_cid': 'root',
            'app': 'alipaymini',
          },
        },
      ],
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/115/validity-check',
      body: _validityResultJson(id: 115, revived: false, validAfter: false),
    );

    await _pumpPage(
      tester,
      mediaApi: mediaApi,
      apiClient: apiClient,
      sessionStore: sessionStore,
      mediaLibrariesApi: MediaLibrariesApi(apiClient: apiClient),
    );

    expect(find.text('ABC-115.mp4'), findsOneWidget);
    expect(find.textContaining('cloud115:'), findsNothing);

    await tester.tap(find.byKey(const Key('invalid-media-check-115')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invalid-media-delete-115')));
    await tester.pumpAndSettle();

    expect(find.textContaining('115 网盘文件'), findsOneWidget);
    expect(find.textContaining('进入 115 回收站'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('refresh button reloads first page', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [_invalidMediaJson(id: 2, movieNumber: 'ABC-002')],
      ),
    );

    await _pumpPage(tester, mediaApi: mediaApi, apiClient: apiClient, sessionStore: sessionStore);
    await tester.tap(find.byKey(const Key('invalid-media-refresh-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ABC-001'), findsNothing);
    expect(find.text('ABC-002'), findsOneWidget);
    expect(adapter.hitCount('GET', '/media/invalid'), 2);
  });

  testWidgets('validity check removes revived media and shows toast', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/1/validity-check',
      body: _validityResultJson(id: 1, revived: true, validAfter: true),
    );

    await _pumpPage(tester, mediaApi: mediaApi, apiClient: apiClient, sessionStore: sessionStore);
    await tester.tap(find.byKey(const Key('invalid-media-check-1')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ABC-001'), findsNothing);
    expect(find.text('媒体已恢复'), findsOneWidget);
    expect(adapter.hitCount('POST', '/media/1/validity-check'), 1);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('validity check keeps invalid media and shows toast', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/1/validity-check',
      body: _validityResultJson(id: 1, revived: false, validAfter: false),
    );

    await _pumpPage(tester, mediaApi: mediaApi, apiClient: apiClient, sessionStore: sessionStore);
    await tester.tap(find.byKey(const Key('invalid-media-check-1')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text('媒体仍不可用，已开放删除'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('delete is disabled until check keeps media invalid', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        total: 1,
        items: [_invalidMediaJson(id: 1, movieNumber: 'ABC-001')],
      ),
    );
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/1/validity-check',
      body: _validityResultJson(id: 1, revived: false, validAfter: false),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);

    await _pumpPage(tester, mediaApi: mediaApi, apiClient: apiClient, sessionStore: sessionStore);

    await tester.tap(find.byKey(const Key('invalid-media-delete-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('invalid-media-delete-confirm-dialog')),
      findsNothing,
    );
    expect(adapter.hitCount('DELETE', '/media/1'), 0);

    await tester.tap(find.byKey(const Key('invalid-media-check-1')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('invalid-media-delete-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('invalid-media-delete-confirm-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('失效媒体记录及对应媒体文件'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('invalid-media-delete-cancel-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ABC-001'), findsOneWidget);
    expect(adapter.hitCount('DELETE', '/media/1'), 0);

    await tester.tap(find.byKey(const Key('invalid-media-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('invalid-media-delete-confirm-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ABC-001'), findsNothing);
    expect(find.text('失效媒体已删除'), findsOneWidget);
    expect(adapter.hitCount('DELETE', '/media/1'), 1);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('load more footer retries after paging failure', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        page: 1,
        pageSize: 20,
        total: 21,
        items: List<Map<String, dynamic>>.generate(
          20,
          (index) => _invalidMediaJson(
            id: index + 1,
            movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
          ),
        ),
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': '错误'},
      },
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/invalid',
      body: _invalidMediaPage(
        page: 2,
        pageSize: 20,
        total: 21,
        items: [_invalidMediaJson(id: 21, movieNumber: 'ABC-021')],
      ),
    );

    await _pumpPage(tester, mediaApi: mediaApi, apiClient: apiClient, sessionStore: sessionStore);
    await tester.scrollUntilVisible(
      find.byKey(const Key('invalid-media-delete-20')),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text('加载更多失效媒体失败，请点击重试'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -120),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('ABC-021'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required MediaApi mediaApi,
  required ApiClient apiClient,
  required SessionStore sessionStore,
  MediaLibrariesApi? mediaLibrariesApi,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // 大多数测试用例只关心失效媒体流程，不 enqueue `/media-libraries` 响应；给个
  // 恒返回空的假实现避免 mediaLibrariesProvider 真的打接口把 adapter 打穿。
  final librariesApi =
      mediaLibrariesApi ?? _EmptyMediaLibrariesApi(apiClient: apiClient);

  await tester.pumpWidget(
    // MaskedImage 内部 context.read<SessionStore>() 拼 baseUrl，所以 legacy Provider
    // 树仍要挂 SessionStore；上层 ProviderScope 承担 Riverpod bridge。
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
      ],
      child: ProviderScope(
        overrides: [
          mediaApiProvider.overrideWithValue(mediaApi),
          mediaLibrariesApiProvider.overrideWithValue(librariesApi),
        ],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const OKToast(
            child: Scaffold(body: DesktopMediaMaintenancePage()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

class _EmptyMediaLibrariesApi extends MediaLibrariesApi {
  const _EmptyMediaLibrariesApi({required super.apiClient});

  @override
  Future<List<MediaLibraryDto>> getLibraries() async =>
      const <MediaLibraryDto>[];
}

Map<String, dynamic> _invalidMediaPage({
  int page = 1,
  int pageSize = 20,
  required int total,
  required List<Map<String, dynamic>> items,
}) {
  return <String, dynamic>{
    'items': items,
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}

Map<String, dynamic> _invalidMediaJson({
  required int id,
  required String movieNumber,
  String? title,
  String? coverUrl,
  String? thinCoverUrl,
}) {
  return <String, dynamic>{
    'id': id,
    'movie_number': movieNumber,
    'movie_title': title ?? 'Movie $id',
    'cover_image':
        coverUrl == null ? null : _imageJson(id: id * 10, url: coverUrl),
    'thin_cover_image': thinCoverUrl == null
        ? null
        : _imageJson(id: id * 10 + 1, url: thinCoverUrl),
    'path': '/library/main/$movieNumber.mp4',
    'library_id': 1,
    'library_name': 'Main Library',
    'file_size_bytes': 2147483648,
    'updated_at': '2026-05-13T12:00:00Z',
  };
}

Map<String, dynamic> _imageJson({required int id, required String url}) {
  return <String, dynamic>{
    'id': id,
    'origin': url,
    'small': url,
    'medium': url,
    'large': url,
  };
}

Map<String, dynamic> _validityResultJson({
  required int id,
  required bool revived,
  required bool validAfter,
}) {
  return <String, dynamic>{
    'id': id,
    'path': '/library/main/ABC-001.mp4',
    'file_exists': validAfter,
    'valid_before': false,
    'valid_after': validAfter,
    'updated': true,
    'invalidated': false,
    'revived': revived,
    'checked_at': '2026-05-13T12:10:00Z',
  };
}

String _localDateTimeText(String value) {
  final dateTime = DateTime.parse(value).toLocal();
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day $hour:$minute';
}
