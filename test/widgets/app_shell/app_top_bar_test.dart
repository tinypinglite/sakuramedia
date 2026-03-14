import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_top_bar.dart';

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
}
