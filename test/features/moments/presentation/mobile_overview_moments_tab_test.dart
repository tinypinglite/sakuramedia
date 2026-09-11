import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';
import 'package:sakuramedia/features/moments/presentation/pages/mobile/overview_moments_tab.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';

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
    // 筛选收口到顶栏入口，摘要只报「内容类型」这一主维度。
    expect(
      tester
          .widget<AppFilterEntryButton>(find.byType(AppFilterEntryButton))
          .label,
      'JAV',
    );
    expect(find.text('最新'), findsNothing);
    expect(find.byKey(const Key('mobile-moments-page-total')), findsOneWidget);
    expect(find.text('1 个时刻'), findsOneWidget);
    expect(
      tester
          .getCenter(
            find.byKey(const Key('mobile-moments-enter-selection-button')),
          )
          .dy,
      closeTo(
        tester
            .getCenter(find.byKey(const Key('mobile-moments-filter-trigger')))
            .dy,
        0.1,
      ),
    );
    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text('02:00'), findsOneWidget);
    expect(_mediaPointsQueryValue(bundle, 0, 'sort'), 'created_at:desc');
    expect(bundle.adapter.hitCount('GET', '/media/456/thumbnails'), 0);
  });

  testWidgets('mobile moments tab shows collections before all moments', (
    WidgetTester tester,
  ) async {
    _enqueueMomentCollectionsResponse(bundle);
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');

    await _pumpMomentsApp(tester, bundle: bundle, sessionStore: sessionStore);
    await tester.pumpAndSettle();

    expect(find.text('时刻合集'), findsOneWidget);
    expect(find.text('全部时刻'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-moments-create-collection-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-moments-view-all-collections-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('moment-collection-card-7')), findsOneWidget);
    expect(find.byTooltip('加入合集'), findsNothing);
    expect(
      tester.getTopLeft(find.text('时刻合集')).dy,
      lessThan(tester.getTopLeft(find.text('全部时刻')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile moments can select and batch add to a collection', (
    WidgetTester tester,
  ) async {
    _enqueueMomentCollectionsResponse(bundle);
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');
    _enqueueMomentCollectionsResponse(bundle);
    _enqueueMomentCollectionsResponse(bundle);
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/7/points/10',
      statusCode: 204,
    );

    await _pumpMomentsApp(tester, bundle: bundle, sessionStore: sessionStore);
    await tester.pumpAndSettle();

    final momentCardTop = tester
        .getTopLeft(find.byKey(const Key('moment-card-10')))
        .dy;
    await tester.tap(
      find.byKey(const Key('mobile-moments-enter-selection-button')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('moment-card-10'))).dy,
      closeTo(momentCardTop, 0.1),
    );
    await tester.tap(find.byKey(const Key('moment-card-10')));
    await tester.pumpAndSettle();

    expect(find.text('已选 1 个'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('mobile-moments-batch-add-collection-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-moment-collection-7')));
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount('PUT', '/moment-collections/7/points/10'),
      1,
    );
    expect(find.text('已选 1 个'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile moments can batch delete moments', (
    WidgetTester tester,
  ) async {
    _enqueueMomentCollectionsResponse(bundle);
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media/456/points/10',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: <String, dynamic>{
        'items': const <dynamic>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/moment-collections',
      body: const <dynamic>[],
    );

    await _pumpMomentsApp(tester, bundle: bundle, sessionStore: sessionStore);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('mobile-moments-enter-selection-button')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('moment-card-10')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('mobile-moments-batch-delete-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-moments-batch-delete-confirm-button')),
      findsOneWidget,
    );
    expect(find.textContaining('只会删除时刻标记'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('mobile-moments-batch-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('DELETE', '/media/456/points/10'), 1);
    expect(find.text('ABC-001'), findsNothing);
    expect(find.text('0 个时刻'), findsOneWidget);
    expect(find.text('已选 1 个'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile moments tab reloads with earliest sort', (
    WidgetTester tester,
  ) async {
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:asc');

    await _pumpMomentsApp(tester, bundle: bundle, sessionStore: sessionStore);
    await tester.pumpAndSettle();

    // 移动端点开的是底部抽屉，面板内容与桌面浮层同构。
    await tester.tap(find.byKey(const Key('mobile-moments-filter-trigger')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-moments-filter-drawer')),
      findsOneWidget,
    );

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
            builder: (_, __) =>
                const Scaffold(body: MobileOverviewMomentsTab()),
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
      expect(
        find.byKey(
          const Key('image-search-result-preview-movie-info-divider-top'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('image-search-result-preview-movie-info-divider-bottom'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('image-search-result-preview-movie-cover')),
      );
      await tester.pumpAndSettle();

      expect(find.text('movie:ABC-001'), findsOneWidget);
      expect(detailRouteExtra, isNull);
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
    final draftStore = ImageSearchDraftStore();
    Uri? imageSearchUri;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: MobileOverviewMomentsTab()),
        ),
        GoRoute(
          path: mobileImageSearchPath,
          builder: (_, state) {
            imageSearchUri = state.uri;
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
      draftStore: draftStore,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('moment-card-10')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('相似图片'));
    await tester.pumpAndSettle();

    expect(find.text('mobile-image-search'), findsOneWidget);
    expect(imageSearchUri, isNotNull);
    expect(imageSearchUri!.path, mobileImageSearchPath);
    expect(imageSearchUri!.queryParameters['currentMovieNumber'], isNull);
    final draftId = imageSearchUri!.queryParameters['draftId'];
    expect(draftId, isNotNull);
    final draft = draftStore.get(draftId);
    expect(draft, isNotNull);
    expect(draft!.fileName, 'moment_ABC-001_10.webp');
    expect(draft.bytes, const <int>[1, 2, 3, 4]);
    expect(draft.mimeType, 'image/webp');
  });
}

Future<void> _pumpMomentsApp(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required SessionStore sessionStore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: AppPlatformScope(
        platform: AppPlatform.mobile,
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            home: const Scaffold(body: MobileOverviewMomentsTab()),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpMomentsRouterApp(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  required GoRouter router,
  ImageSearchDraftStore? draftStore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(imageSearchDraftStore: draftStore),
      child: AppPlatformScope(
        platform: AppPlatform.mobile,
        child: OKToast(
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
          ),
        ),
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

void _enqueueMomentCollectionsResponse(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/moment-collections',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 7,
        'name': '周末回看',
        'description': '',
        'point_count': 3,
        'cover_image': null,
        'created_at': '2026-09-10T10:00:00Z',
        'updated_at': '2026-09-10T11:00:00Z',
      },
    ],
  );
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
          'valid': true,
          'progress': null,
          'playback_deliveries': const <String>['proxy', 'redirect'],
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
