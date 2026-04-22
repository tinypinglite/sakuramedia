import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_page_content.dart';
import 'package:sakuramedia/features/movies/presentation/mobile_movie_detail_page.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_mobile_subpage_shell.dart';
import 'package:sakuramedia/widgets/media/app_image_fullscreen.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_hero_card.dart';
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

  testWidgets('mobile movie detail page shows loading skeleton on first load', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/movies/ABC-001',
      responder: (options, requestBody) async {
        await completer.future;
        return ResponseBody.fromString(
          jsonEncode(_movieDetailJson()),
          200,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pump();

    final loadingSurface = tester.widget<ColoredBox>(
      find.byKey(const Key('mobile-movie-detail-page-surface')),
    );
    expect(loadingSurface.color, sakuraThemeData.appColors.surfaceCard);
    expect(
      find.byKey(const Key('movie-detail-loading-skeleton')),
      findsOneWidget,
    );

    if (!completer.isCompleted) {
      completer.complete();
    }
    await tester.pumpAndSettle();
  });

  testWidgets(
    'mobile movie detail loading skeleton does not overflow on narrow widths',
    (WidgetTester tester) async {
      final controller = MovieDetailController(
        movieNumber: 'ABC-001',
        fetchMovieDetail:
            ({required movieNumber}) =>
                Future<MovieDetailDto>.value(throw UnimplementedError()),
        fetchSimilarMovies:
            ({required movieNumber, int limit = 15}) =>
                Future<List<MovieListItemDto>>.value(
                  const <MovieListItemDto>[],
                ),
      );
      addTearDown(controller.dispose);

      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox.expand(
              child: MovieDetailLoadingSkeleton(controller: controller),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-detail-loading-skeleton')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile movie detail page shows error state and can retry', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('影片详情暂时无法加载，请稍后重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-detail-page')), findsOneWidget);
    expect(find.text('ABC-001'), findsWidgets);
  });

  testWidgets('mobile movie detail page renders sections and opens inspector', (
    WidgetTester tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 40, bottom: 24);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(
        heat: 12,
        mediaItems: <Map<String, dynamic>>[
          _mediaItemJson(
            mediaId: 100,
            specialTags: '普通',
            points: <Map<String, dynamic>>[
              _mediaPointJson(pointId: 1, thumbnailId: 66, offsetSeconds: 120),
            ],
          ),
          _mediaItemJson(
            mediaId: 101,
            specialTags: '预告',
            points: <Map<String, dynamic>>[
              _mediaPointJson(pointId: 2, thumbnailId: 77, offsetSeconds: 240),
            ],
          ),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/101/thumbnails',
      body: _mediaThumbnailsJson(mediaId: 101),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/reviews',
      body: _movieReviewsJson(prefix: 'hot', count: 2),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final loadedSurface = tester.widget<ColoredBox>(
      find.byKey(const Key('mobile-movie-detail-page-surface')),
    );
    expect(loadedSurface.color, sakuraThemeData.appColors.surfaceCard);
    expect(find.text('系列 · Attackers'), findsOneWidget);
    expect(find.text('厂商 · S1 NO.1 STYLE'), findsOneWidget);
    expect(find.text('导演 · 紋℃'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-interaction-row')),
      findsOneWidget,
    );
    expect(find.text('想看人数 23'), findsOneWidget);
    expect(find.text('看过人数 12'), findsOneWidget);
    expect(find.text('评分人数 45'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-hero-heat-text')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-detail-interaction-heat-text')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('movie-detail-hero-heat-text')))
          .data,
      '12',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('movie-detail-interaction-heat-text')),
          )
          .data,
      '12',
    );
    expect(find.byIcon(Icons.star_outline_rounded), findsWidgets);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
    expect(find.text('演员'), findsOneWidget);
    expect(find.text('媒体源'), findsOneWidget);
    expect(find.text('H.264 · 22.8 Mbps · 29.97 fps'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-media-point-timecode-0')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('movie-media-point-timecode-0')))
          .data,
      '02:00',
    );

    await tester.ensureVisible(find.text('预告 1.0 GB'));
    await tester.tap(find.text('预告 1.0 GB'));
    await tester.pumpAndSettle();
    expect(find.text('H.265 · 6.5 Mbps · 24 fps'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('movie-media-point-timecode-0')))
          .data,
      '04:00',
    );
    await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-detail-inspector-bottom-sheet')),
      findsOneWidget,
    );
    final drawerRect = tester.getRect(
      find.byKey(const Key('movie-detail-inspector-bottom-sheet')),
    );
    final panelTopLeft = tester.getTopLeft(
      find.byKey(const Key('movie-detail-inspector-panel')),
    );

    expect(panelTopLeft.dy - drawerRect.top, 16);
    expect(panelTopLeft.dx - drawerRect.left, 16);
    final firstTabRect = tester.getRect(find.byType(Tab).first);
    final hotSortRect = tester.getRect(
      find.byKey(const Key('movie-detail-review-sort-hotly')),
    );
    expect(firstTabRect.left, hotSortRect.left);
    expect(find.text('评论'), findsOneWidget);
    expect(find.text('磁力搜索'), findsOneWidget);
    expect(find.text('缩略图'), findsOneWidget);
    expect(find.text('Missav缩略图'), findsOneWidget);
    expect(find.text('hot-review-1'), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/media/101/thumbnails'), 1);
    expect(bundle.adapter.hitCount('GET', '/movies/ABC-001/reviews'), 1);
    expect(
      bundle.adapter.hitCount(
        'GET',
        '/movies/ABC-001/thumbnails/missav/stream',
      ),
      0,
    );
  });

  testWidgets(
    'mobile movie detail page opens media delete confirmation drawer',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-media-delete-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-media-delete-confirm-drawer')),
        findsOneWidget,
      );
      expect(find.text('删除媒体文件'), findsOneWidget);
      expect(find.byKey(const Key('movie-media-delete-path')), findsOneWidget);
    },
  );

  testWidgets(
    'mobile movie detail page deletes selected media and refreshes media section',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
            _mediaItemJson(mediaId: 100, specialTags: '普通'),
            _mediaItemJson(mediaId: 101, specialTags: '预告'),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media/100',
        statusCode: 204,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
            _mediaItemJson(mediaId: 101, specialTags: '预告'),
          ],
        ),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-media-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-media-delete-confirm')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('DELETE', '/media/100'), 1);
      expect(bundle.adapter.hitCount('GET', '/movies/ABC-001'), 2);
      expect(find.text('普通 1.0 GB'), findsNothing);
      expect(find.text('预告 1.0 GB'), findsOneWidget);
      expect(find.text('媒体文件已删除'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'mobile movie detail page aligns content with mobile subpage shell padding',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );

      await _pumpSubpage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      final heroRect = tester.getRect(find.byType(MovieDetailHeroCard));
      final appSize = tester.getSize(find.byType(MaterialApp).first);

      expect(heroRect.left, AppPageInsets.compact);
      expect(heroRect.right, appSize.width - AppPageInsets.compact);
    },
  );

  testWidgets(
    'mobile movie detail page shows similar movies as an independent section after media section',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
            _mediaItemJson(
              points: <Map<String, dynamic>>[
                _mediaPointJson(
                  pointId: 1,
                  thumbnailId: 66,
                  offsetSeconds: 120,
                ),
              ],
            ),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: _similarMoviesJson(count: 4),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-media-points-title')), findsOneWidget);
      expect(
        find.byKey(const Key('movie-similar-movies-title')),
        findsOneWidget,
      );
      expect(find.text('媒体源'), findsOneWidget);
      expect(find.byType(MovieSummaryCard), findsNWidgets(4));
      expect(
        find.byKey(const Key('movie-summary-card-SIM-001')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('媒体源')).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('movie-similar-movies-title')))
              .dy,
        ),
      );

      final similarScroller = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('movie-similar-strip-scroll')),
      );
      expect(similarScroller.scrollDirection, Axis.horizontal);
      expect(
        _queryValueForPath(bundle, '/movies/ABC-001/similar', 'limit'),
        '15',
      );
    },
  );

  testWidgets(
    'mobile movie detail page shows similar movies when there are no media items',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(mediaItems: const <Map<String, dynamic>>[]),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: _similarMoviesJson(count: 2),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('媒体源'), findsNothing);
      expect(find.text('暂无媒体源'), findsNothing);
      expect(
        find.byKey(const Key('movie-similar-movies-title')),
        findsOneWidget,
      );
      expect(find.byType(MovieSummaryCard), findsNWidgets(2));
    },
  );

  testWidgets(
    'mobile movie detail page similar movie tap pushes detail route',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001/similar',
        body: _similarMoviesJson(count: 2),
      );

      final router = GoRouter(
        initialLocation: '/mobile/library/movies/ABC-001',
        routes: [
          GoRoute(
            path: '/mobile/library/movies/ABC-001',
            builder:
                (_, __) => const MobileMovieDetailPage(movieNumber: 'ABC-001'),
          ),
          GoRoute(
            path: '$mobileMoviesPath/:movieNumber',
            builder:
                (_, state) => Text(
                  'movie:${state.pathParameters['movieNumber']}',
                  textDirection: TextDirection.ltr,
                ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await _pumpRouterPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        router: router,
      );
      await tester.pumpAndSettle();

      final verticalScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('movie-summary-card-SIM-001')),
        300,
        scrollable: verticalScrollable,
      );
      await tester.ensureVisible(
        find.byKey(const Key('movie-summary-card-SIM-001')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-summary-card-SIM-001')));
      await tester.pumpAndSettle();

      expect(find.text('movie:SIM-001'), findsOneWidget);
      expect(router.canPop(), isTrue);
    },
  );

  testWidgets(
    'mobile movie detail page opens media point preview bottom sheet',
    (WidgetTester tester) async {
      final pointJson = _mediaPointJson(
        pointId: 1,
        thumbnailId: 66,
        offsetSeconds: 120,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
            _mediaItemJson(points: <Map<String, dynamic>>[pointJson]),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/points',
        body: <Map<String, dynamic>>[
          <String, dynamic>{
            'point_id': 1,
            'media_id': 100,
            'thumbnail_id': 66,
            'offset_seconds': 120,
            'image': pointJson['image'],
            'created_at': '2026-03-12T10:00:00Z',
          },
        ],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      final verticalScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('movie-media-point-thumb-0')),
        300,
        scrollable: verticalScrollable,
      );
      await tester.ensureVisible(
        find.byKey(const Key('movie-media-point-thumb-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-media-point-thumb-0')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('image-search-result-preview-hero')),
        findsOneWidget,
      );
      expect(find.text('影片详情'), findsNothing);
      expect(find.text('删除标记'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile movie detail page hides maker and director sections when empty',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(makerName: '', directorName: ''),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('厂商 · S1 NO.1 STYLE'), findsNothing);
      expect(find.text('导演 · 紋℃'), findsNothing);
    },
  );

  testWidgets(
    'mobile movie detail page inspector review skeleton expands in taller bottom sheet',
    (WidgetTester tester) async {
      final reviewsCompleter = Completer<void>();
      addTearDown(() {
        if (!reviewsCompleter.isCompleted) {
          reviewsCompleter.complete();
        }
      });

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          mediaItems: <Map<String, dynamic>>[
            _mediaItemJson(mediaId: 100, specialTags: '普通'),
            _mediaItemJson(mediaId: 101, specialTags: '预告'),
          ],
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/101/thumbnails',
        body: _mediaThumbnailsJson(mediaId: 101),
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/movies/ABC-001/reviews',
        responder: (options, requestBody) async {
          await reviewsCompleter.future;
          return ResponseBody.fromString(
            jsonEncode(_movieReviewsJson(prefix: 'hot', count: 2)),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
        physicalSize: const Size(430, 1400),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('预告 1.0 GB'));
      await tester.tap(find.text('预告 1.0 GB'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pump();

      expect(
        find.byKey(const Key('movie-detail-inspector-bottom-sheet')),
        findsOneWidget,
      );
      expect(_reviewSkeletonFinder(), findsWidgets);
      expect(_reviewSkeletonFinder().evaluate().length, greaterThan(3));

      if (!reviewsCompleter.isCompleted) {
        reviewsCompleter.complete();
      }
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'mobile movie detail page shows preferred description below movie number without title',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          title: 'ABC-001 4K 中文字幕',
          summary: '这是影片简介',
          descZh: '这是中文简介',
          desc: 'これは日本語紹介です',
        ),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-detail-title')), findsNothing);
      expect(find.byKey(const Key('movie-detail-summary')), findsOneWidget);
      expect(find.text('ABC-001 4K 中文字幕'), findsNothing);
      expect(find.text('这是中文简介'), findsOneWidget);

      final heroTop = tester.getTopLeft(find.byType(MovieDetailHeroCard)).dy;
      final movieNumberBottom =
          tester.getBottomLeft(find.byKey(const Key('movie-detail-number'))).dy;
      final interactionTop =
          tester
              .getTopLeft(find.byKey(const Key('movie-detail-interaction-row')))
              .dy;
      final summaryTop =
          tester.getTopLeft(find.byKey(const Key('movie-detail-summary'))).dy;
      final numberText = tester.widget<Text>(
        find.byKey(const Key('movie-detail-number')),
      );
      final summaryText = tester.widget<Text>(
        find.byKey(const Key('movie-detail-summary')),
      );

      expect(heroTop, lessThan(movieNumberBottom));
      expect(movieNumberBottom, lessThan(interactionTop));
      expect(interactionTop, lessThan(summaryTop));
      expect(
        numberText.style?.fontSize,
        sakuraMobileThemeData.appTextScale.s16,
      );
      expect(
        summaryText.style?.fontSize,
        sakuraMobileThemeData.appTextScale.s14,
      );
    },
  );

  testWidgets(
    'mobile movie detail page hides description when desc_zh summary and desc are empty',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          title: 'ABC-001',
          summary: '',
          descZh: ' ',
          desc: '',
        ),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-detail-title')), findsNothing);
      expect(find.byKey(const Key('movie-detail-summary')), findsNothing);
      expect(find.byKey(const Key('movie-detail-number')), findsOneWidget);
    },
  );

  testWidgets(
    'mobile movie detail page falls back to summary for description when desc_zh is blank',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(
          summary: '这是摘要',
          descZh: ' ',
          desc: 'これは日本語紹介です',
        ),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('这是摘要'), findsOneWidget);
      expect(find.text('これは日本語紹介です'), findsNothing);
    },
  );

  testWidgets(
    'mobile movie detail page falls back to desc for description when desc_zh and summary are blank',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(summary: ' ', descZh: '', desc: 'これは日本語紹介です'),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('これは日本語紹介です'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile movie detail opens playlist picker and creator as bottom sheets',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          _playlistJson(
            id: 1,
            name: '最近播放',
            kind: 'recently_played',
            isSystem: true,
            movieCount: 1,
          ),
          _playlistJson(
            id: 2,
            name: '我的收藏',
            description: 'Favorite',
            movieCount: 2,
          ),
        ],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('movie-detail-playlist-trigger')),
      );
      await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-playlist-picker-bottom-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-playlist-picker-dialog')),
        findsNothing,
      );
      expect(find.text('我的收藏'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('最近播放'), findsNothing);

      final playlistNameText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('movie-playlist-option-2')),
          matching: find.text('我的收藏'),
        ),
      );
      expect(
        playlistNameText.style?.fontSize,
        sakuraMobileThemeData.appTextScale.s14,
      );

      final playlistCountText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('movie-playlist-option-2')),
          matching: find.text('2'),
        ),
      );
      expect(
        playlistCountText.style?.fontSize,
        sakuraMobileThemeData.appTextScale.s12,
      );

      final checkboxScale = tester.widget<Transform>(
        find.byKey(const Key('movie-playlist-checkbox-scale-2')),
      );
      expect(checkboxScale.transform.storage[0], closeTo(0.85, 0.001));
      expect(checkboxScale.transform.storage[5], closeTo(0.85, 0.001));

      await tester.tap(find.byKey(const Key('movie-playlist-create-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('create-playlist-bottom-sheet')),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets('mobile movie detail toggles collection type near movie number', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/collection-status',
      body: <String, dynamic>{
        'movie_number': 'ABC-001',
        'is_collection': false,
      },
    );
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/movies/collection-type',
      body: <String, dynamic>{'requested_count': 1, 'updated_count': 1},
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('movie-detail-collection-trigger')),
    );
    expect(find.text('标记合集'), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-detail-collection-trigger')));
    await tester.pumpAndSettle();

    final patchRequest = bundle.adapter.requests.singleWhere(
      (request) =>
          request.method == 'PATCH' &&
          request.path == '/movies/collection-type',
    );
    expect(patchRequest.body, <String, dynamic>{
      'movie_numbers': <String>['ABC-001'],
      'collection_type': 'collection',
    });
    expect(
      bundle.adapter.hitCount('GET', '/movies/ABC-001/collection-status'),
      1,
    );
    expect(find.text('已标记为合集'), findsOneWidget);
    expect(find.text('标记单体'), findsOneWidget);
    expect(find.text('合集'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'mobile movie detail playlist picker height adapts with small content',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(540, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[_playlistJson(id: 2, name: '我的收藏')],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('movie-detail-playlist-trigger')),
      );
      await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
      await tester.pumpAndSettle();

      final viewportHeight =
          tester.getSize(find.byType(MobileMovieDetailPage)).height;
      final drawerHeight =
          tester
              .getSize(
                find.byKey(const Key('movie-playlist-picker-bottom-sheet')),
              )
              .height;

      expect(drawerHeight, lessThanOrEqualTo(viewportHeight * 0.7));
    },
  );

  testWidgets(
    'mobile movie detail playlist picker caps height at 70% and keeps list scrollable',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(540, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final customPlaylists = List<Map<String, dynamic>>.generate(
        24,
        (index) => _playlistJson(
          id: 100 + index,
          name: '自定义列表 ${index + 1}',
          movieCount: index,
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/playlists',
        body: <Map<String, dynamic>>[
          _playlistJson(
            id: 1,
            name: '最近播放',
            kind: 'recently_played',
            isSystem: true,
            movieCount: 10,
          ),
          ...customPlaylists,
        ],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('movie-detail-playlist-trigger')),
      );
      await tester.tap(find.byKey(const Key('movie-detail-playlist-trigger')));
      await tester.pumpAndSettle();

      final viewportHeight =
          tester.getSize(find.byType(MobileMovieDetailPage)).height;
      final drawerHeight =
          tester
              .getSize(
                find.byKey(const Key('movie-playlist-picker-bottom-sheet')),
              )
              .height;
      final maxAllowedHeight = viewportHeight * 0.7;

      expect(drawerHeight, lessThanOrEqualTo(maxAllowedHeight + 0.1));

      final listFinder = find.byKey(const Key('movie-playlist-list'));
      final lastOptionFinder = find.byKey(
        const Key('movie-playlist-option-123'),
      );

      expect(listFinder, findsOneWidget);
      expect(lastOptionFinder, findsNothing);
      await tester.dragUntilVisible(
        lastOptionFinder,
        listFinder,
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      expect(lastOptionFinder, findsOneWidget);
    },
  );

  testWidgets(
    'mobile movie detail plot thumbnail opens bottom drawer preview',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-plot-thumb-0')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-plot-preview-bottom-drawer')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('movie-plot-preview-dialog')), findsNothing);
    },
  );

  testWidgets(
    'mobile movie detail plot preview main image opens action menu on long press',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-plot-thumb-0')));
      await tester.pumpAndSettle();

      final center = tester.getCenter(
        find.byKey(const Key('movie-plot-preview-main-image-0')),
      );
      final gesture = await tester.startGesture(center);
      await tester.pump(kLongPressTimeout);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('相似图片'), findsOneWidget);
      expect(find.text('保存到本地'), findsOneWidget);
    },
  );

  testWidgets('mobile movie detail hero height follows 30% viewport rule', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(540, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final viewportHeight =
        tester.getSize(find.byType(MobileMovieDetailPage)).height;
    final heroHeight = tester.getSize(find.byType(MovieDetailHeroCard)).height;

    expect(heroHeight, closeTo(viewportHeight * 0.3, 0.1));
  });

  testWidgets(
    'mobile movie detail inspector supports manual magnet search local sort compact interval selector and thumbnail columns',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(offsets: <int>[10, 20, 30, 40]),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/download-candidates',
        body: _downloadCandidatesJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('磁力搜索'));
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('GET', '/download-candidates'), 0);

      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-search-button')),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/download-candidates'), 1);
      expect(
        find.byKey(const Key('movie-detail-magnet-sort-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-detail-magnet-sort-direction')),
        findsOneWidget,
      );
      expect(
        _orderedMagnetTitles(tester, _defaultMagnetTitles),
        _defaultMagnetTitles,
      );

      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-sort-direction')),
      );
      await tester.pumpAndSettle();
      expect(
        _orderedMagnetTitles(tester, _defaultMagnetTitles),
        _sizeAscendingMagnetTitles,
      );

      await tester.tap(find.text('文件大小'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('做种人数').last);
      await tester.pumpAndSettle();
      expect(
        _orderedMagnetTitles(tester, _defaultMagnetTitles),
        _seedersAscendingMagnetTitles,
      );

      await tester.tap(find.text('缩略图'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('movie-media-thumb-0')), findsOneWidget);
      expect(
        find.byKey(const Key('movie-detail-thumbnail-interval-icon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-detail-thumbnail-columns-icon')),
        findsOneWidget,
      );

      final toolbarLeft = tester.getTopLeft(
        find.byKey(const Key('movie-detail-thumbnail-toolbar')),
      );
      final intervalGroupLeft = tester.getTopLeft(
        find.byKey(const Key('movie-detail-thumbnail-interval-group')),
      );
      expect(intervalGroupLeft.dx, toolbarLeft.dx);

      await tester.tap(
        find.byKey(const Key('movie-detail-thumbnail-interval-20')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-media-thumb-1')), findsOneWidget);
      expect(find.byKey(const Key('movie-media-thumb-2')), findsNothing);
      expect(find.byKey(const Key('movie-media-thumb-3')), findsNothing);

      await tester.tap(
        find.byKey(const Key('movie-detail-thumbnail-columns-5')),
      );
      await tester.pumpAndSettle();

      final columnButton = tester.widget<AppTextButton>(
        find.byKey(const Key('movie-detail-thumbnail-columns-5')),
      );
      expect(columnButton.isSelected, isTrue);
    },
  );

  testWidgets(
    'mobile movie detail inspector thumbnail opens bottom drawer preview',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('缩略图'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-media-thumb-0')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-plot-preview-bottom-drawer')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('movie-plot-preview-dialog')), findsNothing);
    },
  );

  testWidgets(
    'mobile movie detail inspector preview main image opens action menu on long press',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/ABC-001',
        body: _movieDetailJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: _mediaThumbnailsJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/points',
        body: const <Map<String, dynamic>>[],
      );

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('缩略图'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-media-thumb-0')));
      await tester.pumpAndSettle();

      final center = tester.getCenter(
        find.byKey(const Key('movie-plot-preview-main-image-0')),
      );
      final gesture = await tester.startGesture(center);
      await tester.pump(kLongPressTimeout);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('相似图片'), findsOneWidget);
      expect(find.text('保存到本地'), findsOneWidget);
    },
  );

  testWidgets('mobile movie detail play entries navigate to mobile player', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/thumbnails',
      body: _mediaThumbnailsJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/points',
      body: const <Map<String, dynamic>>[],
    );

    final visitedPlayerUris = <String>[];
    final router = GoRouter(
      initialLocation: buildMobileMovieDetailRoutePath('ABC-001'),
      routes: [
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber',
          builder:
              (_, state) => MobileMovieDetailPage(
                movieNumber: state.pathParameters['movieNumber']!,
              ),
        ),
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber/player',
          builder: (_, state) {
            visitedPlayerUris.add(state.uri.toString());
            return Text(
              'player:${state.uri}',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouterPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      router: router,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-hero-play-button')));
    await tester.pumpAndSettle();
    expect(
      visitedPlayerUris,
      contains('/mobile/library/movies/ABC-001/player?mediaId=100'),
    );

    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('movie-detail-fixed-info-bar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('缩略图'));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('movie-media-thumb-0'))),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();
    expect(
      visitedPlayerUris,
      contains(
        '/mobile/library/movies/ABC-001/player?mediaId=100&positionSeconds=10',
      ),
    );
  });

  testWidgets('mobile movie detail actor tap navigates to actor detail route', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );
    final router = GoRouter(
      initialLocation: buildMobileMovieDetailRoutePath('ABC-001'),
      routes: [
        GoRoute(
          path: '$mobileMoviesPath/:movieNumber',
          builder:
              (_, state) => MobileMovieDetailPage(
                movieNumber: state.pathParameters['movieNumber']!,
              ),
        ),
        GoRoute(
          path: '$mobileActorsPath/:actorId',
          builder:
              (_, state) => Text(
                'actor:${state.pathParameters['actorId']}',
                textDirection: TextDirection.ltr,
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpRouterPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
      router: router,
    );
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('movie-actor-1')),
      300,
      scrollable: verticalScrollable,
    );
    await tester.tap(find.byKey(const Key('movie-actor-1')));
    await tester.pumpAndSettle();

    expect(find.text('actor:1'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  Size physicalSize = const Size(430, 900),
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<MediaApi>.value(value: MediaApi(apiClient: bundle.apiClient)),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        ChangeNotifierProvider(
          create: (_) => MovieCollectionTypeChangeNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
        Provider<DownloadsApi>.value(value: bundle.downloadsApi),
      ],
      child: MaterialApp(
        theme: sakuraMobileThemeData,
        builder:
            (context, child) =>
                AppImageFullscreenHost(child: child ?? const SizedBox()),
        home: const OKToast(
          child: Scaffold(body: MobileMovieDetailPage(movieNumber: 'ABC-001')),
        ),
      ),
    ),
  );
}

Future<void> _pumpSubpage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
  Size physicalSize = const Size(430, 900),
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<MediaApi>.value(value: MediaApi(apiClient: bundle.apiClient)),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        ChangeNotifierProvider(
          create: (_) => MovieCollectionTypeChangeNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
        Provider<DownloadsApi>.value(value: bundle.downloadsApi),
      ],
      child: MaterialApp(
        theme: sakuraMobileThemeData,
        builder:
            (context, child) =>
                AppImageFullscreenHost(child: child ?? const SizedBox()),
        home: const OKToast(
          child: AppMobileSubpageShell(
            title: '影片详情',
            defaultLocation: '/mobile/library/movies',
            child: MobileMovieDetailPage(movieNumber: 'ABC-001'),
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
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<MediaApi>.value(value: MediaApi(apiClient: bundle.apiClient)),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        ChangeNotifierProvider(
          create: (_) => MovieCollectionTypeChangeNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
        Provider<DownloadsApi>.value(value: bundle.downloadsApi),
      ],
      child: OKToast(
        child: MaterialApp.router(
          theme: sakuraMobileThemeData,
          builder:
              (context, child) =>
                  AppImageFullscreenHost(child: child ?? const SizedBox()),
          routerConfig: router,
        ),
      ),
    ),
  );
}

Map<String, dynamic> _movieDetailJson({
  String title = 'Movie 1',
  String summary = '',
  String descZh = '',
  String desc = '',
  String makerName = 'S1 NO.1 STYLE',
  String directorName = '紋℃',
  int heat = 0,
  List<Map<String, dynamic>>? mediaItems,
}) {
  return <String, dynamic>{
    'javdb_id': 'MovieA1',
    'movie_number': 'ABC-001',
    'title': title,
    'cover_image': <String, dynamic>{
      'id': 10,
      'origin': '/files/images/movies/ABC-001/cover.jpg',
      'small': '/files/images/movies/ABC-001/cover-small.jpg',
      'medium': '/files/images/movies/ABC-001/cover-medium.jpg',
      'large': '/files/images/movies/ABC-001/cover-large.jpg',
    },
    'release_date': '2026-03-08',
    'duration_minutes': 120,
    'score': 4.5,
    'heat': heat,
    'watched_count': 12,
    'want_watch_count': 23,
    'comment_count': 34,
    'score_number': 45,
    'is_collection': false,
    'is_subscribed': true,
    'can_play': true,
    'series_name': 'Attackers',
    'maker_name': makerName,
    'director_name': directorName,
    'summary': summary,
    'desc_zh': descZh,
    'desc': desc,
    'actors': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'javdb_id': 'ActorA1',
        'name': '三上悠亚',
        'alias_name': '三上悠亚 / 鬼头桃菜',
        'is_subscribed': false,
        'profile_image': null,
      },
    ],
    'tags': <Map<String, dynamic>>[
      <String, dynamic>{'tag_id': 1, 'name': '剧情'},
      <String, dynamic>{'tag_id': 2, 'name': '偶像'},
    ],
    'thin_cover_image': <String, dynamic>{
      'id': 11,
      'origin': '/files/images/movies/ABC-001/thin.jpg',
      'small': '/files/images/movies/ABC-001/thin-small.jpg',
      'medium': '/files/images/movies/ABC-001/thin-medium.jpg',
      'large': '/files/images/movies/ABC-001/thin-large.jpg',
    },
    'plot_images': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 12,
        'origin': '/files/images/movies/ABC-001/plots/0.jpg',
        'small': '/files/images/movies/ABC-001/plots/0-small.jpg',
        'medium': '/files/images/movies/ABC-001/plots/0-medium.jpg',
        'large': '/files/images/movies/ABC-001/plots/0-large.jpg',
      },
    ],
    'media_items': mediaItems ?? <Map<String, dynamic>>[_mediaItemJson()],
    'playlists': const <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _playlistJson({
  required int id,
  required String name,
  String kind = 'custom',
  bool isSystem = false,
  bool isMutable = true,
  bool isDeletable = true,
  int movieCount = 0,
  String description = '',
}) {
  final mutable = isSystem ? false : isMutable;
  final deletable = isSystem ? false : isDeletable;
  return <String, dynamic>{
    'id': id,
    'name': name,
    'kind': kind,
    'description': description,
    'is_system': isSystem,
    'is_mutable': mutable,
    'is_deletable': deletable,
    'movie_count': movieCount,
    'created_at': '2026-03-12T10:10:00Z',
    'updated_at': '2026-03-12T10:10:00Z',
  };
}

Map<String, dynamic> _mediaItemJson({
  int mediaId = 100,
  String specialTags = '普通',
  List<Map<String, dynamic>>? points,
}) {
  final isPreview = mediaId == 101;
  return <String, dynamic>{
    'media_id': mediaId,
    'library_id': 1,
    'play_url':
        '/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
    'path': '/library/main/ABC-001/video.mp4',
    'storage_mode': 'hardlink',
    'resolution': '1920x1080',
    'file_size_bytes': 1073741824,
    'duration_seconds': 7200,
    'special_tags': specialTags,
    'valid': true,
    'progress': <String, dynamic>{
      'last_position_seconds': 600,
      'last_watched_at': '2026-03-08T09:30:00',
    },
    'video_info': <String, dynamic>{
      'container': <String, dynamic>{
        'format_name': isPreview ? 'mp4' : 'mpegts',
        'duration_seconds': 7200,
        'bit_rate': isPreview ? 8000000 : 22793091,
        'size_bytes': 1073741824,
      },
      'video': <String, dynamic>{
        'codec_name': isPreview ? 'hevc' : 'h264',
        'codec_long_name': isPreview ? 'H.265 / HEVC' : 'H.264 / AVC',
        'profile': isPreview ? 'Main' : 'High',
        'bit_rate': isPreview ? 6500000 : null,
        'width': isPreview ? 1280 : 1920,
        'height': isPreview ? 720 : 1080,
        'frame_rate': isPreview ? 24.0 : 29.97,
        'pixel_format': 'yuv420p',
      },
      'audio': <String, dynamic>{
        'codec_name': 'aac',
        'codec_long_name': 'AAC',
        'profile': 'LC',
        'bit_rate': 192000,
        'sample_rate': 48000,
        'channels': 2,
        'channel_layout': 'stereo',
      },
      'subtitles': const <Map<String, dynamic>>[],
    },
    'points': points ?? const <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _mediaPointJson({
  required int pointId,
  required int thumbnailId,
  required int offsetSeconds,
}) {
  return <String, dynamic>{
    'point_id': pointId,
    'thumbnail_id': thumbnailId,
    'offset_seconds': offsetSeconds,
    'image': <String, dynamic>{
      'id': 300 + pointId,
      'origin': '/files/points/$thumbnailId.webp',
      'small': '/files/points/$thumbnailId-small.webp',
      'medium': '/files/points/$thumbnailId-medium.webp',
      'large': '/files/points/$thumbnailId-large.webp',
    },
  };
}

List<Map<String, dynamic>> _movieReviewsJson({
  required String prefix,
  required int count,
}) {
  return List<Map<String, dynamic>>.generate(count, (index) {
    final seed = index + 1;
    return <String, dynamic>{
      'id': seed,
      'score': 5,
      'content': '$prefix-review-$seed',
      'created_at': '2026-03-10T08:00:00Z',
      'username': '$prefix-user-$seed',
      'like_count': 10 + seed,
      'watch_count': 20 + seed,
    };
  });
}

Finder _reviewSkeletonFinder() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('movie-detail-review-skeleton-');
  });
}

const List<String> _defaultMagnetTitles = <String>[
  'ABC-001 高码率收藏版',
  'ABC-001 4K 中文字幕',
  'ABC-001 无码流出版',
];

const List<String> _sizeAscendingMagnetTitles = <String>[
  'ABC-001 无码流出版',
  'ABC-001 4K 中文字幕',
  'ABC-001 高码率收藏版',
];

const List<String> _seedersAscendingMagnetTitles = <String>[
  'ABC-001 无码流出版',
  'ABC-001 高码率收藏版',
  'ABC-001 4K 中文字幕',
];

List<String> _orderedMagnetTitles(WidgetTester tester, List<String> titles) {
  final sorted = List<String>.from(titles);
  sorted.sort((left, right) {
    final leftDy = tester.getTopLeft(find.text(left)).dy;
    final rightDy = tester.getTopLeft(find.text(right)).dy;
    return leftDy.compareTo(rightDy);
  });
  return sorted;
}

List<Map<String, dynamic>> _downloadCandidatesJson() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'source': 'jackett',
      'indexer_name': 'mteam',
      'indexer_kind': 'bt',
      'resolved_client_id': 2,
      'resolved_client_name': 'qb-main',
      'movie_number': 'ABC-001',
      'title': 'ABC-001 高码率收藏版',
      'size_bytes': 17179869184,
      'seeders': 20,
      'magnet_url': 'magnet:?xt=urn:btih:archive',
      'torrent_url': '',
      'tags': <String>['收藏', '高码率'],
    },
    <String, dynamic>{
      'source': 'jackett',
      'indexer_name': 'mteam',
      'indexer_kind': 'bt',
      'resolved_client_id': 2,
      'resolved_client_name': 'qb-main',
      'movie_number': 'ABC-001',
      'title': 'ABC-001 4K 中文字幕',
      'size_bytes': 12884901888,
      'seeders': 35,
      'magnet_url': 'magnet:?xt=urn:btih:abcdef',
      'torrent_url': '',
      'tags': <String>['4K', '中字'],
    },
    <String, dynamic>{
      'source': 'jackett',
      'indexer_name': 'nyaa',
      'indexer_kind': 'bt',
      'resolved_client_id': 2,
      'resolved_client_name': 'qb-main',
      'movie_number': 'ABC-001',
      'title': 'ABC-001 无码流出版',
      'size_bytes': 8589934592,
      'seeders': 12,
      'magnet_url': 'magnet:?xt=urn:btih:stream',
      'torrent_url': '',
      'tags': <String>['无码', '流出'],
    },
  ];
}

List<Map<String, dynamic>> _similarMoviesJson({required int count}) {
  return List<Map<String, dynamic>>.generate(count, (index) {
    final seed = index + 1;
    final movieNumber = 'SIM-${seed.toString().padLeft(3, '0')}';
    return <String, dynamic>{
      'javdb_id': 'Similar$seed',
      'movie_number': movieNumber,
      'title': 'Similar movie $seed',
      'cover_image': null,
      'release_date': '2024-01-02',
      'duration_minutes': 120,
      'heat': 10 + seed,
      'is_subscribed': seed.isEven,
      'can_play': seed.isOdd,
      'similarity_score': 0.9 - (index * 0.01),
    };
  }, growable: false);
}

List<Map<String, dynamic>> _mediaThumbnailsJson({
  int mediaId = 100,
  List<int> offsets = const <int>[10],
}) {
  return List<Map<String, dynamic>>.generate(offsets.length, (index) {
    final thumbnailId = index + 1;
    return <String, dynamic>{
      'thumbnail_id': thumbnailId,
      'media_id': mediaId,
      'offset_seconds': offsets[index],
      'image': <String, dynamic>{
        'id': 100 + thumbnailId,
        'origin': '/files/thumbs/$mediaId/$thumbnailId.webp',
        'small': '/files/thumbs/$mediaId/$thumbnailId-small.webp',
        'medium': '/files/thumbs/$mediaId/$thumbnailId-medium.webp',
        'large': '/files/thumbs/$mediaId/$thumbnailId-large.webp',
      },
    };
  }, growable: false);
}

String? _queryValueForPath(TestApiBundle bundle, String path, String key) {
  final request = bundle.adapter.requests.firstWhere(
    (request) => request.path == path,
  );
  return request.uri.queryParameters[key];
}
