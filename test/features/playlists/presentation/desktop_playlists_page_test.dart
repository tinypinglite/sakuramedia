import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/playlists/data/playlist_order_store.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/desktop_playlist_detail_page.dart';
import 'package:sakuramedia/features/playlists/presentation/desktop_playlists_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  testWidgets(
    'playlists page shows loading skeleton before request completes',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/playlists',
        responder: (options, requestBody) async {
          await completer.future;
          return ResponseBody.fromString(
            jsonEncode(_playlistsJson()),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pump();

      expect(find.byKey(const Key('playlists-page-loading')), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('playlists page renders banners and navigates to detail', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: _playlistsJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/1/movies',
      body: _playlistMoviesJson(movieNumber: 'ABC-001'),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/2/movies',
      body: _playlistMoviesJson(movieNumber: 'SSNI-002'),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/2',
      body: _playlistsJson()[1],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/2/movies',
      body: _playlistMoviesJson(movieNumber: 'SSNI-002'),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/desktop/library/playlists',
          builder: (context, state) => const DesktopPlaylistsPage(),
        ),
        GoRoute(
          path: '/desktop/library/playlists/:playlistId',
          builder:
              (context, state) => DesktopPlaylistDetailPage(
                playlistId: int.parse(state.pathParameters['playlistId']!),
              ),
        ),
      ],
      initialLocation: '/desktop/library/playlists',
    );
    addTearDown(router.dispose);

    await _pumpRouterPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      router: router,
    );
    await tester.pumpAndSettle();

    expect(find.text('最近播放'), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.byKey(const Key('playlists-create-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('playlist-banner-card-2')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/playlists/2',
    );
    expect(find.text('我的收藏'), findsWidgets);
  });

  testWidgets('playlists page creates playlist from dialog', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: _playlistsJson().sublist(0, 1),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/1/movies',
      body: _playlistMoviesJson(movieNumber: 'ABC-001'),
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/playlists',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 3,
        'name': '稍后再看',
        'kind': 'custom',
        'description': 'Need watch later',
        'is_system': false,
        'is_mutable': true,
        'is_deletable': true,
        'movie_count': 0,
        'created_at': '2026-03-12T10:10:00Z',
        'updated_at': '2026-03-12T10:10:00Z',
      },
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('playlists-create-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create-playlist-name-field')),
      '稍后再看',
    );
    await tester.enterText(
      find.byKey(const Key('create-playlist-description-field')),
      'Need watch later',
    );
    await tester.tap(find.byKey(const Key('create-playlist-submit-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('稍后再看'), findsOneWidget);
  });

  testWidgets('playlists page applies locally stored order', (
    WidgetTester tester,
  ) async {
    final orderStore = InMemoryPlaylistOrderStore();
    await orderStore.savePlaylistOrder(
      scopeKey: 'https://api.example.com',
      playlistIds: <int>[2, 1],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: _playlistsJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/1/movies',
      body: _playlistMoviesJson(movieNumber: 'ABC-001'),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/2/movies',
      body: _playlistMoviesJson(movieNumber: 'SSNI-002'),
    );

    await _pumpPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      playlistOrderStore: orderStore,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey<int>(2))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey<int>(1))).dy),
    );
  });

  testWidgets('desktop playlists reorder handle is visible only on hover', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists',
      body: _playlistsJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/1/movies',
      body: _playlistMoviesJson(movieNumber: 'ABC-001'),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/2/movies',
      body: _playlistMoviesJson(movieNumber: 'SSNI-002'),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.unfold_more_rounded), findsNothing);
    expect(find.byKey(const Key('playlist-reorder-handle-1')), findsNothing);
    expect(find.byKey(const Key('playlist-reorder-handle-2')), findsNothing);

    final mouseGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(mouseGesture.removePointer);
    await mouseGesture.addPointer(location: Offset.zero);
    await mouseGesture.moveTo(
      tester.getCenter(find.byKey(const Key('playlist-banner-card-2'))),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
    expect(find.byKey(const Key('playlist-reorder-handle-1')), findsNothing);
    expect(find.byKey(const Key('playlist-reorder-handle-2')), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  PlaylistOrderStore? playlistOrderStore,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: OKToast(
          child: Scaffold(
            body: DesktopPlaylistsPage(
              playlistOrderStore:
                  playlistOrderStore ??
                  const SharedPreferencesPlaylistOrderStore(),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpRouterPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required GoRouter router,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
      ],
      child: MaterialApp.router(
        theme: sakuraThemeData,
        routerConfig: router,
        builder: (context, child) => OKToast(child: child!),
      ),
    ),
  );
}

List<Map<String, dynamic>> _playlistsJson() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'name': '最近播放',
      'kind': 'recently_played',
      'description': '系统自动维护的最近播放影片列表',
      'is_system': true,
      'is_mutable': false,
      'is_deletable': false,
      'movie_count': 1,
      'created_at': '2026-03-12T10:00:00Z',
      'updated_at': '2026-03-12T10:00:00Z',
    },
    <String, dynamic>{
      'id': 2,
      'name': '我的收藏',
      'kind': 'custom',
      'description': 'Favorite movies',
      'is_system': false,
      'is_mutable': true,
      'is_deletable': true,
      'movie_count': 1,
      'created_at': '2026-03-12T10:10:00Z',
      'updated_at': '2026-03-12T11:20:00Z',
    },
  ];
}

Map<String, dynamic> _playlistMoviesJson({required String movieNumber}) {
  return <String, dynamic>{
    'items': [
      <String, dynamic>{
        'javdb_id': 'MovieA1',
        'movie_number': movieNumber,
        'title': 'Movie 1',
        'cover_image': null,
        'release_date': '2024-01-02',
        'duration_minutes': 120,
        'score': 4.5,
        'watched_count': 0,
        'want_watch_count': 0,
        'comment_count': 0,
        'score_number': 0,
        'is_collection': false,
        'is_subscribed': false,
        'can_play': true,
        'playlist_item_updated_at': '2026-03-12T10:20:00Z',
      },
    ],
    'page': 1,
    'page_size': 1,
    'total': 1,
  };
}
