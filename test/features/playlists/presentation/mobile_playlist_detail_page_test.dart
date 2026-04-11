import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/mobile_playlist_detail_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
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

  testWidgets('mobile playlist detail page renders banner and movie grid', (
    WidgetTester tester,
  ) async {
    _enqueuePlaylistDetailSuccess(bundle);
    _enqueuePlaylistMoviesSuccess(bundle);

    await _pumpPage(tester, bundle: bundle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-playlist-detail-page')),
      findsOneWidget,
    );
    final pageRoot = tester.widget<ColoredBox>(
      find.byKey(const Key('mobile-playlist-detail-page')),
    );
    expect(pageRoot.color, sakuraThemeData.appColors.surfaceCard);
    expect(find.text('我的收藏'), findsWidgets);
    expect(find.text('1 部影片'), findsOneWidget);
    expect(find.byKey(const Key('playlist-banner-card-8')), findsOneWidget);
    expect(find.byType(MovieSummaryCard), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets(
    'mobile playlist detail page shows empty state when detail fails',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/8',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
        },
      );
      _enqueuePlaylistMoviesSuccess(bundle);

      await _pumpPage(tester, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('播放列表详情暂时无法加载，请稍后重试'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile playlist detail page keeps header on movie load failure',
    (WidgetTester tester) async {
      _enqueuePlaylistDetailSuccess(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists/8/movies',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
        },
      );

      await _pumpPage(tester, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('我的收藏'), findsWidgets);
      expect(find.text('影片列表加载失败，请稍后重试'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile playlist detail page movie tap navigates to movie detail',
    (WidgetTester tester) async {
      _enqueuePlaylistDetailSuccess(bundle);
      _enqueuePlaylistMoviesSuccess(bundle);
      final router = GoRouter(
        initialLocation: buildMobilePlaylistDetailRoutePath(8),
        routes: [
          GoRoute(
            path: '$mobilePlaylistDetailPathPrefix/:playlistId',
            builder:
                (_, state) => MobilePlaylistDetailPage(
                  playlistId: int.parse(state.pathParameters['playlistId']!),
                ),
          ),
          GoRoute(
            path: '$mobileMoviesPath/:movieNumber',
            builder:
                (_, state) => Text(
                  'movie-detail:${state.pathParameters['movieNumber']}',
                  textDirection: TextDirection.ltr,
                ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await _pumpRouterPage(tester, bundle: bundle, router: router);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-summary-card-ABC-001')));
      await tester.pumpAndSettle();

      expect(find.text('movie-detail:ABC-001'), findsOneWidget);
      expect(router.canPop(), isTrue);
    },
  );
}

Future<void> _pumpPage(WidgetTester tester, {required TestApiBundle bundle}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: const OKToast(
          child: Scaffold(body: MobilePlaylistDetailPage(playlistId: 8)),
        ),
      ),
    ),
  );
}

Future<void> _pumpRouterPage(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required GoRouter router,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
      ],
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );
}

void _enqueuePlaylistDetailSuccess(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists/8',
    body: <String, dynamic>{
      'id': 8,
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
  );
}

void _enqueuePlaylistMoviesSuccess(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists/8/movies',
    body: <String, dynamic>{
      'items': [
        <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
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
      'page_size': 24,
      'total': 1,
    },
  );
}
