import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/mobile/mobile_media_tags_page.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-10-31T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() => bundle.dispose());

  Widget wrap() {
    return ProviderScope(
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
          home: const Scaffold(body: MobileMediaTagsPage()),
        ),
      ),
    );
  }

  testWidgets('renders mobile rules and creates a tag in a drawer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '4K',
          'include_terms': ['4k'],
          'exclude_terms': <dynamic>[],
          'enabled': false,
          'media_count': 3,
          'created_at': '2026-10-30T01:02:03Z',
          'updated_at': '2026-10-30T01:02:03Z',
        },
      ],
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-settings-media-tags')), findsOneWidget);
    expect(find.byKey(const Key('mobile-media-tag-rule-1')), findsOneWidget);
    expect(find.text('已停用'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-media-tag-create-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('media-tag-rule-editor-drawer')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('media-tag-name-field')),
      'Subtitles',
    );
    await tester.enterText(
      find.byKey(const Key('media-tag-include-terms-field')),
      '中文字幕',
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/media-tags',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 2,
        'name': 'Subtitles',
        'include_terms': ['中文字幕'],
        'exclude_terms': <dynamic>[],
        'enabled': true,
        'media_count': 0,
        'created_at': '2026-10-31T01:02:03Z',
        'updated_at': '2026-10-31T01:02:03Z',
      },
    );
    await tester.tap(find.byKey(const Key('media-tag-rule-save')));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/media-tags'), 1);
    expect(find.byKey(const Key('mobile-media-tag-rule-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows the empty state and validates a new rule', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: const <Map<String, dynamic>>[],
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-media-tags-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mobile-media-tag-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-tag-rule-save')));
    await tester.pumpAndSettle();

    expect(find.text('请输入标签名称'), findsOneWidget);
    expect(find.text('至少需要一个命中词'), findsOneWidget);
    expect(bundle.adapter.hitCount('POST', '/media-tags'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a load error and retries', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      statusCode: 500,
      body: <String, dynamic>{
        'error': {'code': 'internal_error', 'message': 'boom'},
      },
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-media-tags-error')), findsOneWidget);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: const <Map<String, dynamic>>[],
    );
    await tester.tap(find.byKey(const Key('mobile-media-tags-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-media-tags-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes a rule from the mobile action sheet', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 9,
          'name': 'Delete me',
          'include_terms': ['delete'],
          'exclude_terms': <dynamic>[],
          'enabled': true,
          'media_count': 0,
          'created_at': '2026-10-31T01:02:03Z',
          'updated_at': '2026-10-31T01:02:03Z',
        },
      ],
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-media-tag-more-9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-media-tag-delete-9')));
    await tester.pumpAndSettle();
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media-tags/9',
      statusCode: 204,
      body: null,
    );
    await tester.tap(
      find.byKey(const Key('mobile-media-tag-delete-confirm-9')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-media-tag-rule-9')), findsNothing);
    expect(find.byKey(const Key('mobile-media-tags-empty')), findsOneWidget);
    expect(bundle.adapter.hitCount('DELETE', '/media-tags/9'), 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('submits the retag task from mobile', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: const <Map<String, dynamic>>[],
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('media-tag-retag-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/jobs/media_tag_retag/runs',
      statusCode: 202,
      body: <String, dynamic>{
        'task_run_id': 12,
        'task_key': 'media_tag_retag',
        'state': 'pending',
      },
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-tag-retag-confirm')));
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount('POST', '/system/jobs/media_tag_retag/runs'),
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });
}
