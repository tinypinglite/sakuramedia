import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

void main() {
  testWidgets('desktop app tab bar switches controller index on tap', (
    WidgetTester tester,
  ) async {
    late TabController controller;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return const Material(
                child: AppTabBar(tabs: [Tab(text: '基础信息'), Tab(text: '下载器')]),
              );
            },
          ),
        ),
      ),
    );

    expect(controller.index, 0);

    await tester.tap(find.text('下载器'));
    await tester.pumpAndSettle();

    expect(controller.index, 1);
  });

  testWidgets('desktop app tab bar renders with the configured height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: DefaultTabController(
          length: 2,
          child: const Material(
            child: AppTabBar(tabs: [Tab(text: '基础信息'), Tab(text: '下载器')]),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(Tab).first).height, 40);
  });

  testWidgets('desktop app tab bar uses labelMedium font size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: DefaultTabController(
          length: 2,
          child: const Material(
            child: AppTabBar(tabs: [Tab(text: '基础信息'), Tab(text: '下载器')]),
          ),
        ),
      ),
    );

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final labelStyle = tabBar.labelStyle as TextStyle;
    final unselectedLabelStyle = tabBar.unselectedLabelStyle as TextStyle;

    expect(labelStyle.fontSize, sakuraThemeData.textTheme.labelMedium!.fontSize);
    expect(
      unselectedLabelStyle.fontSize,
      sakuraThemeData.textTheme.labelMedium!.fontSize,
    );
  });

  test('compact app tab bar reports compact preferred height', () {
    const widget = AppTabBar(
      variant: AppTabBarVariant.compact,
      tabs: [Tab(text: 'A')],
    );

    expect(widget.preferredSize.height, 32);
  });

  test('mobileTop app tab bar reports mobile preferred height', () {
    const widget = AppTabBar(
      variant: AppTabBarVariant.mobileTop,
      tabs: [Tab(text: 'A')],
    );

    expect(widget.preferredSize.height, 48);
  });

  testWidgets('mobileTop app tab bar centers tabs and allows scroll layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: DefaultTabController(
          length: 4,
          child: const Material(
            child: AppTabBar(
              variant: AppTabBarVariant.mobileTop,
              tabs: [
                Tab(text: '我的'),
                Tab(text: '关注'),
                Tab(text: '发现'),
                Tab(text: '时刻'),
              ],
            ),
          ),
        ),
      ),
    );

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.isScrollable, isTrue);
    expect(tabBar.tabAlignment, TabAlignment.center);
    expect(
      tabBar.labelPadding,
      EdgeInsets.symmetric(horizontal: sakuraThemeData.appSpacing.sm),
    );
  });
}
