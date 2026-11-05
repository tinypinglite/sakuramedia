import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_state.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/desktop_overview_insights.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('宽屏把趋势和存储排成有主次的洞察带', (WidgetTester tester) async {
    await _pumpBand(tester, width: 1200);

    final trend = tester.getRect(
      find.byKey(const Key('overview-watch-trend-card')),
    );
    final storage = tester.getRect(
      find.byKey(const Key('overview-storage-usage-card')),
    );
    expect(find.byKey(const Key('overview-insights-band')), findsOneWidget);
    expect(trend.top, storage.top);
    expect(trend.width, greaterThan(storage.width));
    expect(storage.left, greaterThan(trend.left));
    expect(
      find.byKey(const Key('overview-watch-trend-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('overview-storage-usage-surface')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄窗口把洞察带改为上下排列', (WidgetTester tester) async {
    await _pumpBand(tester, width: 700);

    final trend = tester.getRect(
      find.byKey(const Key('overview-watch-trend-card')),
    );
    final storage = tester.getRect(
      find.byKey(const Key('overview-storage-usage-card')),
    );
    expect(storage.top, greaterThan(trend.top));
    expect(storage.left, trend.left);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpBand(WidgetTester tester, {required double width}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: DesktopOverviewInsights(
              state: _state(),
              onTrendRangeChanged: (_) {},
              onTrendRetry: () {},
              onInsightsRetry: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

OverviewSystemInfoState _state() {
  return const OverviewSystemInfoState(
    isLoadingStatus: false,
    isLoadingImageSearchStatus: false,
    isLoadingInsights: false,
    isLoadingWatchTrend: false,
    watchTrendRange: WatchTrendRange.last30Days,
    watchTrend: StatusWatchTrendDto(
      range: WatchTrendRange.last30Days,
      granularity: 'day',
      watchedMovieCount: 3,
      buckets: <WatchTrendBucketDto>[
        WatchTrendBucketDto(period: '2026-09-01', count: 1),
        WatchTrendBucketDto(period: '2026-09-02', count: 2),
      ],
    ),
    insights: StatusInsightsDto(
      mediaLibraries: <MediaLibraryUsageDto>[
        MediaLibraryUsageDto(
          libraryId: 1,
          name: '主媒体库',
          providerKey: 'local',
          fileCount: 1420,
          totalSizeBytes: 6400000000000,
        ),
      ],
    ),
  );
}
