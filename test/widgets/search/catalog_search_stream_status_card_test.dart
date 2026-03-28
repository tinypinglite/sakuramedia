import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/search/data/catalog_search_stream_stats.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/search/catalog_search_stream_status_card.dart';

void main() {
  testWidgets(
    'catalog search stream status card shows centered text content without status icon',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: CatalogSearchStreamStatusCard(
              status: CatalogSearchStreamStatus(
                message: '正在从外部数据源搜索影片',
                isRunning: true,
                isFailure: false,
              ),
            ),
          ),
        ),
      );

      final column = tester.widget<Column>(
        find.byKey(const Key('catalog-search-stream-status-content')),
      );
      expect(column.mainAxisSize, MainAxisSize.min);
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);
      expect(find.text('正在从外部数据源搜索影片'), findsOneWidget);
      expect(find.byIcon(Icons.public_rounded), findsNothing);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      expect(find.byIcon(Icons.cloud_done_outlined), findsNothing);
    },
  );

  testWidgets(
    'catalog search stream status card keeps progress and stats text visible',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: SizedBox(
              height: 240,
              child: CatalogSearchStreamStatusCard(
                status: CatalogSearchStreamStatus(
                  message: '正在同步在线影片搜索结果',
                  isRunning: false,
                  isFailure: false,
                  current: 4,
                  total: 12,
                  stats: CatalogSearchStreamStats(
                    total: 12,
                    createdCount: 3,
                    alreadyExistsCount: 8,
                    failedCount: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('正在同步在线影片搜索结果'), findsOneWidget);
      expect(find.text('4 / 12'), findsOneWidget);
      expect(find.text('共 12 条，新增 3，已存在 8，失败 1'), findsOneWidget);

      final center = tester.widget<Center>(
        find.descendant(
          of: find.byKey(const Key('catalog-search-stream-status-card')),
          matching: find.byType(Center),
        ),
      );
      expect(center.child, isNotNull);
    },
  );
}
