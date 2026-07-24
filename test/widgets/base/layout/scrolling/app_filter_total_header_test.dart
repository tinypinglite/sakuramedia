import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';

void main() {
  testWidgets('filter total header locks to the shared list header height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Material(
          // 顶部对齐，让高度约束是 loose 的——否则 home 的 tight 约束会把
          // 组件撑满整屏，量不出它自己的高度。
          child: Align(
            alignment: Alignment.topLeft,
            child: AppFilterTotalHeader(
              leading: SizedBox(height: 32, child: Text('筛选')),
              totalText: '34 位',
              totalKey: Key('header-total'),
            ),
          ),
        ),
      ),
    );

    // 与 AppListHeader 同高，页面之间 / 进出多选都不跳版。
    final tokens = sakuraThemeData.appComponentTokens;
    expect(
      tester.getSize(find.byType(AppFilterTotalHeader)).height,
      tokens.mobileTopTabHeight + sakuraThemeData.appSpacing.xs,
    );
  });

  testWidgets('filter total header centers total text within the first row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Material(
          // 顶部对齐，让高度约束是 loose 的——否则 home 的 tight 约束会把
          // 组件撑满整屏，量不出它自己的高度。
          child: Align(
            alignment: Alignment.topLeft,
            child: AppFilterTotalHeader(
              leading: SizedBox(height: 32, child: Text('筛选')),
              totalText: '34 位',
              totalKey: Key('header-total'),
            ),
          ),
        ),
      ),
    );

    final totalContainerRect = tester.getRect(
      find
          .ancestor(
            of: find.byKey(const Key('header-total')),
            matching: find.byWidgetPredicate(
              (widget) => widget is SizedBox && widget.height != null,
            ),
          )
          .first,
    );
    final totalTextRect = tester.getRect(find.byKey(const Key('header-total')));

    expect(
      totalTextRect.center.dy,
      moreOrLessEquals(totalContainerRect.center.dy, epsilon: 0.5),
    );
  });
}
