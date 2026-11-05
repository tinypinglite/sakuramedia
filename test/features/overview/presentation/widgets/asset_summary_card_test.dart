import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/asset_summary_card.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';

void main() {
  testWidgets('渲染分格数字与副文案', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpCard(
      tester,
      AssetSummaryCard(status: _status(), insights: null, pendingIndexCount: 0),
    );

    expect(find.byKey(const Key('overview-asset-movies')), findsOneWidget);
    expect(find.text('1,286'), findsOneWidget);
    expect(find.text('可播放 1,104 · 已订阅 87'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    expect(find.text('2,410'), findsOneWidget);
    expect(find.text('9.0 TB'), findsOneWidget);
    expect(find.text('2,410 个媒体文件 · 2,318 张缩略图'), findsOneWidget);
  });

  testWidgets('Hero 布局建立主指标层级并收拢库状态', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      AssetSummaryCard(
        status: _status(),
        insights: StatusInsightsDto(
          collections: CollectionsStatsDto(
            playlists: const CollectionSummaryDto(count: 5, itemCount: 42),
            videoCollections: const CollectionSummaryDto(
              count: 2,
              itemCount: 8,
            ),
          ),
        ),
        pendingIndexCount: 12,
        layout: AssetSummaryCardLayout.hero,
      ),
    );

    final primaryWidth = tester
        .getSize(find.byKey(const Key('overview-asset-media-size')))
        .width;
    final supportingWidth = tester
        .getSize(find.byKey(const Key('overview-asset-movies')))
        .width;
    expect(primaryWidth, greaterThan(supportingWidth));
    final statusLine = find.byKey(const Key('overview-asset-status-line'));
    expect(statusLine, findsOneWidget);
    expect(find.text('3 个资源库'), findsOneWidget);
    expect(
      find.descendant(of: statusLine, matching: find.textContaining('待生成缩略图')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: statusLine, matching: find.textContaining('待索引')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: statusLine, matching: find.textContaining('合集：')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hero 布局在窄窗口回退到等权分格', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(540, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      AssetSummaryCard(
        status: _status(),
        insights: null,
        pendingIndexCount: 0,
        layout: AssetSummaryCardLayout.hero,
      ),
    );

    final primaryWidth = tester
        .getSize(find.byKey(const Key('overview-asset-movies')))
        .width;
    final supportingWidth = tester
        .getSize(find.byKey(const Key('overview-asset-actors')))
        .width;
    expect(primaryWidth, supportingWidth);
    expect(find.byKey(const Key('overview-asset-status-line')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄卡片副文案只保留一个事实，避免中文断词', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      AssetSummaryCard(status: _status(), insights: null, pendingIndexCount: 0),
    );

    expect(find.text('可播放 1,104'), findsOneWidget);
    expect(find.textContaining('已订阅 87'), findsNothing);
  });

  testWidgets('加载态宽卡片渲染骨架，高度与数据态接近', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      const AssetSummaryCard(
        status: null,
        insights: null,
        pendingIndexCount: 0,
        isLoading: true,
      ),
    );

    // 加载态渲染的是真实分格（占位数据），由 AppSkeletonizer 灰化。
    expect(find.byKey(const Key('overview-asset-movies')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppSkeletonizer && widget.enabled,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    final skeletonHeight = tester
        .getSize(find.byKey(const Key('overview-asset-summary-card')))
        .height;

    await _pumpCard(
      tester,
      AssetSummaryCard(
        status: _status(),
        insights: StatusInsightsDto(
          collections: CollectionsStatsDto(
            playlists: const CollectionSummaryDto(count: 5, itemCount: 42),
            videoCollections: const CollectionSummaryDto(
              count: 2,
              itemCount: 8,
            ),
          ),
        ),
        pendingIndexCount: 12,
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppSkeletonizer && widget.enabled,
      ),
      findsNothing,
    );
    final loadedHeight = tester
        .getSize(find.byKey(const Key('overview-asset-summary-card')))
        .height;
    expect((skeletonHeight - loadedHeight).abs(), lessThan(20));
  });

  testWidgets('加载态窄卡片折成两行两格，高度与数据态接近', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      const AssetSummaryCard(
        status: null,
        insights: null,
        pendingIndexCount: 0,
        isLoading: true,
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppSkeletonizer && widget.enabled,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    final skeletonHeight = tester
        .getSize(find.byKey(const Key('overview-asset-summary-card')))
        .height;

    await _pumpCard(
      tester,
      AssetSummaryCard(
        status: _status(),
        insights: StatusInsightsDto(
          collections: CollectionsStatsDto(
            playlists: const CollectionSummaryDto(count: 5, itemCount: 42),
            videoCollections: const CollectionSummaryDto(
              count: 2,
              itemCount: 8,
            ),
          ),
        ),
        pendingIndexCount: 12,
      ),
    );

    final loadedHeight = tester
        .getSize(find.byKey(const Key('overview-asset-summary-card')))
        .height;
    expect((skeletonHeight - loadedHeight).abs(), lessThan(20));
  });

  testWidgets('没有积压与合集时隐藏两行脚注', (WidgetTester tester) async {
    await _pumpCard(
      tester,
      AssetSummaryCard(
        status: _status(
          thumbnails: const ThumbnailStatsDto(
            pendingMedia: 0,
            retryWaitMedia: 0,
            terminalFailedMedia: 0,
            total: 2318,
          ),
        ),
        insights: null,
        pendingIndexCount: 0,
      ),
    );

    expect(find.textContaining('待生成缩略图'), findsNothing);
    expect(find.textContaining('合集'), findsNothing);
  });

  testWidgets('存在积压与合集时展示脚注', (WidgetTester tester) async {
    await _pumpCard(
      tester,
      AssetSummaryCard(
        status: _status(),
        insights: StatusInsightsDto(
          collections: CollectionsStatsDto(
            playlists: const CollectionSummaryDto(count: 5, itemCount: 42),
            videoCollections: const CollectionSummaryDto(
              count: 2,
              itemCount: 8,
            ),
          ),
        ),
        pendingIndexCount: 12,
      ),
    );

    expect(find.textContaining('待生成缩略图'), findsOneWidget);
    expect(find.textContaining('待索引'), findsOneWidget);
    expect(find.textContaining('缩略图失败'), findsNothing);
    expect(find.textContaining('播放列表'), findsOneWidget);
    expect(find.textContaining('片段合集'), findsNothing);
  });

  testWidgets('错误态展示重试按钮', (WidgetTester tester) async {
    var retried = false;
    await _pumpCard(
      tester,
      AssetSummaryCard(
        status: null,
        insights: null,
        pendingIndexCount: 0,
        errorMessage: '媒体资产加载失败，请稍后重试',
        onRetry: () => retried = true,
      ),
    );

    expect(find.text('媒体资产加载失败，请稍后重试'), findsOneWidget);
    await tester.tap(find.byKey(const Key('overview-asset-retry-button')));
    await tester.pump();
    expect(retried, isTrue);
  });
}

StatusDto _status({
  ActorStatsDto actors = const ActorStatsDto(
    femaleTotal: 128,
    femaleSubscribed: 34,
  ),
  MovieStatsDto movies = const MovieStatsDto(
    total: 1286,
    subscribed: 87,
    playable: 1104,
  ),
  MediaFileStatsDto mediaFiles = const MediaFileStatsDto(
    total: 2410,
    totalSizeBytes: 9876543210987,
  ),
  MediaLibraryStatsDto mediaLibraries = const MediaLibraryStatsDto(total: 3),
  ThumbnailStatsDto thumbnails = const ThumbnailStatsDto(
    pendingMedia: 12,
    retryWaitMedia: 3,
    terminalFailedMedia: 4,
    total: 2318,
  ),
}) {
  return StatusDto(
    backendVersion: 'v1.0.0',
    actors: actors,
    movies: movies,
    mediaFiles: mediaFiles,
    mediaLibraries: mediaLibraries,
    thumbnails: thumbnails,
  );
}

Future<void> _pumpCard(WidgetTester tester, Widget card) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );
}
