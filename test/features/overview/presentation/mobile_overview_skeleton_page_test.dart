import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/overview/presentation/mobile_overview_skeleton_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

void main() {
  testWidgets('mobile overview page uses AppTabBar mobileTop variant', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: MobileOverviewSkeletonPage()),
      ),
    );
    await tester.pumpAndSettle();

    final tabBar = tester.widget<AppTabBar>(
      find.byKey(const Key('mobile-overview-tabs')),
    );
    expect(tabBar.variant, AppTabBarVariant.mobileTop);
  });

  testWidgets('mobile overview supports swipe to switch tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: MobileOverviewSkeletonPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的内容骨架搭建中'), findsOneWidget);
    expect(find.text('关注内容骨架搭建中'), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();

    expect(find.text('关注内容骨架搭建中'), findsOneWidget);
  });
}
