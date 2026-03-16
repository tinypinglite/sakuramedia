import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/moments/presentation/mobile_overview_moments_tab.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_image_search_route_state.dart';
import 'package:sakuramedia/theme.dart';

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

  testWidgets('mobile moments tab loads latest moments and shows total', (
    WidgetTester tester,
  ) async {
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');

    await _pumpMomentsApp(tester, bundle: bundle, sessionStore: sessionStore);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-overview-moments-tab')),
      findsOneWidget,
    );
    final latestSortLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('mobile-moments-sort-latest')),
        matching: find.text('最新'),
      ),
    );
    expect(latestSortLabel.style?.fontSize, 10);
    expect(find.byKey(const Key('mobile-moments-page-total')), findsOneWidget);
    expect(find.text('1 个时刻'), findsOneWidget);
    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text('02:00'), findsOneWidget);
    expect(_mediaPointsQueryValue(bundle, 0, 'sort'), 'created_at:desc');
    expect(bundle.adapter.hitCount('GET', '/media/456/thumbnails'), 0);
  });

  testWidgets('mobile moments tab reloads with earliest sort', (
    WidgetTester tester,
  ) async {
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:asc');

    await _pumpMomentsApp(tester, bundle: bundle, sessionStore: sessionStore);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-moments-sort-earliest')));
    await tester.pumpAndSettle();

    expect(_mediaPointsQueryValue(bundle, 1, 'sort'), 'created_at:asc');
  });

  testWidgets(
    'mobile moments preview opens bottom drawer and navigates detail',
    (WidgetTester tester) async {
      _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');
      _enqueuePreviewResponses(bundle);
      Object? detailRouteExtra;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder:
                (_, __) => const Scaffold(body: MobileOverviewMomentsTab()),
          ),
          GoRoute(
            path: '$mobileMoviesPath/:movieNumber',
            builder: (_, state) {
              detailRouteExtra = state.extra;
              return Scaffold(
                body: Text(
                  'movie:${state.pathParameters['movieNumber']}',
                  textDirection: TextDirection.ltr,
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await _pumpMomentsRouterApp(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('moment-card-10')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mobile-moments-preview-bottom-sheet')),
        findsOneWidget,
      );
      expect(find.textContaining('相似度'), findsNothing);

      await tester.tap(find.text('影片详情'));
      await tester.pumpAndSettle();

      expect(find.text('movie:ABC-001'), findsOneWidget);
      expect(detailRouteExtra, mobileOverviewPath);
    },
  );

  testWidgets('mobile moments preview similar image routes to image search', (
    WidgetTester tester,
  ) async {
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');
    _enqueuePreviewResponses(bundle);
    bundle.adapter.enqueueBytes(
      method: 'GET',
      path: '/thumb-1.webp',
      body: Uint8List.fromList(const <int>[1, 2, 3, 4]),
    );
    Object? imageSearchExtra;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: MobileOverviewMomentsTab()),
        ),
        GoRoute(
          path: mobileImageSearchPath,
          builder: (_, state) {
            imageSearchExtra = state.extra;
            return const Scaffold(body: Text('mobile-image-search'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpMomentsRouterApp(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      router: router,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('moment-card-10')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('相似图片'));
    await tester.pumpAndSettle();

    expect(find.text('mobile-image-search'), findsOneWidget);
    final routeState = imageSearchExtra as DesktopImageSearchRouteState;
    expect(routeState.fallbackPath, mobileOverviewPath);
    expect(routeState.initialFileName, 'moment_ABC-001_10.webp');
    expect(routeState.initialFileBytes, const <int>[1, 2, 3, 4]);
    expect(routeState.initialMimeType, 'image/webp');
  });
}

Future<void> _pumpMomentsApp(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required SessionStore sessionStore,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<MediaApi>(
          create: (_) => MediaApi(apiClient: bundle.apiClient),
        ),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: MobileOverviewMomentsTab()),
      ),
    ),
  );
}

Future<void> _pumpMomentsRouterApp(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<MediaApi>(
          create: (_) => MediaApi(apiClient: bundle.apiClient),
        ),
      ],
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );
}

void _enqueueMomentsPageResponses(
  TestApiBundle bundle, {
  required String sort,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-points',
    body: <String, dynamic>{
      'items': [
        <String, dynamic>{
          'point_id': 10,
          'media_id': 456,
          'movie_number': 'ABC-001',
          'thumbnail_id': 1,
          'offset_seconds': 120,
          'image': <String, dynamic>{
            'id': 10,
            'origin': '/thumb-1.webp',
            'small': '/thumb-1.webp',
            'medium': '/thumb-1.webp',
            'large': '/thumb-1.webp',
          },
          'created_at': '2026-03-12T10:00:00Z',
        },
      ],
      'page': 1,
      'page_size': 20,
      'total': 1,
    },
  );
  expect(sort, isNotEmpty);
}

void _enqueuePreviewResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/ABC-001',
    body: <String, dynamic>{
      'javdb_id': 'MovieA1',
      'movie_number': 'ABC-001',
      'title': 'Movie 1',
      'series_name': '',
      'cover_image': <String, dynamic>{
        'id': 1,
        'origin': '/cover.jpg',
        'small': '/cover.jpg',
        'medium': '/cover.jpg',
        'large': '/cover.jpg',
      },
      'release_date': null,
      'duration_minutes': 0,
      'score': 0,
      'watched_count': 0,
      'want_watch_count': 0,
      'comment_count': 0,
      'score_number': 0,
      'is_collection': false,
      'is_subscribed': false,
      'can_play': true,
      'summary': '',
      'thin_cover_image': null,
      'plot_images': const <Map<String, dynamic>>[],
      'actors': const <Map<String, dynamic>>[],
      'tags': const <Map<String, dynamic>>[],
      'media_items': [
        <String, dynamic>{
          'media_id': 456,
          'library_id': 1,
          'play_url': '/files/media/movies/ABC-001/video.mp4',
          'path': '/library/main/ABC-001/video.mp4',
          'storage_mode': 'hardlink',
          'resolution': '1920x1080',
          'file_size_bytes': 1073741824,
          'duration_seconds': 7200,
          'special_tags': '普通',
          'valid': true,
          'progress': null,
          'points': [
            <String, dynamic>{'point_id': 10, 'offset_seconds': 120},
          ],
        },
      ],
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media/456/points',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'point_id': 10,
        'media_id': 456,
        'thumbnail_id': 1,
        'offset_seconds': 120,
        'image': <String, dynamic>{
          'id': 10,
          'origin': '/thumb-1.webp',
          'small': '/thumb-1.webp',
          'medium': '/thumb-1.webp',
          'large': '/thumb-1.webp',
        },
        'created_at': '2026-03-12T10:00:00Z',
      },
    ],
  );
}

String? _mediaPointsQueryValue(
  TestApiBundle bundle,
  int requestIndex,
  String key,
) {
  final requests = bundle.adapter.requests
      .where((request) => request.path == '/media-points')
      .toList(growable: false);
  if (requestIndex >= requests.length) {
    return null;
  }
  return requests[requestIndex].uri.queryParameters[key];
}
