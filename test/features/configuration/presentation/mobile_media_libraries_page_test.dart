import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/mobile_media_libraries_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';

import '../../../support/test_api_bundle.dart';

late SessionStore _sessionStore;
late TestApiBundle _bundle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _sessionStore = await _buildLoggedInSessionStore();
    _bundle = await createTestApiBundle(_sessionStore);
  });

  tearDown(() {
    _bundle.dispose();
  });

  testWidgets('renders notice card, empty state and fixed create action', (
    WidgetTester tester,
  ) async {
    _enqueueMediaLibraries(_bundle, libraries: const <Map<String, dynamic>>[]);

    await _pumpPage(tester);

    expect(
      find.byKey(const Key('mobile-settings-media-libraries')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-libraries-notice-card')),
      findsOneWidget,
    );
    expect(find.text('媒体库存储路径'), findsOneWidget);
    expect(
      find.text('媒体库用于维护本地媒体存储根路径，下载器等模块会依赖这里的路径配置。'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-media-libraries-empty-state')),
      findsOneWidget,
    );
    expect(find.text('还没有媒体库'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-media-libraries-create-button')),
      findsOneWidget,
    );
  });

  testWidgets('shows load error and retries to empty state', (
    WidgetTester tester,
  ) async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': '媒体库加载失败，请稍后重试。',
        },
      },
    );
    _enqueueMediaLibraries(_bundle, libraries: const <Map<String, dynamic>>[]);

    await _pumpPage(tester);

    expect(
      find.byKey(const Key('mobile-media-libraries-error-state')),
      findsOneWidget,
    );
    expect(find.text('媒体库加载失败，请稍后重试。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-media-libraries-retry-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-media-libraries-empty-state')),
      findsOneWidget,
    );
  });

  testWidgets('pull to refresh failure keeps current list and shows toast', (
    WidgetTester tester,
  ) async {
    final api = _RefreshFailureMediaLibrariesApi(
      apiClient: _bundle.apiClient,
      initialLibraries: const <MediaLibraryDto>[
        MediaLibraryDto(
          id: 1,
          name: 'Main Library',
          rootPath: '/media/library/main',
          createdAt: null,
          updatedAt: null,
        ),
      ],
    );

    await _pumpPage(tester, api: api);

    expect(find.text('Main Library'), findsOneWidget);

    final pullToRefresh = tester.widget<AppPullToRefresh>(
      find.byType(AppPullToRefresh),
    );
    await pullToRefresh.onRefresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Main Library'), findsOneWidget);
    expect(find.text('媒体库加载失败，请稍后重试。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('creates media library and syncs list', (WidgetTester tester) async {
    _enqueueMediaLibraries(_bundle, libraries: const <Map<String, dynamic>>[]);
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/media-libraries',
      body: <String, dynamic>{
        'id': 2,
        'name': 'Archive Library',
        'root_path': '/media/library/archive',
        'created_at': '2026-03-09T09:30:00Z',
        'updated_at': '2026-03-09T09:30:00Z',
      },
    );
    _enqueueMediaLibraries(
      _bundle,
      libraries: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 2,
          'name': 'Archive Library',
          'root_path': '/media/library/archive',
          'created_at': '2026-03-09T09:30:00Z',
          'updated_at': '2026-03-09T09:30:00Z',
        },
      ],
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-media-libraries-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('media-library-name-field')),
      'Archive Library',
    );
    await tester.enterText(
      find.byKey(const Key('media-library-root-path-field')),
      '/media/library/archive',
    );
    await tester.tap(find.byKey(const Key('mobile-media-library-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final postRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'POST' && request.path == '/media-libraries',
    );
    expect(postRequest.body['name'], 'Archive Library');
    expect(postRequest.body['root_path'], '/media/library/archive');
    expect(find.text('Archive Library'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('validates relative root path before create submit', (
    WidgetTester tester,
  ) async {
    _enqueueMediaLibraries(_bundle, libraries: const <Map<String, dynamic>>[]);

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-media-libraries-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('media-library-name-field')),
      'Archive Library',
    );
    await tester.enterText(
      find.byKey(const Key('media-library-root-path-field')),
      'relative/path',
    );
    await tester.tap(find.byKey(const Key('mobile-media-library-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('请输入路径'), findsOneWidget);
    expect(_bundle.adapter.hitCount('POST', '/media-libraries'), 0);
  });

  testWidgets('shows backend error when create media library fails', (
    WidgetTester tester,
  ) async {
    _enqueueMediaLibraries(_bundle, libraries: const <Map<String, dynamic>>[]);
    _bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/media-libraries',
      responder: (_, __) async {
        return ResponseBody.fromString(
          jsonEncode({
            'error': <String, dynamic>{
              'code': 'media_library_conflict',
              'message': '媒体库名称已存在',
            },
          }),
          409,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-media-libraries-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('media-library-name-field')),
      'Main Library',
    );
    await tester.enterText(
      find.byKey(const Key('media-library-root-path-field')),
      '/media/library/main',
    );
    await tester.tap(find.byKey(const Key('mobile-media-library-submit-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('媒体库名称已存在'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-media-library-editor-drawer')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('edits media library from card tap and syncs list', (
    WidgetTester tester,
  ) async {
    _enqueueMediaLibraries(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/media-libraries/1',
      body: <String, dynamic>{
        'id': 1,
        'name': 'Main Library Updated',
        'root_path': '/media/library/updated',
        'created_at': '2026-03-08T09:30:00Z',
        'updated_at': '2026-03-10T09:30:00Z',
      },
    );
    _enqueueMediaLibraries(
      _bundle,
      libraries: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Main Library Updated',
          'root_path': '/media/library/updated',
          'created_at': '2026-03-08T09:30:00Z',
          'updated_at': '2026-03-10T09:30:00Z',
        },
      ],
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-media-library-card-body-1')));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('media-library-name-field')),
    );
    final rootPathField = tester.widget<TextFormField>(
      find.byKey(const Key('media-library-root-path-field')),
    );
    expect(nameField.controller?.text, 'Main Library');
    expect(rootPathField.controller?.text, '/media/library/main');

    await tester.enterText(
      find.byKey(const Key('media-library-name-field')),
      'Main Library Updated',
    );
    await tester.enterText(
      find.byKey(const Key('media-library-root-path-field')),
      '/media/library/updated',
    );
    await tester.tap(find.byKey(const Key('mobile-media-library-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'PATCH' && request.path == '/media-libraries/1',
    );
    expect(patchRequest.body['name'], 'Main Library Updated');
    expect(patchRequest.body['root_path'], '/media/library/updated');
    expect(find.text('Main Library Updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('delete flow can be canceled from confirm drawer', (
    WidgetTester tester,
  ) async {
    _enqueueMediaLibraries(_bundle);

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-media-library-more-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-media-library-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(_bundle.adapter.hitCount('DELETE', '/media-libraries/1'), 0);
    expect(find.byKey(const Key('mobile-media-library-card-1')), findsOneWidget);
  });

  testWidgets('deletes media library from action sheet and syncs list', (
    WidgetTester tester,
  ) async {
    _enqueueMediaLibraries(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media-libraries/1',
      statusCode: 204,
    );
    _enqueueMediaLibraries(_bundle, libraries: const <Map<String, dynamic>>[]);

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-media-library-more-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-media-library-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-media-library-delete-confirm-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_bundle.adapter.hitCount('DELETE', '/media-libraries/1'), 1);
    expect(find.text('还没有媒体库'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows backend error when delete media library fails', (
    WidgetTester tester,
  ) async {
    _enqueueMediaLibraries(_bundle);
    _bundle.adapter.enqueueResponder(
      method: 'DELETE',
      path: '/media-libraries/1',
      responder: (_, __) async {
        return ResponseBody.fromString(
          jsonEncode({
            'error': <String, dynamic>{
              'code': 'media_library_in_use',
              'message': '媒体库仍被业务数据引用，无法删除',
            },
          }),
          409,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-media-library-more-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-media-library-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-media-library-delete-confirm-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('媒体库仍被业务数据引用，无法删除'), findsOneWidget);
    expect(find.byKey(const Key('mobile-media-library-card-1')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-media-library-delete-drawer')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  MediaLibrariesApi? api,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<MediaLibrariesApi>.value(value: api ?? _bundle.mediaLibrariesApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobileMediaLibrariesPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RefreshFailureMediaLibrariesApi extends MediaLibrariesApi {
  _RefreshFailureMediaLibrariesApi({
    required super.apiClient,
    required this.initialLibraries,
  });

  final List<MediaLibraryDto> initialLibraries;
  int _requestCount = 0;

  @override
  Future<List<MediaLibraryDto>> getLibraries() async {
    _requestCount += 1;
    if (_requestCount == 1) {
      return initialLibraries;
    }
    throw Exception('refresh failed');
  }
}

void _enqueueMediaLibraries(
  TestApiBundle bundle, {
  List<Map<String, dynamic>>? libraries,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body:
        libraries ??
        const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': 'Main Library',
            'root_path': '/media/library/main',
            'created_at': '2026-03-08T09:30:00Z',
            'updated_at': '2026-03-08T10:30:00Z',
          },
        ],
  );
}

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'mobile-access-token',
    refreshToken: 'mobile-refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}
