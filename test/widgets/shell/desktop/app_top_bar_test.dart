import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_top_bar.dart';

void main() {
  testWidgets(
    'top bar back button pops the shell navigator in glass and high contrast modes',
    (tester) async {
      for (final highContrast in <bool>[false, true]) {
        final shellNavigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: sakuraDesktopThemeData,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(highContrast: highContrast),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: Navigator(
                key: shellNavigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Center(child: Text('列表页'))),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        shellNavigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: AppTopBar(
                currentPath: '/desktop/library/movies/ABC-001',
                config: const DesktopTopBarConfig(
                  title: '影片详情',
                  fallbackPath: null,
                  isBackEnabled: true,
                ),
                shellNavigatorKey: shellNavigatorKey,
                translucent: true,
                hideActions: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('影片详情'), findsOneWidget);
        await tester.tap(find.byKey(const Key('topbar-back-button')));
        await tester.pumpAndSettle();

        expect(find.text('列表页'), findsOneWidget);
        expect(find.text('影片详情'), findsNothing);
      }
    },
  );
}
