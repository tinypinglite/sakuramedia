import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_update_check_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/sidebar_version_footer.dart';

void main() {
  testWidgets('footer exposes version actions without provider access', (
    tester,
  ) async {
    var frontendReleaseCount = 0;
    var backendReleaseCount = 0;
    var pluginUpdatesCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildSakuraMobileThemeData(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SidebarVersionFooter(
                version: const AppVersionInfoState(
                  frontendVersion: '1.2.3',
                  backendVersion: 'v1.0.0',
                ),
                pluginUpdates: 2,
                updates: const AppUpdateCheckState(
                  frontendUpdateVersion: '1.3.0',
                  backendUpdateVersion: 'v1.1.0',
                ),
                onOpenFrontendRelease: () => frontendReleaseCount += 1,
                onOpenBackendRelease: () => backendReleaseCount += 1,
                onOpenPluginUpdates: () => pluginUpdatesCount += 1,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sidebar-version-update-dot')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar-version-info')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar-version-popover')), findsOneWidget);
    expect(find.byKey(const Key('sidebar-update-notice')), findsOneWidget);
    expect(
      find.byKey(const Key('version-release-link-frontend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('version-release-link-backend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sidebar-version-popover-go-plugins')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('version-release-link-frontend')));
    await tester.pumpAndSettle();
    expect(frontendReleaseCount, 1);

    await tester.tap(find.byKey(const Key('sidebar-version-info')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('version-release-link-backend')));
    await tester.pumpAndSettle();
    expect(backendReleaseCount, 1);

    await tester.tap(find.byKey(const Key('sidebar-version-info')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('sidebar-version-popover-go-plugins')),
    );
    await tester.pumpAndSettle();
    expect(pluginUpdatesCount, 1);
  });

  testWidgets('footer hides update-only entries when everything is current', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildSakuraMobileThemeData(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SidebarVersionFooter(
                version: const AppVersionInfoState(
                  frontendVersion: '1.2.3',
                  backendVersion: 'v1.0.0',
                ),
                pluginUpdates: 0,
                updates: AppUpdateCheckState.initial,
                onOpenFrontendRelease: () {},
                onOpenBackendRelease: () {},
                onOpenPluginUpdates: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('sidebar-version-info')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar-update-notice')), findsNothing);
    expect(
      find.byKey(const Key('version-release-link-frontend')),
      findsNothing,
    );
    expect(find.byKey(const Key('version-release-link-backend')), findsNothing);
    expect(
      find.byKey(const Key('sidebar-version-popover-go-plugins')),
      findsNothing,
    );
  });
}
