import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/desktop/media_tags_section.dart';
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
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: DesktopMediaTagsSection(active: true),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('loads rules and submits a manual retag job', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '4K',
          'include_terms': ['4k', '2160p'],
          'exclude_terms': ['sample'],
          'enabled': true,
          'media_count': 8,
          'created_at': '2026-10-30T01:02:03Z',
          'updated_at': '2026-10-30T01:02:03Z',
        },
      ],
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-tag-rule-1')), findsOneWidget);
    expect(find.text('4k / 2160p · 排除 1 项: sample'), findsOneWidget);

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

  testWidgets('creates a media tag rule from one-term-per-line input', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: const <Map<String, dynamic>>[],
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final create = find.byKey(const Key('media-tag-create-button'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('media-tag-name-field')),
      'Chinese subtitles',
    );
    await tester.enterText(
      find.byKey(const Key('media-tag-include-terms-field')),
      '中文字幕\nCHS',
    );
    await tester.enterText(
      find.byKey(const Key('media-tag-exclude-terms-field')),
      'machine',
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/media-tags',
      statusCode: 201,
      body: <String, dynamic>{
        'id': 7,
        'name': 'Chinese subtitles',
        'include_terms': ['中文字幕', 'CHS'],
        'exclude_terms': ['machine'],
        'enabled': true,
        'media_count': 0,
        'created_at': '2026-10-31T01:02:03Z',
        'updated_at': '2026-10-31T01:02:03Z',
      },
    );
    await tester.tap(find.byKey(const Key('media-tag-rule-save')));
    await tester.pumpAndSettle();

    final request = bundle.adapter.requests.singleWhere(
      (request) => request.method == 'POST' && request.path == '/media-tags',
    );
    expect(request.body, {
      'name': 'Chinese subtitles',
      'include_terms': ['中文字幕', 'CHS'],
      'exclude_terms': ['machine'],
      'enabled': true,
    });
    expect(find.byKey(const Key('media-tag-rule-7')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('tests saved rules with filename and release metadata', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: const <Map<String, dynamic>>[],
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final fileName = find.byKey(const Key('media-tag-preview-file-name'));
    await tester.ensureVisible(fileName);
    await tester.enterText(fileName, 'ABC-001.2160p.mkv');
    await tester.enterText(
      find.byKey(const Key('media-tag-preview-release-title')),
      'ABC-001 4K',
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/media-tags/preview',
      body: <String, dynamic>{
        'matches': [
          {'tag_id': 1, 'name': '4K', 'matched_term': '2160p'},
        ],
      },
    );
    final submit = find.byKey(const Key('media-tag-preview-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('4K'), findsOneWidget);
    expect(find.text('命中词：2160p'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the empty state and validates required rule fields', (
    tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: const <Map<String, dynamic>>[],
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('还没有媒体文件标签'), findsOneWidget);
    final create = find.byKey(const Key('media-tag-create-button'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-tag-rule-save')));
    await tester.pumpAndSettle();

    expect(find.text('请输入标签名称'), findsOneWidget);
    expect(find.text('至少需要一个命中词'), findsOneWidget);
    expect(bundle.adapter.hitCount('POST', '/media-tags'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads a failed list and retries', (tester) async {
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

    expect(find.text('媒体文件标签加载失败'), findsOneWidget);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: const <Map<String, dynamic>>[],
    );
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('还没有媒体文件标签'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes a rule after confirmation', (tester) async {
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

    await tester.tap(find.byKey(const Key('media-tag-delete-9')));
    await tester.pumpAndSettle();
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media-tags/9',
      statusCode: 204,
      body: null,
    );
    await tester.tap(find.byKey(const Key('media-tag-delete-confirm-9')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-tag-rule-9')), findsNothing);
    expect(find.text('还没有媒体文件标签'), findsOneWidget);
    expect(bundle.adapter.hitCount('DELETE', '/media-tags/9'), 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });
}
