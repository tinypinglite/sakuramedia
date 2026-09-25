import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../support/logged_in_session_store.dart';
import '../../../support/test_api_bundle.dart';

void main() {
  testWidgets('movie summary card prefers thin cover image', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: MovieListItemDto(
                  javdbId: 'MovieA1',
                  movieNumber: 'ABC-001',
                  title: 'Movie 1',
                  coverImage: const MovieImageDto(
                    id: 1,
                    origin: '/poster-origin.jpg',
                    small: '/poster-small.jpg',
                    medium: '/poster-medium.jpg',
                    large: '/poster-large.jpg',
                  ),
                  thinCoverImage: const MovieImageDto(
                    id: 2,
                    origin: '/thin-origin.jpg',
                    small: '/thin-small.jpg',
                    medium: '/thin-medium.jpg',
                    large: '/thin-large.jpg',
                  ),
                  releaseDate: DateTime(2024, 1, 1),
                  durationMinutes: 120,
                  heat: 42,
                  isSubscribed: true,
                  canPlay: true,
                ),
                onSubscriptionTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ABC-001'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-status-playable-ABC-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-heat-ABC-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-heat-text-ABC-001')),
      findsOneWidget,
    );
    expect(find.text('42'), findsOneWidget);
    expect(find.byType(MaskedImage), findsOneWidget);

    final maskedImage = tester.widget<MaskedImage>(find.byType(MaskedImage));
    expect(maskedImage.url, '/thin-large.jpg');
    expect(maskedImage.fit, BoxFit.cover);

    // 渐进披露：默认态不展开标题/时长，悬停后才补上。
    expect(find.text('Movie 1'), findsNothing);
    expect(find.text('120 分钟 · 2024.01.01'), findsNothing);

    // 可播放标记回到左上角：彩色圆底徽标。
    final playableBadgeContainer = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('movie-summary-card-status-playable-ABC-001')),
        matching: find.byType(Container),
      ),
    );
    final playableBadgeDecoration =
        playableBadgeContainer.decoration as BoxDecoration;
    expect(
      playableBadgeDecoration.color,
      AppColors.defaults().movieCardPlayableBadgeBackground,
    );

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(
      icons.where((icon) => icon.icon == Icons.play_arrow_rounded).single.color,
      AppTextPalette.defaults().onMedia,
    );
    final subscriptionIcon =
        icons.where((icon) => icon.icon == Icons.favorite_rounded).single;
    expect(subscriptionIcon.color, AppColors.defaults().subscriptionHeartIcon);
    expect(subscriptionIcon.size, AppComponentTokens.defaults().iconSizeXl);
    final heatIcon =
        icons
            .where((icon) => icon.icon == Icons.local_fire_department_rounded)
            .single;
    expect(heatIcon.color, AppColors.defaults().movieDetailHeatIcon);
    final heatBadgeContainer = tester.widget<Container>(
      find.byKey(const Key('movie-summary-card-heat-ABC-001')),
    );
    final heatBadgeDecoration = heatBadgeContainer.decoration as BoxDecoration;
    expect(heatBadgeDecoration.color, AppColors.defaults().mediaOverlayStrong);

    await _hoverCard(tester, 'ABC-001');

    expect(find.text('Movie 1'), findsOneWidget);
    expect(find.text('120 分钟 · 2024.01.01'), findsOneWidget);
    // 展开态不重复渲染热度胶囊。
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('movie summary card contains horizontal cover fallback', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: MovieListItemDto(
                  javdbId: 'MovieA1-cover',
                  movieNumber: 'ABC-101',
                  title: 'Movie 101',
                  coverImage: const MovieImageDto(
                    id: 1,
                    origin: '/cover-origin.jpg',
                    small: '/cover-small.jpg',
                    medium: '/cover-medium.jpg',
                    large: '/cover-large.jpg',
                  ),
                  thinCoverImage: const MovieImageDto(
                    id: 2,
                    origin: '',
                    small: '',
                    medium: '',
                    large: '',
                  ),
                  releaseDate: DateTime(2024, 1, 1),
                  durationMinutes: 120,
                  heat: 42,
                  isSubscribed: false,
                  canPlay: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MaskedImage), findsOneWidget);

    final maskedImage = tester.widget<MaskedImage>(find.byType(MaskedImage));
    expect(maskedImage.url, '/cover-large.jpg');
    expect(maskedImage.fit, BoxFit.contain);
  });

  testWidgets(
    'movie summary card shows poster placeholder when image missing',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: MovieListItemDto(
                    javdbId: 'MovieA2',
                    movieNumber: 'ABC-002',
                    title: 'Movie 2',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    heat: 0,
                    isSubscribed: false,
                    canPlay: false,
                  ),
                  onSubscriptionTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-summary-card-placeholder-ABC-002')),
        findsOneWidget,
      );
      expect(find.byType(MaskedImage), findsNothing);
      expect(find.text('ABC-002'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-subscription-ABC-002')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      // 热度为 0 时不渲染热度胶囊。
      expect(
        find.byKey(const Key('movie-summary-card-heat-ABC-002')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'movie summary card ignores poster placeholder icon under skeleton',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: AppSkeletonizer(
                  enabled: true,
                  child: MovieSummaryCard(
                    movie: MovieListItemDto(
                      javdbId: 'MovieA4',
                      movieNumber: 'ABC-004',
                      title: 'Movie 4',
                      coverImage: null,
                      releaseDate: null,
                      durationMinutes: 0,
                      heat: 0,
                      isSubscribed: false,
                      canPlay: false,
                    ),
                    onSubscriptionTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('movie-summary-card-placeholder-ABC-004')),
        findsOneWidget,
      );
      final icon = find.byIcon(Icons.movie_creation_outlined);
      expect(icon, findsOneWidget);
      // 图标自身包在 `Skeleton.ignore` 里，外层还有卡级 `Skeleton.unite`
      // 把整卡收敛成一块 shimmer（避免角标 / 文字骨块单独透出）。
      expect(
        find.ancestor(
          of: icon,
          matching: find.byWidgetPredicate((widget) => widget is Skeleton),
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'movie summary card shows loading indicator while subscription updates',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: MovieListItemDto(
                    javdbId: 'MovieA3',
                    movieNumber: 'ABC-003',
                    title: 'Movie 3',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    heat: 0,
                    isSubscribed: true,
                    canPlay: false,
                  ),
                  onSubscriptionTap: () {},
                  isSubscriptionUpdating: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const Key('movie-summary-card-subscription-loading-ABC-003'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('movie summary card forwards secondary tap menu position', (
    WidgetTester tester,
  ) async {
    Offset? menuPosition;
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: const MovieListItemDto(
                  javdbId: 'MovieA4',
                  movieNumber: 'OFJE-888',
                  title: 'Movie 4',
                  coverImage: null,
                  releaseDate: null,
                  durationMinutes: 0,
                  heat: 7,
                  isSubscribed: false,
                  canPlay: false,
                ),
                onRequestMenu: (position) => menuPosition = position,
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(
      find.byKey(const Key('movie-summary-card-OFJE-888')),
    );
    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pump();

    expect(menuPosition, equals(center));
  });

  testWidgets(
    'movie summary card keeps rank in bottom row and heat at top right',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: const MovieListItemDto(
                    javdbId: 'MovieA4-rank',
                    movieNumber: 'OFJE-777',
                    title: 'Movie Rank',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    heat: 99,
                    isSubscribed: false,
                    canPlay: false,
                  ),
                  rank: 3,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-summary-card-rank-OFJE-777')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-summary-card-heat-OFJE-777')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-summary-card-subscription-OFJE-777')),
        findsOneWidget,
      );

      final cardRect = tester.getRect(
        find.byKey(const Key('movie-summary-card-OFJE-777')),
      );
      final heatRect = tester.getRect(
        find.byKey(const Key('movie-summary-card-heat-OFJE-777')),
      );
      final subscriptionRect = tester.getRect(
        find.byKey(const Key('movie-summary-card-subscription-OFJE-777')),
      );
      final edgeInset = AppSpacing.defaults().xs;

      expect(heatRect.top - cardRect.top, closeTo(edgeInset, 0.1));
      expect(cardRect.right - heatRect.right, closeTo(edgeInset, 0.1));
      expect(subscriptionRect.top - cardRect.top, closeTo(edgeInset, 0.1));
      expect(subscriptionRect.left - cardRect.left, closeTo(edgeInset, 0.1));

      // 热度在顶部一行，rank 在底部信息条里。
      final heatBottom =
          tester
              .getBottomLeft(
                find.byKey(const Key('movie-summary-card-heat-OFJE-777')),
              )
              .dy;
      final rankTop =
          tester
              .getTopLeft(
                find.byKey(const Key('movie-summary-card-rank-OFJE-777')),
              )
              .dy;
      expect(heatBottom, lessThan(rankTop));

      // rank 与番号同排居中。
      final numberCenter =
          tester
              .getCenter(
                find.byKey(const Key('movie-summary-card-number-OFJE-777')),
              )
              .dy;
      final rankCenter =
          tester
              .getCenter(
                find.byKey(const Key('movie-summary-card-rank-OFJE-777')),
              )
              .dy;
      expect((rankCenter - numberCenter).abs(), lessThanOrEqualTo(8));
    },
  );

  testWidgets('movie summary card forwards long press menu position', (
    WidgetTester tester,
  ) async {
    Offset? menuPosition;
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: const MovieListItemDto(
                  javdbId: 'MovieA5',
                  movieNumber: 'OFJE-889',
                  title: 'Movie 5',
                  coverImage: null,
                  releaseDate: null,
                  durationMinutes: 0,
                  heat: 0,
                  isSubscribed: false,
                  canPlay: false,
                ),
                onRequestMenu: (position) => menuPosition = position,
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(
      find.byKey(const Key('movie-summary-card-OFJE-889')),
    );
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout);
    await gesture.up();

    expect(menuPosition, equals(center));
  });

  testWidgets('movie summary card hides play when not playable', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: const MovieListItemDto(
                  javdbId: 'MovieA8',
                  movieNumber: 'ABC-021',
                  title: 'Movie 8',
                  coverImage: null,
                  releaseDate: null,
                  durationMinutes: 0,
                  heat: 0,
                  isSubscribed: false,
                  canPlay: false,
                ),
                onTap: () {},
                onSubscriptionTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await _hoverCard(tester, 'ABC-021');

    expect(
      find.byKey(const Key('movie-summary-card-play-ABC-021')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('movie-summary-card-status-playable-ABC-021')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('movie summary card does not expand while selecting', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: const MovieListItemDto(
                  javdbId: 'MovieA8',
                  movieNumber: 'ABC-021',
                  title: 'Movie 8',
                  coverImage: null,
                  releaseDate: null,
                  durationMinutes: 0,
                  heat: 0,
                  isSubscribed: false,
                  canPlay: true,
                ),
                selectionMode: true,
                onTap: () {},
                onSubscriptionTap: () {},
                onSelectedChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await _hoverCard(tester, 'ABC-021');

    expect(
      find.byKey(const Key('movie-summary-card-play-ABC-021')),
      findsNothing,
    );
    expect(find.text('Movie 8'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'movie summary card pushes the player route when no play callback is given',
    (WidgetTester tester) async {
      var cardTaps = 0;
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      final router = GoRouter(
        initialLocation: '/list',
        routes: [
          GoRoute(
            path: '/list',
            builder: (context, state) => Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: const MovieListItemDto(
                    javdbId: 'MovieA9',
                    movieNumber: 'ABC-022',
                    title: 'Movie 9',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    heat: 0,
                    isSubscribed: false,
                    canPlay: true,
                  ),
                  onTap: () => cardTaps++,
                  onSubscriptionTap: () {},
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/desktop/library/movies/:movieNumber/player',
            builder: (context, state) =>
                const Scaffold(body: Text('player-page')),
          ),
        ],
      );
      addTearDown(router.dispose);

      // 内置实现按平台选播放页；widget 测试默认平台是 Android，这里按桌面验证。
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
            child: MaterialApp.router(
              theme: sakuraThemeData,
              routerConfig: router,
            ),
          ),
        );

        await _hoverCard(tester, 'ABC-022');
        await tester.tap(
          find.byKey(const Key('movie-summary-card-play-ABC-022')),
        );
        await tester.pumpAndSettle();

        // 内置实现把应用内播放页压在栈上；这个版本的 GoRouter
        // currentConfiguration.uri 不反映 imperative push，直接断言页面已渲染。
        expect(find.text('player-page'), findsOneWidget);
        // 内层播放按钮必须吃掉这次点击，不能同时打开详情。
        expect(cardTaps, 0);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'movie summary card plays confirm haptic on card-level heart tap',
    (WidgetTester tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      var subscriptionTaps = 0;
      var cardTaps = 0;
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: const MovieListItemDto(
                    javdbId: 'MovieA6',
                    movieNumber: 'ABC-010',
                    title: 'Movie 6',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    heat: 0,
                    isSubscribed: false,
                    canPlay: false,
                  ),
                  onTap: () => cardTaps++,
                  onSubscriptionTap: () => subscriptionTaps++,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(
        tester.getCenter(
          find.byKey(const Key('movie-summary-card-subscription-ABC-010')),
        ),
      );
      await tester.pump();

      expect(subscriptionTaps, 1);
      expect(cardTaps, 0);
      expect(
        calls.map((call) => '${call.method}:${call.arguments}'),
        contains('HapticFeedback.vibrate:HapticFeedbackType.selectionClick'),
      );

      calls.clear();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('movie-summary-card-ABC-010'))),
      );
      await tester.pump();

      expect(cardTaps, 1);
      expect(subscriptionTaps, 1);
      expect(
        calls.where((call) => call.method == 'HapticFeedback.vibrate'),
        isEmpty,
      );
    },
  );

  testWidgets(
    'movie summary card hides the inspector entry in selection mode',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: const MovieListItemDto(
                    javdbId: 'MovieA9',
                    movieNumber: 'ABC-031',
                    title: 'Movie 9',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    heat: 0,
                    isSubscribed: false,
                    canPlay: true,
                  ),
                  selectionMode: true,
                  onSelectedChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-summary-card-inspector-ABC-031')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'movie summary card animates the hover panel and drops the menu button',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: const MovieListItemDto(
                    javdbId: 'MovieB1',
                    movieNumber: 'ABC-032',
                    title: 'Movie 10',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    heat: 0,
                    isSubscribed: false,
                    canPlay: false,
                  ),
                  onRequestMenu: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // 展开行不再有「更多」按钮（右键 / 长按菜单入口仍在）。
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);

      await _startHoverCard(tester, 'ABC-032');
      await tester.pump(const Duration(milliseconds: 90));
      // 切换中间帧：收起与展开内容同时在树里（AnimatedSwitcher 正在过渡）。
      expect(
        find.byKey(const Key('movie-summary-card-number-ABC-032')),
        findsNWidgets(2),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      expect(
        find.byKey(const Key('movie-summary-card-number-ABC-032')),
        findsOneWidget,
      );
      expect(find.text('Movie 10'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-inspector-ABC-032')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'movie summary card skips the panel animation under reduced motion',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: const SizedBox(
                    width: 220,
                    child: MovieSummaryCard(
                      movie: MovieListItemDto(
                        javdbId: 'MovieB4',
                        movieNumber: 'ABC-033',
                        title: 'Movie 13',
                        coverImage: null,
                        releaseDate: null,
                        durationMinutes: 0,
                        heat: 0,
                        isSubscribed: false,
                        canPlay: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await _startHoverCard(tester, 'ABC-033');
      // 关闭动画后切换瞬时完成：不会出现收起 / 展开内容同时在场的中间帧。
      expect(
        find.byKey(const Key('movie-summary-card-number-ABC-033')),
        findsOneWidget,
      );
      expect(find.text('Movie 13'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'movie summary card opens the inspector dialog from the list entry',
    (WidgetTester tester) async {
      var cardTaps = 0;
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionStore = await buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/movies/ABC-040',
        body: <String, dynamic>{
          'javdb_id': 'MovieB2',
          'movie_number': 'ABC-040',
          'title': 'Movie 11',
          'cover_image': null,
          'thin_cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'is_subscribed': false,
          'can_play': true,
          'media_items': <Map<String, dynamic>>[
            <String, dynamic>{
              'media_id': 100,
              'play_url': '/files/media/movies/ABC-040/video.mp4',
              'resolution': '1920x1080',
              'valid': true,
            },
          ],
        },
      );
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/movies/ABC-040/reviews',
        body: <dynamic>[],
      );
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        body: <dynamic>[],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: bundle.riverpodOverrides(),
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: const MovieListItemDto(
                    javdbId: 'MovieB2',
                    movieNumber: 'ABC-040',
                    title: 'Movie 11',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 120,
                    heat: 0,
                    isSubscribed: false,
                    canPlay: true,
                  ),
                  onTap: () => cardTaps++,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('movie-summary-card-inspector-ABC-040')),
      );
      await tester.pumpAndSettle();

      // 先取一次影片详情拿默认媒体，再弹出与详情页一致的检查器对话框。
      expect(bundle.adapter.hitCount('GET', '/movies/ABC-040'), 1);
      expect(
        find.byKey(const Key('movie-detail-inspector-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-detail-inspector-panel')),
        findsOneWidget,
      );
      // 内层按钮必须吃掉这次点击，不能同时打开详情。
      expect(cardTaps, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'movie summary card opens the inspector bottom sheet on mobile',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionStore = await buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/movies/ABC-041',
        body: <String, dynamic>{
          'javdb_id': 'MovieB3',
          'movie_number': 'ABC-041',
          'title': 'Movie 12',
          'cover_image': null,
          'thin_cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'is_subscribed': false,
          'can_play': true,
          'media_items': <Map<String, dynamic>>[
            <String, dynamic>{
              'media_id': 101,
              'play_url': '/files/media/movies/ABC-041/video.mp4',
              'resolution': '1920x1080',
              'valid': true,
            },
          ],
        },
      );
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/movies/ABC-041/reviews',
        body: <dynamic>[],
      );
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/media/101/thumbnails',
        body: <dynamic>[],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: bundle.riverpodOverrides(),
          child: AppPlatformScope(
            platform: AppPlatform.mobile,
            child: MaterialApp(
              theme: sakuraMobileThemeData,
              home: Scaffold(
                body: SizedBox(
                  width: 220,
                  child: MovieSummaryCard(
                    movie: const MovieListItemDto(
                      javdbId: 'MovieB3',
                      movieNumber: 'ABC-041',
                      title: 'Movie 12',
                      coverImage: null,
                      releaseDate: null,
                      durationMinutes: 120,
                      heat: 0,
                      isSubscribed: false,
                      canPlay: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('movie-summary-card-inspector-ABC-041')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-inspector-bottom-sheet')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'movie summary card hover action row triggers collection type and blacklist',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      var collectionType = 0;
      var blacklist = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: const MovieListItemDto(
                    javdbId: 'MovieA9',
                    movieNumber: 'ABC-031',
                    title: 'Movie 9',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    heat: 0,
                    isSubscribed: false,
                    canPlay: false,
                  ),
                  onToggleCollectionType: () => collectionType++,
                  onBlacklist: () => blacklist++,
                ),
              ),
            ),
          ),
        ),
      );

      await _hoverCard(tester, 'ABC-031');

      await tester.tap(
        find.byKey(const Key('movie-summary-card-collection-type-ABC-031')),
      );
      await tester.tap(
        find.byKey(const Key('movie-summary-card-blacklist-ABC-031')),
      );
      await tester.pumpAndSettle();

      expect(collectionType, 1);
      expect(blacklist, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('movie summary card hides blacklist while subscribed', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: const MovieListItemDto(
                  javdbId: 'MovieA10',
                  movieNumber: 'ABC-032',
                  title: 'Movie 10',
                  coverImage: null,
                  releaseDate: null,
                  durationMinutes: 0,
                  heat: 0,
                  isSubscribed: true,
                  canPlay: false,
                ),
                onToggleCollectionType: () {},
                onBlacklist: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await _hoverCard(tester, 'ABC-032');

    expect(
      find.byKey(const Key('movie-summary-card-collection-type-ABC-032')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-blacklist-ABC-032')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄卡四个动作加排名徽标不溢出', (WidgetTester tester) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(sessionStore)],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              // 相似影片条的实际卡宽：movieCardTargetWidth(220) × 0.75。
              width: 165,
              child: MovieSummaryCard(
                movie: const MovieListItemDto(
                  javdbId: 'MovieA11',
                  movieNumber: 'ABC-033',
                  title: 'Movie 11',
                  coverImage: null,
                  releaseDate: null,
                  durationMinutes: 0,
                  heat: 0,
                  isSubscribed: false,
                  canPlay: true,
                ),
                rank: 3,
                onSubscriptionTap: () {},
                onToggleCollectionType: () {},
                onBlacklist: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await _hoverCard(tester, 'ABC-033');

    expect(
      find.byKey(const Key('movie-summary-card-play-ABC-033')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-subscription-action-ABC-033')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-collection-type-ABC-033')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-blacklist-ABC-033')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-rank-ABC-033')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

/// 把鼠标指针移到卡片上：桌面端信息条靠悬停展开，必须用真实指针事件触发。
Future<void> _hoverCard(WidgetTester tester, String movieNumber) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(
    tester.getCenter(find.byKey(Key('movie-summary-card-$movieNumber'))),
  );
  await tester.pumpAndSettle();
}

/// 悬停但不等待动画结束：用于断言 AnimatedSwitcher 的过渡中间帧。
Future<void> _startHoverCard(WidgetTester tester, String movieNumber) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(
    tester.getCenter(find.byKey(Key('movie-summary-card-$movieNumber'))),
  );
  await tester.pump();
}
