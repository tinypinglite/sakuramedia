import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/search/catalog_search_stream_status_card.dart';

void main() {
  testWidgets(
    'catalog search stream status card vertically centers icon with text content',
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

      final row = tester.widget<Row>(
        find.descendant(
          of: find.byKey(const Key('catalog-search-stream-status-card')),
          matching: find.byType(Row),
        ),
      );

      expect(row.crossAxisAlignment, CrossAxisAlignment.center);
    },
  );
}
