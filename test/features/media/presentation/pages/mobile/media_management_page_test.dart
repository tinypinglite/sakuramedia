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

/// 「媒体管理」移动端页测试：三 tab + 移动行卡 + 底部抽屉筛选 + 长按多选。
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

    // 页面挂载即建媒体列表 tab 与秒传轮询监听，给两个端点常驻空响应。
    adapter.setFallbackJson(method: 'GET', path: '/media', body: _emptyPage());
    adapter.setFallbackJson(
      method: 'GET',
      path: '/media/rapid-uploads',
      body: _emptyPage(),
    );
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders mobile tabs and mobile media rows', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1), _mediaItemJson(2)]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpPage(
      tester,
      mediaApi: mediaApi,
      apiClient: apiClient,
      sessionStore: sessionStore,
    );

    expect(
      find.byKey(const Key('mobile-media-management-page')),
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
      findsOneWidget,
    );
    // 移动行卡：流式布局（无固定行高），Key 前缀 mobile-。
    expect(
      find.byKey(const Key('mobile-media-management-row-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-row-2')),
      findsOneWidget,
    );
    // displayHeading 优先番号。
    expect(find.text('ABC-1'), findsOneWidget);
    expect(find.text('ABC-2'), findsOneWidget);
    // 移动端筛选入口是按钮而非桌面 popover 工具栏。
    expect(
      find.byKey(const Key('mobile-media-management-filter-trigger')),
      findsOneWidget,
    );
    expect(find.text('共 2 条'), findsOneWidget);
  });

  testWidgets('filter trigger opens bottom drawer with section group', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpPage(
      tester,
      mediaApi: mediaApi,
      apiClient: apiClient,
      sessionStore: sessionStore,
    );
    await tester.tap(
      find.byKey(const Key('mobile-media-management-filter-trigger')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-media-management-filter-drawer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-filter-scroll-view')),
      findsOneWidget,
    );
    // 筛选内容复用共享分节（归属 / 媒体库 / 排序）。
    expect(find.text('全部媒体'), findsWidgets);
  });

  testWidgets('long press enters selection mode with toolbar and bottom bar', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1), _mediaItemJson(2)]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpPage(
      tester,
      mediaApi: mediaApi,
      apiClient: apiClient,
      sessionStore: sessionStore,
    );

    // 初始非多选态：无选择工具栏与底部操作条。
    expect(
      find.byKey(const Key('mobile-media-management-exit-selection-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
      findsNothing,
    );

    // 长按第一行 → 进入多选态：顶栏选择工具栏 + 底部操作条 + 该行被选中。
    await tester.longPress(
      find.byKey(const Key('mobile-media-management-row-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-media-management-exit-selection-button')),
      findsOneWidget,
    );
    // 顶栏选择工具栏与底部操作条各有一处计数。
    expect(find.text('已选 1 项'), findsNWidgets(2));
    expect(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-management-rapid-upload-button')),
      findsOneWidget,
    );

    // 多选态点击第二行 → 选中并计数。
    await tester.tap(find.byKey(const Key('mobile-media-management-row-2')));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsNWidgets(2));

    // 退出多选态：清空选择并恢复普通头。
    await tester.tap(
      find.byKey(const Key('mobile-media-management-exit-selection-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mobile-media-management-filter-trigger')),
      findsOneWidget,
    );
  });

  testWidgets('select all toggles between 全选本页 and 取消全选本页', (tester) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1), _mediaItemJson(2)]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpPage(
      tester,
      mediaApi: mediaApi,
      apiClient: apiClient,
      sessionStore: sessionStore,
    );
    await tester.longPress(
      find.byKey(const Key('mobile-media-management-row-1')),
    );
    await tester.pumpAndSettle();

    // 长按后只选 1 项，未全选 → 「全选本页」。
    expect(find.text('全选本页'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('mobile-media-management-select-all-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('取消全选本页'), findsOneWidget);
    expect(find.text('已选 2 项'), findsNWidgets(2));

    // 已全选再点 → 取消全选当前页，多选态保留。
    await tester.tap(
      find.byKey(const Key('mobile-media-management-select-all-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('全选本页'), findsOneWidget);
    expect(find.text('已选 0 项'), findsNWidgets(2));

    // 取消全选后仍可逐行点选。
    await tester.tap(find.byKey(const Key('mobile-media-management-row-1')));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 项'), findsNWidgets(2));
  });

  testWidgets('batch delete from selection bar opens confirm dialog', (
    tester,
  ) async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media',
      body: _mediaPage(items: [_mediaItemJson(1)]),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpPage(
      tester,
      mediaApi: mediaApi,
      apiClient: apiClient,
      sessionStore: sessionStore,
    );
    await tester.longPress(
      find.byKey(const Key('mobile-media-management-row-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-management-batch-delete-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('批量删除媒体'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('media-management-batch-delete-cancel-button')),
    );
    await tester.pumpAndSettle();
    // 取消后仍停留在多选态。
    expect(
      find.byKey(const Key('mobile-media-management-batch-delete-button')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required MediaApi mediaApi,
  required ApiClient apiClient,
  required SessionStore sessionStore,
  MediaLibrariesApi? mediaLibrariesApi,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final librariesApi =
      mediaLibrariesApi ?? _EmptyMediaLibrariesApi(apiClient: apiClient);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        mediaApiProvider.overrideWithValue(mediaApi),
        mediaLibrariesApiProvider.overrideWithValue(librariesApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: const OKToast(child: Scaffold(body: MobileMediaManagementPage())),
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

Map<String, dynamic> _emptyPage() {
  return <String, dynamic>{
    'items': const <Map<String, dynamic>>[],
    'page': 1,
    'page_size': 20,
    'total': 0,
  };
}

Map<String, dynamic> _mediaPage({required List<Map<String, dynamic>> items}) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': 20,
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
    'path': '/library/main/abc-$id.mp4',
    'file_size_bytes': 100,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'special_tags': '普通',
    'valid': true,
    'heat': 100,
    'last_rapid_upload_status': null,
    'created_at': '2026-03-12T10:00:00Z',
    'updated_at': '2026-03-12T10:00:00Z',
  };
}
