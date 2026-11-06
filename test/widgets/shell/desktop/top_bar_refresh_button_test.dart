import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/desktop/top_bar_refresh_button.dart';

void main() {
  for (final glass in <bool>[false, true]) {
    testWidgets(
      'refresh button triggers the controlled action (glass: $glass)',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: sakuraDesktopThemeData,
            home: Scaffold(
              body: TopBarRefreshButton(
                onPressed: () => taps += 1,
                isRefreshing: false,
                glass: glass,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('topbar-refresh-button')));

        expect(taps, 1);
      },
    );

    testWidgets('refreshing refresh button is disabled and shows loading state '
        '(glass: $glass)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sakuraDesktopThemeData,
          home: Scaffold(
            body: TopBarRefreshButton(
              onPressed: () => taps += 1,
              isRefreshing: true,
              glass: glass,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('topbar-refresh-button-loading')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('topbar-refresh-button')), findsNothing);

      await tester.tap(
        find.byKey(const Key('topbar-refresh-button-loading')),
        warnIfMissed: false,
      );

      expect(taps, 0);
    });
  }
}
