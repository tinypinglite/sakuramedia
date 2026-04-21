import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/mobile_playlists_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';

import '../../../support/test_api_bundle.dart';

late SessionStore _sessionStore;
late TestApiBundle _bundle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _sessionStore = SessionStore.inMemory();
    await _sessionStore.saveBaseUrl('https://api.example.com');
    await _sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    _bundle = await createTestApiBundle(_sessionStore);
  });

  tearDown(() {
    _bundle.dispose();
  });

  testWidgets('shows loading skeleton before playlists request completes', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    _enqueuePlaylistCoverRequests(_bundle, const <int>[2, 5]);

    _bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/playlists',
      responder: (_, __) async {
        await completer.future;
        return ResponseBody.fromString(
          jsonEncode(_customPlaylistsJson()),
          200,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    await _pumpPage(tester);
    await tester.pump();

    expect(find.byKey(const Key('mobile-playlist-skeleton-0')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-playlists-notice-card')),
      findsOneWidget,
    );

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'renders custom playlists only and uses false include_system query',
    (WidgetTester tester) async {
      _enqueuePlaylistCoverRequests(_bundle, const <int>[2, 5, 9]);
      _bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          ..._customPlaylistsJson(),
          <String, dynamic>{
            'id': 9,
            'name': '系统列表',
            'kind': 'system',
            'description': 'system',
            'is_system': true,
            'is_mutable': false,
            'is_deletable': false,
            'movie_count': 4,
            'created_at': '2026-03-10T10:10:00Z',
            'updated_at': '2026-03-10T11:20:00Z',
          },
        ],
      );

      await _pumpPage(tester);
      await tester.pumpAndSettle();

      final request = _bundle.adapter.requests.firstWhere(
        (item) => item.method == 'GET' && item.path == '/playlists',
      );
      expect(request.uri.queryParameters['include_system'], 'false');
      expect(
        find.byKey(const Key('mobile-playlist-management-card-2')),
        findsOneWidget,
      );
      expect(find.text('系统列表'), findsNothing);
      expect(find.text('未填写描述'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('mobile-playlists-notice-card')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('mobile-playlists-notice-card')),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows load error and retries to empty state', (
    WidgetTester tester,
  ) async {
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': '播放列表加载失败，请稍后重试。',
        },
      },
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-playlists-error-state')),
      findsOneWidget,
    );
    expect(find.text('播放列表加载失败，请稍后重试。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-playlists-retry-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-playlists-empty-state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-playlists-create-button')),
      findsOneWidget,
    );
  });

  testWidgets('pull to refresh failure keeps current list and shows toast', (
    WidgetTester tester,
  ) async {
    await _pumpPage(
      tester,
      api: _RefreshFailurePlaylistsApi(
        apiClient: _bundle.apiClient,
        initialPlaylists:
            _customPlaylistsJson().map(PlaylistDto.fromJson).toList(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-playlist-management-card-2')),
      findsOneWidget,
    );

    final pullToRefresh = tester.widget<AppPullToRefresh>(
      find.byType(AppPullToRefresh),
    );
    await pullToRefresh.onRefresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('mobile-playlist-management-card-2')),
      findsOneWidget,
    );
    expect(find.text('播放列表加载失败，请稍后重试。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('creates playlist from bottom drawer and syncs list', (
    WidgetTester tester,
  ) async {
    _enqueuePlaylistCoverRequests(_bundle, const <int>[7]);
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/playlists',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 7,
        'name': '补番队列',
        'kind': 'custom',
        'description': '本周处理',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'movie_count': 0,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-12T10:10:00Z',
      },
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 7,
          'name': '补番队列',
          'kind': 'custom',
          'description': '本周处理',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 0,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T10:10:00Z',
        },
      ],
    );

    await _pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-playlists-create-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('create-playlist-bottom-sheet')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('create-playlist-name-field')),
      '补番队列',
    );
    await tester.enterText(
      find.byKey(const Key('create-playlist-description-field')),
      '本周处理',
    );
    await tester.tap(find.byKey(const Key('create-playlist-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final postRequest = _bundle.adapter.requests.firstWhere(
      (request) => request.method == 'POST' && request.path == '/playlists',
    );
    expect(postRequest.body['name'], '补番队列');
    expect(postRequest.body['description'], '本周处理');
    expect(
      find.byKey(const Key('mobile-playlist-management-card-7')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('view action navigates to playlist detail route', (
    WidgetTester tester,
  ) async {
    _enqueuePlaylistCoverRequests(_bundle, const <int>[2, 5]);
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: _customPlaylistsJson(),
    );
    final router = GoRouter(
      initialLocation: mobileSettingsPlaylistsPath,
      routes: [
        GoRoute(
          path: mobileSettingsPlaylistsPath,
          builder: (_, __) => const MobilePlaylistsPage(),
        ),
        GoRoute(
          path: '$mobilePlaylistDetailPathPrefix/:playlistId',
          builder:
              (_, state) => Text(
                'playlist-detail:${state.pathParameters['playlistId']}',
                textDirection: TextDirection.ltr,
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouterPage(tester, router: router);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-playlist-view-2')));
    await tester.pumpAndSettle();

    expect(find.text('playlist-detail:2'), findsOneWidget);
  });

  testWidgets('edits playlist from action button and syncs list', (
    WidgetTester tester,
  ) async {
    _enqueuePlaylistCoverRequests(_bundle, const <int>[2, 5, 2]);
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: _customPlaylistsJson(),
    );
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/playlists/2',
      body: <String, dynamic>{
        'id': 2,
        'name': '稍后再看（已整理）',
        'kind': 'custom',
        'description': '本周重点',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'movie_count': 3,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-13T10:10:00Z',
      },
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 2,
          'name': '稍后再看（已整理）',
          'kind': 'custom',
          'description': '本周重点',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 3,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-13T10:10:00Z',
        },
      ],
    );

    await _pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-playlist-edit-2')));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('mobile-playlist-name-field')),
    );
    final descriptionField = tester.widget<TextFormField>(
      find.byKey(const Key('mobile-playlist-description-field')),
    );
    expect(nameField.controller?.text, '稍后再看');
    expect(descriptionField.controller?.text, '');

    await tester.enterText(
      find.byKey(const Key('mobile-playlist-name-field')),
      '稍后再看（已整理）',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-playlist-description-field')),
      '本周重点',
    );
    await tester.tap(find.byKey(const Key('mobile-playlist-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) => request.method == 'PATCH' && request.path == '/playlists/2',
    );
    expect(patchRequest.body['name'], '稍后再看（已整理）');
    expect(patchRequest.body['description'], '本周重点');
    expect(
      find.byKey(const Key('mobile-playlist-management-card-2')),
      findsOneWidget,
    );
    expect(find.text('本周重点'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('deletes playlist from confirm drawer and syncs list', (
    WidgetTester tester,
  ) async {
    _enqueuePlaylistCoverRequests(_bundle, const <int>[2, 5]);
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: _customPlaylistsJson(),
    );
    _bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/playlists/2',
      statusCode: 204,
    );
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: const <Map<String, dynamic>>[],
    );

    await _pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-playlist-delete-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mobile-playlist-delete-confirm-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_bundle.adapter.hitCount('DELETE', '/playlists/2'), 1);
    expect(
      find.byKey(const Key('mobile-playlists-empty-state')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpPage(WidgetTester tester, {PlaylistsApi? api}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PlaylistsApi>.value(value: api ?? _bundle.playlistsApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobilePlaylistsPage()),
        ),
      ),
    ),
  );
}

Future<void> _pumpRouterPage(
  WidgetTester tester, {
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<PlaylistsApi>.value(value: _bundle.playlistsApi)],
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );
}

List<Map<String, dynamic>> _customPlaylistsJson() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 2,
      'name': '稍后再看',
      'kind': 'custom',
      'description': '',
      'is_system': false,
      'is_mutable': true,
      'is_deletable': true,
      'movie_count': 3,
      'created_at': '2026-03-12T10:10:00Z',
      'updated_at': '2026-03-12T11:20:00Z',
    },
    <String, dynamic>{
      'id': 5,
      'name': '周末合集',
      'kind': 'custom',
      'description': '轻松补完',
      'is_system': false,
      'is_mutable': true,
      'is_deletable': true,
      'movie_count': 2,
      'created_at': '2026-03-10T10:10:00Z',
      'updated_at': '2026-03-11T11:20:00Z',
    },
  ];
}

void _enqueuePlaylistCoverRequests(
  TestApiBundle bundle,
  List<int> playlistIds,
) {
  for (final playlistId in playlistIds) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/$playlistId/movies',
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 1,
        'total': 0,
      },
    );
  }
}

class _RefreshFailurePlaylistsApi extends PlaylistsApi {
  _RefreshFailurePlaylistsApi({
    required super.apiClient,
    required this.initialPlaylists,
  });

  final List<PlaylistDto> initialPlaylists;
  int _playlistLoadCount = 0;

  @override
  Future<List<PlaylistDto>> getPlaylists({bool includeSystem = true}) async {
    if (_playlistLoadCount == 0) {
      _playlistLoadCount += 1;
      return initialPlaylists;
    }
    throw DioException(
      requestOptions: RequestOptions(path: '/playlists'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/playlists'),
        statusCode: 500,
        data: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'server_error',
            'message': '播放列表加载失败，请稍后重试。',
          },
        },
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<PaginatedResponseDto<MovieListItemDto>> getPlaylistMovies({
    required int playlistId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PaginatedResponseDto<MovieListItemDto>(
      items: <MovieListItemDto>[],
      page: 1,
      pageSize: 1,
      total: 0,
    );
  }
}
