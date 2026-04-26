import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/overview/overview_stats_strip.dart';

void main() {
  testWidgets('overview stats strip keeps default tile sizing and text style', (
    WidgetTester tester,
  ) async {
    await _pumpStatsStrip(
      tester,
      items: const [
        OverviewStatItem(id: 'default', label: '影片总数', value: '13170'),
      ],
    );

    final tileSize = tester.getSize(
      find.byKey(const Key('overview-stat-default')),
    );
    expect(tileSize.width, 150);
    expect(tileSize.width, lessThanOrEqualTo(190));

    final valueText = tester.widget<Text>(find.text('13170'));
    expect(valueText.style?.fontSize, 18);
    expect(valueText.maxLines, 1);
    expect(valueText.softWrap, isFalse);
    expect(valueText.overflow, TextOverflow.ellipsis);
  });

  testWidgets(
    'overview stats strip supports custom tile width and value size',
    (WidgetTester tester) async {
      await _pumpStatsStrip(
        tester,
        items: const [
          OverviewStatItem(
            id: 'external-data-sources',
            label: '外部数据源',
            value: '未检测 JavDB / DMM',
            valueTextSize: AppTextSize.s14,
            maxWidth: 260,
          ),
        ],
      );

      final tileSize = tester.getSize(
        find.byKey(const Key('overview-stat-external-data-sources')),
      );
      expect(tileSize.width, greaterThan(150));
      expect(tileSize.width, lessThanOrEqualTo(260));

      final valueText = tester.widget<Text>(find.text('未检测 JavDB / DMM'));
      expect(valueText.style?.fontSize, 14);
      expect(valueText.style?.fontWeight, FontWeight.w600);
    },
  );

  testWidgets('overview stats strip action does not change tile height', (
    WidgetTester tester,
  ) async {
    await _pumpStatsStrip(
      tester,
      items: [
        const OverviewStatItem(id: 'plain', label: '待索引', value: '0'),
        OverviewStatItem(
          id: 'with-action',
          label: '外部数据源',
          value: '未检测 JavDB / DMM',
          valueTextSize: AppTextSize.s12,
          maxWidth: 260,
          action: IconButton(
            key: const Key('overview-stat-test-action'),
            onPressed: () {},
            icon: const Icon(Icons.radar_rounded),
          ),
        ),
      ],
    );

    final plainHeight =
        tester.getSize(find.byKey(const Key('overview-stat-plain'))).height;
    final actionHeight =
        tester
            .getSize(find.byKey(const Key('overview-stat-with-action')))
            .height;

    expect(actionHeight, plainHeight);
  });
}

Future<void> _pumpStatsStrip(
  WidgetTester tester, {
  required List<OverviewStatItem> items,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: Center(child: OverviewStatsStrip(items: items, isLoading: false)),
      ),
    ),
  );
}
