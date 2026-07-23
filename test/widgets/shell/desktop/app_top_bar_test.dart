import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_top_bar.dart';

void main() {
  testWidgets('app top bar back button uses xs icon token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppTopBar(
            currentPath: '/desktop/library/movies/ABC-001',
            config: DesktopTopBarConfig(
              title: '影片详情',
              fallbackPath: '/desktop/library/movies',
              isBackEnabled: true,
            ),
          ),
        ),
      ),
    );

    final backIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('topbar-back-button')),
        matching: find.byIcon(Icons.arrow_back_ios_new_rounded),
      ),
    );
    expect(backIcon.size, AppComponentTokens.defaults().iconSizeXs);
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('topbar-back-button')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, '返回');
  });

  testWidgets('app top bar hides refresh button when onRefresh is null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppTopBar(
            currentPath: '/desktop/library/movies',
            config: DesktopTopBarConfig(
              title: '影片',
              fallbackPath: null,
              isBackEnabled: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('topbar-refresh-button')), findsNothing);
    expect(find.byKey(const Key('topbar-refresh-button-loading')), findsNothing);
  });

  testWidgets('app top bar shows refresh button when onRefresh is provided', (
    WidgetTester tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppTopBar(
            currentPath: '/desktop/library/movies',
            config: const DesktopTopBarConfig(
              title: '影片',
              fallbackPath: null,
              isBackEnabled: false,
            ),
            onRefresh: () => callCount++,
          ),
        ),
      ),
    );

    final button = find.byKey(const Key('topbar-refresh-button'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.byIcon(Icons.refresh_rounded)),
      findsOneWidget,
    );

    await tester.tap(button);
    await tester.pump();
    expect(callCount, 1);
  });

  testWidgets(
    'app top bar renders spinner when controlled isRefreshing is true',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: AppTopBar(
              currentPath: '/desktop/library/movies',
              config: const DesktopTopBarConfig(
                title: '影片',
                fallbackPath: null,
                isBackEnabled: false,
              ),
              onRefresh: () {},
              isRefreshing: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('topbar-refresh-button')), findsNothing);
      expect(
        find.byKey(const Key('topbar-refresh-button-loading')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );
}
