import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/pages/mobile/overview_hot_reviews_tab.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

import '../../../../../support/test_api_bundle.dart';

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

  testWidgets('mobile hot reviews tab enables pull to refresh', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewsJson(total: 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
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

  testWidgets('mobile hot reviews tab uses cupertino sliver refresh on iOS', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewsJson(total: 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          theme: sakuraThemeData.copyWith(platform: TargetPlatform.iOS),
          home: const OKToast(
            child: Scaffold(body: MobileOverviewHotReviewsTab()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'mobile hot reviews tab opens the same filter sections in a bottom drawer',
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: bundle.riverpodOverrides(),
          child: MaterialApp(
            theme: sakuraThemeData,
            home: const OKToast(
              child: Scaffold(body: MobileOverviewHotReviewsTab()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 两端共用同一个筛选入口按钮，摘要就是当前周期名，默认「本周」。
      final triggerFinder = find.byKey(const Key('hot-reviews-filter-trigger'));
      expect(triggerFinder, findsOneWidget);
      expect(
        tester
            .widget<AppFilterEntryButton>(find.byType(AppFilterEntryButton))
            .label,
        '本周',
      );

      await tester.tap(triggerFinder);
      await tester.pumpAndSettle();

      // 移动端点开的是底部抽屉，不是桌面就地浮层；面板内容是同一组分节。
      expect(
        find.byKey(const Key('mobile-hot-reviews-filter-drawer')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('hot-reviews-filter-panel')), findsNothing);
      expect(
        find.byKey(const Key('hot-reviews-filter-period-monthly')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('hot-reviews-filter-period-monthly')),
      );
      await tester.pumpAndSettle();

      final reviewRequests = bundle.adapter.requests
          .where((request) => request.path == '/hot-reviews')
          .toList(growable: false);
      expect(reviewRequests, hasLength(2));
      expect(reviewRequests[1].uri.queryParameters['period'], 'monthly');
    },
  );

  testWidgets('mobile hot reviews tab keeps standard header gap below header', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      body: _hotReviewsJson(total: 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const OKToast(
            child: Scaffold(body: MobileOverviewHotReviewsTab()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 量 header **容器**底部而不是里面控件的底部：容器是固定高度
    // （AppListHeader，进出多选不跳版），控件在其中居中，
    // 控件底部与容器底部之间本来就有留白。
    final headerRect = tester.getRect(find.byType(AppListHeader));
    final firstCardRect = tester.getRect(
      find.byKey(const Key('hot-review-card-101')),
    );

    expect(
      firstCardRect.top - headerRect.bottom,
      moreOrLessEquals(sakuraThemeData.appSpacing.lg, epsilon: 1.0),
    );
  });
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
