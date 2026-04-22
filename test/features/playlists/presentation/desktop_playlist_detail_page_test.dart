import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/desktop_playlist_detail_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
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

  testWidgets('playlist detail page renders banner and movie grid', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8',
      body: _playlistJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8/movies',
      body: _moviesJson(total: 1),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('我的收藏'), findsWidgets);
    expect(find.text('1 部影片'), findsOneWidget);
    expect(find.byKey(const Key('playlist-banner-card-8')), findsOneWidget);
    expect(find.byType(MovieSummaryCard), findsOneWidget);
  });

  testWidgets(
    'playlist detail page keeps pull to refresh disabled on desktop',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/8',
        body: _playlistJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/8/movies',
        body: _moviesJson(total: 1),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.text('1 部影片'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-ABC-001')),
        findsOneWidget,
      );
    },
  );

  testWidgets('playlist detail page opens movie detail route on tap', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8',
      body: _playlistJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8/movies',
      body: _moviesJson(total: 1),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/desktop/library/playlists/8',
          builder:
              (context, state) =>
                  const DesktopPlaylistDetailPage(playlistId: 8),
        ),
        GoRoute(
          path: '/desktop/library/movies/:movieNumber',
          builder:
              (context, state) => Text(
                'movie:${state.pathParameters['movieNumber']}',
                textDirection: TextDirection.ltr,
              ),
        ),
      ],
      initialLocation: '/desktop/library/playlists/8',
    );
    addTearDown(router.dispose);

    await _pumpRouterPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      router: router,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
    await tester.pumpAndSettle();

    expect(find.text('movie:ABC-001'), findsOneWidget);
  });

  testWidgets('playlist detail page keeps header on movie load failure', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8',
      body: _playlistJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/playlists/8/movies',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('我的收藏'), findsWidgets);
    expect(find.text('影片列表加载失败，请稍后重试'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: const OKToast(
          child: Scaffold(body: DesktopPlaylistDetailPage(playlistId: 8)),
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
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
      ],
      child: MaterialApp.router(
        theme: sakuraThemeData,
        routerConfig: router,
        builder: (context, child) => OKToast(child: child!),
      ),
    ),
  );
}

Map<String, dynamic> _playlistJson({int movieCount = 1}) {
  return <String, dynamic>{
    'id': 8,
    'name': '我的收藏',
    'kind': 'custom',
    'description': 'Favorite movies',
    'is_system': false,
    'is_mutable': true,
    'is_deletable': true,
    'movie_count': movieCount,
    'created_at': '2026-03-12T10:10:00Z',
    'updated_at': '2026-03-12T11:20:00Z',
  };
}

Map<String, dynamic> _moviesJson({
  required int total,
  String movieNumber = 'ABC-001',
  String title = 'Movie 1',
}) {
  return <String, dynamic>{
    'items': [
      <String, dynamic>{
        'javdb_id': 'MovieA1',
        'movie_number': movieNumber,
        'title': title,
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
    'page_size': 24,
    'total': total,
  };
}
