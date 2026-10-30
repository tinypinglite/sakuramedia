import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/presentation/pages/mobile/account_security_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_download_selection_policy_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_downloaders_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_indexers_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_media_libraries_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_media_tags_page.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_system_maintenance_page.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/mobile/mobile_plugin_market_page.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/mobile/mobile_plugins_page.dart';
import 'package:sakuramedia/features/recent_views/presentation/pages/mobile/recent_views_page.dart';
import 'package:sakuramedia/features/recent_views/presentation/widgets/recent_view_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  /// 在真实子页壳里渲染页面（见 `_MobileSubpageRouteData.buildPage`）。
  Future<void> pumpSubpage(WidgetTester tester, Widget page) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: OKToast(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            theme: sakuraThemeData,
            home: AppMobileSubpageShell(
              title: '子页',
              defaultLocation: '/mobile/overview',
              child: page,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 内容左边缘应正好贴住子页壳的内容边缘：横向缩进只由壳的
  /// `bodyPadding` 提供，页面自己再补一层就会比兄弟页多缩一截。
  void expectAlignedWithShellInset(WidgetTester tester, Finder landmark) {
    final bodyRect = tester.getRect(
      find.byKey(const Key('mobile-subpage-body-padding')),
    );
    final left = tester.getTopLeft(landmark).dx;
    expect(left, bodyRect.left + AppPageInsets.compact);
  }

  testWidgets('设置 · 媒体库', (WidgetTester tester) async {
    await pumpSubpage(tester, const MobileMediaLibrariesPage());

    expectAlignedWithShellInset(
      tester,
      find.byKey(const Key('mobile-media-libraries-notice-card')),
    );
  });

  testWidgets('设置 · 媒体标签', (WidgetTester tester) async {
    await pumpSubpage(tester, const MobileMediaTagsPage());

    expectAlignedWithShellInset(tester, find.byType(AppNoticeCard).first);
  });

  testWidgets('设置 · 插件', (WidgetTester tester) async {
    await pumpSubpage(tester, const MobilePluginsPage());

    expectAlignedWithShellInset(
      tester,
      find.byKey(const Key('mobile-plugins-restart-notice')),
    );
  });

  testWidgets('设置 · 插件市场', (WidgetTester tester) async {
    await pumpSubpage(tester, const MobilePluginMarketPage());

    expectAlignedWithShellInset(tester, find.byType(AppNoticeCard).first);
  });

  testWidgets('设置 · 索引器', (WidgetTester tester) async {
    await pumpSubpage(tester, const MobileIndexersPage());

    expectAlignedWithShellInset(
      tester,
      find.byType(AppMobileSectionError).first,
    );
  });

  testWidgets('设置 · 下载器', (WidgetTester tester) async {
    await pumpSubpage(tester, const MobileDownloadersPage());

    expectAlignedWithShellInset(tester, find.byType(AppTabBar).first);
  });

  testWidgets('设置 · 系统维护', (WidgetTester tester) async {
    await pumpSubpage(tester, const MobileSystemMaintenancePage());

    expectAlignedWithShellInset(
      tester,
      find.byType(AppMobileSectionError).first,
    );
  });

  testWidgets('最近浏览更多页', (WidgetTester tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/view-history',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'entity_type': 'movie',
            'viewed_at': '2026-10-10T10:00:00',
            'movie': <String, dynamic>{
              'movie_number': 'ABC-001',
              'title': 'Movie 1',
              'cover_image': null,
              'release_date': '2026-05-01',
              'duration_minutes': 120,
              'is_subscribed': false,
              'can_play': true,
            },
            'actor': null,
          },
        ],
      },
    );

    await pumpSubpage(tester, const MobileRecentViewsPage());

    expectAlignedWithShellInset(tester, find.byType(RecentViewCard).first);
  });

  testWidgets('设置 · 账号安全', (WidgetTester tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/account',
      body: <String, dynamic>{
        'username': 'account',
        'created_at': '2026-03-08T09:00:00Z',
        'last_login_at': '2026-03-08T10:00:00Z',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/account/api-keys',
      body: <Map<String, Object?>>[],
    );

    await pumpSubpage(tester, const MobileAccountSecurityPage());

    expectAlignedWithShellInset(
      tester,
      find.byKey(const Key('mobile-account-card')),
    );
  });

  testWidgets('设置 · 下载选择策略', (WidgetTester tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/download-selection-policy',
      body: <String, dynamic>{
        'version': 1,
        'created_at': '2026-10-29T12:00:00Z',
        'updated_at': '2026-10-29T12:00:00Z',
        'rules': <String, dynamic>{
          'schema_version': 1,
          'indexer_kinds': <String>[],
          'indexer_names': <String>[],
          'min_size_bytes': 1024 * 1024 * 1024,
          'max_size_bytes': 40 * 1024 * 1024 * 1024,
          'min_seeders': 1,
          'max_age_days': null,
          'match_title': true,
          'match_description': true,
          'required_groups': <Map<String, dynamic>>[],
          'excluded_terms': <String>[],
          'preferred_groups': <Map<String, dynamic>>[],
          'ranking': <String>['size_desc'],
          'indexer_priority_names': <String>[],
        },
      },
    );

    await pumpSubpage(tester, const MobileDownloadSelectionPolicyPage());

    expectAlignedWithShellInset(tester, find.byType(AppNoticeCard).first);
  });
}
