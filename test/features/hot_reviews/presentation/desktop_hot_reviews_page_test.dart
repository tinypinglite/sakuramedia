import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/desktop_hot_reviews_page.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/mobile_overview_hot_reviews_tab.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

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

  testWidgets(
    'desktop hot reviews page shows loading skeletons before data resolves',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/hot-reviews',
        responder: (options, body) async {
          await completer.future;
          return ResponseBody.fromString(
            jsonEncode(_hotReviewsJson(total: 1)),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpHotReviewsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pump();

      expect(find.byKey(const Key('hot-review-grid')), findsOneWidget);
      expect(
        find.byKey(const Key('hot-review-card-skeleton-0')),
        findsOneWidget,
      );

      completer.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'desktop hot reviews page switches period query by toolbar buttons',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/hot-reviews',
        body: _hotReviewsJson(total: 1),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/hot-reviews',
        body: _hotReviewsJson(total: 1),
      );

      await _pumpHotReviewsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      var reviewRequests = bundle.adapter.requests
          .where((request) => request.path == '/hot-reviews')
          .toList(growable: false);
      expect(reviewRequests, hasLength(1));
      expect(reviewRequests.first.uri.queryParameters['period'], 'weekly');

      await tester.tap(
        find.byKey(const Key('desktop-hot-reviews-period-monthly')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      reviewRequests = bundle.adapter.requests
          .where((request) => request.path == '/hot-reviews')
          .toList(growable: false);
      expect(reviewRequests, hasLength(2));
      expect(reviewRequests[1].uri.queryParameters['period'], 'monthly');
    },
  );

  testWidgets(
    'desktop hot reviews page keeps pull to refresh disabled by default',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/hot-reviews',
        body: _hotReviewsJson(total: 1),
      );

      await _pumpHotReviewsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsNothing);
    },
  );

  testWidgets('mobile hot reviews tab enables pull to refresh', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewsJson(total: 1),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<HotReviewsApi>.value(value: bundle.hotReviewsApi),
        ],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const OKToast(
            child: Scaffold(body: MobileOverviewHotReviewsTab()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-overview-hot-reviews-tab')),
      findsOneWidget,
    );
  });

  testWidgets('desktop hot reviews grid resolves 2 to 4 columns adaptively', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(920, 1000);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewsJson(total: 2),
    );

    await _pumpHotReviewsPage(
      tester,
      sessionStore: sessionStore,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    final gridAtNarrow = tester.widget<GridView>(
      find.byKey(const Key('hot-review-grid')),
    );
    expect(
      (gridAtNarrow.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );

    tester.view.physicalSize = const Size(2000, 1000);
    await tester.pumpAndSettle();

    final gridAtWide = tester.widget<GridView>(
      find.byKey(const Key('hot-review-grid')),
    );
    expect(
      (gridAtWide.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      4,
    );
  });

  testWidgets(
    'desktop hot reviews card uses full cover pane and full-height content box',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/hot-reviews',
        body: _hotReviewsJson(
          total: 1,
          items: <Map<String, dynamic>>[
            _hotReviewItem(
              reviewId: 101,
              movieNumber: 'ABP-001',
              content: '这位女主是Riho（宾户里帆）',
            ),
          ],
        ),
      );

      await _pumpHotReviewsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      final cover = tester.widget<MaskedImage>(
        find.byKey(const Key('hot-review-card-cover-101')),
      );
      final coverPaneRect = tester.getRect(
        find.byKey(const Key('hot-review-card-cover-pane-101')),
      );
      final coverRect = tester.getRect(
        find.byKey(const Key('hot-review-card-cover-101')),
      );
      final cardRect = tester.getRect(
        find.byKey(const Key('hot-review-card-101')),
      );
      final contentRect = tester.getRect(
        find.byKey(const Key('hot-review-card-content-box-101')),
      );
      final spacing = sakuraThemeData.extension<AppSpacing>()!.sm;
      final appColors = sakuraThemeData.extension<AppColors>()!;
      final componentTokens = sakuraThemeData.extension<AppComponentTokens>()!;
      final icon = tester.widget<Icon>(find.byIcon(Icons.thumb_up_alt_rounded));
      final contentText = tester.widget<Text>(find.text('这位女主是Riho（宾户里帆）'));

      expect(cover.fit, BoxFit.cover);
      expect(
        cover.visibleWidthFactor,
        componentTokens.movieCardCoverVisibleWidthFactor,
      );
      expect(cover.visibleAlignment, Alignment.centerRight);
      expect(
        coverPaneRect.width / coverPaneRect.height,
        closeTo(componentTokens.movieCardAspectRatio, 0.02),
      );
      expect(
        icon.size,
        lessThan(sakuraThemeData.extension<AppComponentTokens>()!.iconSizeXs),
      );
      expect(coverRect.left, closeTo(coverPaneRect.left, 0.1));
      expect(coverRect.top, closeTo(coverPaneRect.top, 0.1));
      expect(coverRect.right, closeTo(coverPaneRect.right, 0.1));
      expect(coverRect.bottom, closeTo(coverPaneRect.bottom, 0.1));
      expect(contentRect.bottom, closeTo(cardRect.bottom - spacing, 1.5));
      expect(
        find.byKey(const Key('hot-review-card-content-box-101')),
        findsOneWidget,
      );
      expect(
        tester.widget<SizedBox>(
          find.byKey(const Key('hot-review-card-content-box-101')),
        ),
        isA<SizedBox>(),
      );
      expect(contentText.style?.color, appColors.textPrimary);
      expect(
        contentText.style?.fontSize,
        sakuraThemeData.textTheme.bodyMedium?.fontSize,
      );
      expect(
        find.byKey(const Key('hot-review-card-meta-row-101')),
        findsOneWidget,
      );
      expect(find.text('demo-user · 26/03/21'), findsOneWidget);
      expect(
        find.byKey(const Key('hot-review-card-content-scroll-101')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'desktop hot reviews card navigates to movie detail with fallback path',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/hot-reviews',
        body: _hotReviewsJson(total: 1),
      );

      String? receivedExtra;
      final router = GoRouter(
        initialLocation: desktopHotReviewsPath,
        routes: [
          GoRoute(
            path: desktopHotReviewsPath,
            builder: (context, state) => const DesktopHotReviewsPage(),
          ),
          GoRoute(
            path: '/desktop/library/movies/:movieNumber',
            builder: (context, state) {
              receivedExtra = state.extra as String?;
              return const SizedBox(key: Key('movie-detail-destination'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
            Provider<HotReviewsApi>.value(value: bundle.hotReviewsApi),
          ],
          child: OKToast(
            child: MaterialApp.router(
              theme: sakuraThemeData,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hot-review-card-101')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-detail-destination')), findsOneWidget);
      expect(receivedExtra, isNull);
    },
  );

  testWidgets(
    'desktop hot reviews retries failed load-more without clearing items',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/hot-reviews',
        body: _hotReviewsJson(
          total: 30,
          items: List<Map<String, dynamic>>.generate(
            20,
            (index) => _hotReviewItem(
              reviewId: index + 1,
              movieNumber: 'ABP-${(index + 1).toString().padLeft(3, '0')}',
            ),
          ),
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/hot-reviews',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
        },
      );

      await _pumpHotReviewsPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('desktop-hot-reviews-scroll-view')),
        const Offset(0, -3000),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hot-review-card-1')), findsOneWidget);
      expect(find.text('加载更多失败，请点击重试'), findsOneWidget);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/hot-reviews',
        body: _hotReviewsJson(
          page: 2,
          total: 30,
          items: List<Map<String, dynamic>>.generate(
            10,
            (index) => _hotReviewItem(
              reviewId: index + 21,
              movieNumber: 'ABP-${(index + 21).toString().padLeft(3, '0')}',
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.widgetWithText(TextButton, '重试'));
      await tester.tap(find.widgetWithText(TextButton, '重试'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hot-review-card-30')), findsOneWidget);
    },
  );
}

Future<void> _pumpHotReviewsPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<HotReviewsApi>.value(value: bundle.hotReviewsApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: DesktopHotReviewsPage()),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _hotReviewsJson({
  int page = 1,
  int pageSize = 20,
  int total = 1,
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'items': items ?? <Map<String, dynamic>>[_hotReviewItem()],
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}

Map<String, dynamic> _hotReviewItem({
  int rank = 1,
  int reviewId = 101,
  int score = 5,
  String movieNumber = 'ABP-001',
  String content = '值得反复看',
  String username = 'demo-user',
}) {
  return <String, dynamic>{
    'rank': rank,
    'review_id': reviewId,
    'score': score,
    'content': content,
    'created_at': '2026-03-21T01:00:00Z',
    'username': username,
    'like_count': 11,
    'watch_count': 21,
    'movie': <String, dynamic>{
      'javdb_id': 'javdb-$movieNumber',
      'movie_number': movieNumber,
      'title': 'Movie $movieNumber',
      'cover_image': null,
      'release_date': null,
      'duration_minutes': 0,
      'is_subscribed': false,
      'can_play': false,
    },
  };
}
