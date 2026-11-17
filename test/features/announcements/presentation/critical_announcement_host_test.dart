import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/features/announcements/data/announcements_api.dart';
import 'package:sakuramedia/features/announcements/presentation/announcement_state_store.dart';
import 'package:sakuramedia/features/announcements/presentation/critical_announcement_host.dart';
import 'package:sakuramedia/features/announcements/presentation/providers/announcement_state_store_provider.dart';
import 'package:sakuramedia/features/announcements/presentation/providers/announcements_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets(
    'host shows critical announcements and persists acknowledgement',
    (tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');
      await sessionStore.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final stateStore = InMemoryAnnouncementStateStore();
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sessionStoreProvider.overrideWithValue(sessionStore),
            announcementsApiProvider.overrideWithValue(
              _CriticalAnnouncementsApi(),
            ),
            announcementStateStoreProvider.overrideWithValue(stateStore),
            appVersionInfoProvider.overrideWith(_FixedVersionInfo.new),
          ],
          child: CriticalAnnouncementHost(
            sessionStore: sessionStore,
            navigatorKey: navigatorKey,
            isLoginPage: () => false,
            child: MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              locale: const Locale('zh'),
              localizationsDelegates: <LocalizationsDelegate<dynamic>>[
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildSakuraDesktopThemeData(),
              home: const Scaffold(body: SizedBox.shrink()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('critical-announcements-dialog')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('critical-announcement-acknowledge')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('critical-announcements-dialog')),
        findsNothing,
      );
      expect(stateStore.acknowledgedIds, contains('critical-1'));
    },
  );
}

class _CriticalAnnouncementsApi implements AnnouncementsApi {
  @override
  Future<List<AnnouncementDto>> getAnnouncements() async {
    return <AnnouncementDto>[
      AnnouncementDto(
        id: 'critical-1',
        level: AnnouncementLevel.critical,
        titleI18n: const <String, String>{
          'zh-CN': '需要处理',
          'en': 'Action required',
        },
        bodyI18n: const <String, String>{
          'zh-CN': '请升级到最新版本。',
          'en': 'Please upgrade.',
        },
        publishedAt: DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        ),
      ),
    ];
  }
}

class _FixedVersionInfo extends AppVersionInfo {
  @override
  AppVersionInfoState build() => const AppVersionInfoState(
    frontendVersion: '0.15.0',
    backendVersion: '0.15.0',
  );

  @override
  Future<void> load() async {}
}
