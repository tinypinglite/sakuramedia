import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_selection_policy_content.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('renders sections and saves edited policy', (tester) async {
    final harness = await _pumpPolicyContent(tester);
    addTearDown(harness.dispose);

    expect(
      find.byKey(const Key('download-selection-scope-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('download-selection-keyword-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('download-selection-ranking-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('download-selection-preview-section')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppBadge &&
            widget.label == '1' &&
            widget.tone == AppBadgeTone.neutral,
      ),
      findsOneWidget,
    );

    final minSizeField = tester.getRect(
      find.byKey(const Key('download-selection-min-size')),
    );
    final minSizeUnitFinder = find.byKey(
      const Key('download-selection-min-size-unit'),
    );
    final minSizeUnit = tester.getRect(minSizeUnitFinder);
    expect(minSizeField.right - minSizeUnit.right, greaterThanOrEqualTo(11));
    expect(
      tester.widget<Text>(minSizeUnitFinder).style?.color,
      sakuraThemeData.appTextPalette.secondary,
    );

    await tester.enterText(
      find.byKey(const Key('download-selection-min-seeders')),
      '5',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('download-selection-unsaved-badge')),
      findsOneWidget,
    );

    harness.bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/download-selection-policy',
      body: _policyJson(version: 2, minSeeders: 5),
    );
    await tester.tap(find.byKey(const Key('download-selection-save-button')));
    await tester.pumpAndSettle();

    final request = harness.bundle.adapter.requests.lastWhere(
      (request) =>
          request.method == 'PUT' &&
          request.path == '/download-selection-policy',
    );
    expect(request.method, 'PUT');
    expect(request.body['expected_version'], 1);
    expect(request.body['rules']['min_seeders'], 5);
    expect(
      find.byKey(const Key('download-selection-unsaved-badge')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('adds a structured required keyword group', (tester) async {
    final harness = await _pumpPolicyContent(tester);
    addTearDown(harness.dispose);

    final addButton = find.text('添加必选组');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('download-selection-keyword-group-label')),
      '清晰度',
    );
    await tester.enterText(
      find.byKey(const Key('download-selection-keyword-group-terms')),
      '1080p\n2160p\n1080p',
    );
    await tester.tap(
      find.byKey(const Key('download-selection-keyword-group-save')),
    );
    await tester.pumpAndSettle();

    expect(find.text('清晰度'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('2160p'), findsOneWidget);
  });

  testWidgets('previews the current draft and marks the selected candidate', (
    tester,
  ) async {
    final harness = await _pumpPolicyContent(tester);
    addTearDown(harness.dispose);
    _enqueueMovieNumberParse(
      harness.bundle,
      query: 'abp123',
      movieNumber: 'ABP-123',
    );
    harness.bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/download-selection-policy/preview',
      body: <String, dynamic>{
        'draft': true,
        'policy_version': null,
        'raw_candidate_count': 2,
        'system_candidate_count': 2,
        'eligible_candidate_count': 1,
        'policy_filtered_count': 1,
        'rejection_counts': <String, int>{'excluded_term': 1},
        'selected_source_uri': 'magnet:?xt=good',
        'candidates': <Map<String, dynamic>>[
          _candidateJson(
            uri: 'magnet:?xt=good',
            title: 'ABC-001 1080p',
            eligible: true,
            rank: 1,
          ),
          _candidateJson(
            uri: 'magnet:?xt=bad',
            title: 'ABC-001 sample',
            eligible: false,
          ),
        ],
      },
    );

    await tester.enterText(
      find.byKey(const Key('download-selection-preview-movie-number')),
      'abp123',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final parseRequest = harness.bundle.adapter.requests.singleWhere(
      (request) =>
          request.method == 'POST' &&
          request.path == '/movies/search/parse-number',
    );
    expect(parseRequest.body, <String, dynamic>{'query': 'abp123'});
    final previewRequest = harness.bundle.adapter.requests.singleWhere(
      (request) =>
          request.method == 'POST' &&
          request.path == '/download-selection-policy/preview',
    );
    expect(previewRequest.body['movie_number'], 'ABP-123');
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('download-selection-preview-movie-number')),
          )
          .controller
          ?.text,
      'abp123',
    );
    expect(find.text('已识别为 ABP-123'), findsOneWidget);
    expect(
      find.byKey(const Key('download-selection-preview-result')),
      findsOneWidget,
    );
    expect(find.text('将自动选择此资源'), findsOneWidget);
    expect(find.text('ABC-001 1080p'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppPill &&
            widget.label == '系统可用 2' &&
            widget.tone == AppPillTone.neutral,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppPill &&
            widget.label == '符合策略 1' &&
            widget.tone == AppPillTone.primary,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppPill &&
            widget.label == '策略过滤 1' &&
            widget.tone == AppPillTone.warning,
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('ABC-001 sample'));
    await tester.pump();
    expect(find.textContaining('命中排除词 sample'), findsOneWidget);
  });

  testWidgets(
    'restores the preview movie number after the content is rebuilt',
    (tester) async {
      final contentVisible = ValueNotifier<bool>(true);
      addTearDown(contentVisible.dispose);
      final harness = await _pumpPolicyContent(
        tester,
        contentVisibility: contentVisible,
      );
      addTearDown(harness.dispose);
      _enqueueMovieNumberParse(
        harness.bundle,
        query: 'abp123',
        movieNumber: 'ABP-123',
      );
      harness.bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-selection-policy/preview',
        body: <String, dynamic>{
          'draft': true,
          'policy_version': null,
          'raw_candidate_count': 1,
          'system_candidate_count': 1,
          'eligible_candidate_count': 1,
          'policy_filtered_count': 0,
          'rejection_counts': <String, int>{},
          'selected_source_uri': 'magnet:?xt=good',
          'candidates': <Map<String, dynamic>>[
            _candidateJson(
              uri: 'magnet:?xt=good',
              title: 'ABC-001 1080p',
              eligible: true,
              rank: 1,
            ),
          ],
        },
      );

      final movieNumberField = find.byKey(
        const Key('download-selection-preview-movie-number'),
      );
      await tester.enterText(movieNumberField, 'abp123');
      await tester.ensureVisible(
        find.byKey(const Key('download-selection-preview-button')),
      );
      await tester.tap(
        find.byKey(const Key('download-selection-preview-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('download-selection-preview-result')),
        findsOneWidget,
      );

      contentVisible.value = false;
      await tester.pumpAndSettle();
      contentVisible.value = true;
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('download-selection-preview-result')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(movieNumberField).controller?.text,
        'abp123',
      );

      await tester.enterText(movieNumberField, 'DEF-002');
      await tester.pump();
      expect(
        tester.widget<TextFormField>(movieNumberField).controller?.text,
        'DEF-002',
      );
      expect(
        find.byKey(const Key('download-selection-preview-result')),
        findsNothing,
      );
    },
  );

  testWidgets('blocks preview when the movie number cannot be parsed', (
    tester,
  ) async {
    final harness = await _pumpPolicyContent(tester);
    addTearDown(harness.dispose);
    _enqueueMovieNumberParse(harness.bundle, query: 'not-a-number');

    await tester.enterText(
      find.byKey(const Key('download-selection-preview-movie-number')),
      'not-a-number',
    );
    await tester.ensureVisible(
      find.byKey(const Key('download-selection-preview-button')),
    );
    await tester.tap(
      find.byKey(const Key('download-selection-preview-button')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('无法识别番号'), findsOneWidget);
    expect(
      harness.bundle.adapter.requests.where(
        (request) => request.path == '/download-selection-policy/preview',
      ),
      isEmpty,
    );
  });

  testWidgets('blocks preview when movie number parsing fails', (tester) async {
    final harness = await _pumpPolicyContent(tester);
    addTearDown(harness.dispose);
    harness.bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      statusCode: 500,
      body: const <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'movie_number_parse_failed',
          'message': '番号解析服务暂不可用',
        },
      },
    );

    await tester.enterText(
      find.byKey(const Key('download-selection-preview-movie-number')),
      'abp123',
    );
    await tester.ensureVisible(
      find.byKey(const Key('download-selection-preview-button')),
    );
    await tester.tap(
      find.byKey(const Key('download-selection-preview-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('番号解析服务暂不可用'), findsOneWidget);
    expect(
      harness.bundle.adapter.requests.where(
        (request) => request.path == '/download-selection-policy/preview',
      ),
      isEmpty,
    );
  });

  testWidgets('ignores a movie number parse result after the input changes', (
    tester,
  ) async {
    final harness = await _pumpPolicyContent(tester);
    addTearDown(harness.dispose);
    final parseResponse = Completer<ResponseBody>();
    harness.bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/movies/search/parse-number',
      responder: (_, _) => parseResponse.future,
    );

    final movieNumberField = find.byKey(
      const Key('download-selection-preview-movie-number'),
    );
    await tester.enterText(movieNumberField, 'abp123');
    await tester.ensureVisible(
      find.byKey(const Key('download-selection-preview-button')),
    );
    await tester.tap(
      find.byKey(const Key('download-selection-preview-button')),
    );
    await tester.pump();
    await tester.enterText(movieNumberField, 'def456');
    parseResponse.complete(
      ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'query': 'abp123',
          'parsed': true,
          'movie_number': 'ABP-123',
          'reason': null,
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      harness.bundle.adapter.requests.where(
        (request) => request.path == '/download-selection-policy/preview',
      ),
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(movieNumberField).controller?.text,
      'def456',
    );
  });

  testWidgets('does not flag indexers while indexer settings are loading', (
    tester,
  ) async {
    final harness = await _pumpPolicyContent(
      tester,
      policy: _policyJson(indexerNames: const <String>['retired-indexer']),
      indexerResponse: _IndexerSettingsResponse.loading,
    );
    addTearDown(harness.dispose);

    expect(find.textContaining('以下索引器已失效'), findsNothing);
  });

  testWidgets('does not flag indexers when indexer settings fail to load', (
    tester,
  ) async {
    final harness = await _pumpPolicyContent(
      tester,
      policy: _policyJson(indexerNames: const <String>['retired-indexer']),
      indexerResponse: _IndexerSettingsResponse.error,
    );
    addTearDown(harness.dispose);

    expect(find.textContaining('以下索引器已失效'), findsNothing);
  });

  testWidgets('version conflict keeps draft and offers reload', (tester) async {
    final harness = await _pumpPolicyContent(tester);
    addTearDown(harness.dispose);
    await tester.enterText(
      find.byKey(const Key('download-selection-min-seeders')),
      '9',
    );
    await tester.pump();
    harness.bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/download-selection-policy',
      statusCode: 409,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'download_selection_policy_version_conflict',
          'message': '策略已在其他端更新',
        },
      },
    );

    await tester.tap(find.byKey(const Key('download-selection-save-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('download-selection-version-conflict')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('download-selection-unsaved-badge')),
      findsOneWidget,
    );
  });

  testWidgets('mobile narrow layout keeps the sticky save footer reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 760);
    addTearDown(tester.view.reset);
    final harness = await _pumpPolicyContent(tester, mobile: true);
    addTearDown(harness.dispose);

    expect(
      find.byKey(const Key('download-selection-save-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile policy rows use a 44px action menu', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 760);
    addTearDown(tester.view.reset);
    final harness = await _pumpPolicyContent(
      tester,
      mobile: true,
      policy: _policyJson(
        requiredGroups: const <Map<String, dynamic>>[
          <String, dynamic>{
            'label': '清晰度',
            'terms': <String>['1080p'],
          },
        ],
        ranking: const <String>['size_desc', 'seeders_desc'],
      ),
    );
    addTearDown(harness.dispose);

    final groupActions = find.byKey(
      const Key('download-selection-group-more-0'),
    );
    final rankingActions = find.byKey(
      const Key('download-selection-ranking-more-0'),
    );
    expect(tester.getSize(groupActions), const Size(44, 44));
    expect(tester.getSize(rankingActions), const Size(44, 44));

    await tester.ensureVisible(groupActions);
    await tester.tap(groupActions);
    await tester.pumpAndSettle();
    expect(find.text('上移'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('清晰度'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

enum _IndexerSettingsResponse { success, loading, error }

Future<_PolicyHarness> _pumpPolicyContent(
  WidgetTester tester, {
  bool mobile = false,
  Map<String, dynamic>? policy,
  _IndexerSettingsResponse indexerResponse = _IndexerSettingsResponse.success,
  ValueNotifier<bool>? contentVisibility,
}) async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
  );
  final bundle = await createTestApiBundle(sessionStore);
  switch (indexerResponse) {
    case _IndexerSettingsResponse.success:
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/indexer-settings',
        body: const <String, dynamic>{
          'indexers': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'name': 'mteam',
              'url': 'https://indexer.example.com',
              'kind': 'pt',
              'api_key': null,
              'download_clients': <Map<String, dynamic>>[
                <String, dynamic>{'id': 1, 'name': 'qb'},
              ],
            },
          ],
        },
      );
    case _IndexerSettingsResponse.loading:
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/indexer-settings',
        responder: (_, _) => Completer<ResponseBody>().future,
      );
    case _IndexerSettingsResponse.error:
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/indexer-settings',
        statusCode: 500,
        body: const <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'indexer_settings_failed',
            'message': '索引器设置加载失败',
          },
        },
      );
  }
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-selection-policy',
    body: policy ?? _policyJson(),
  );
  Widget content = DownloadSelectionPolicyContent(mobile: mobile);
  if (contentVisibility != null) {
    content = ValueListenableBuilder<bool>(
      valueListenable: contentVisibility,
      builder: (_, visible, _) => visible
          ? DownloadSelectionPolicyContent(mobile: mobile)
          : const SizedBox.expand(),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: AppPlatformScope(
        platform: mobile ? AppPlatform.mobile : AppPlatform.desktop,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: mobile ? sakuraMobileThemeData : sakuraThemeData,
          home: OKToast(
            child: Scaffold(body: SizedBox.expand(child: content)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _PolicyHarness(sessionStore: sessionStore, bundle: bundle);
}

class _PolicyHarness {
  const _PolicyHarness({required this.sessionStore, required this.bundle});

  final SessionStore sessionStore;
  final TestApiBundle bundle;

  void dispose() {
    bundle.dispose();
    sessionStore.dispose();
  }
}

Map<String, dynamic> _policyJson({
  int version = 1,
  int minSeeders = 1,
  List<String> indexerNames = const <String>[],
  List<Map<String, dynamic>> requiredGroups = const <Map<String, dynamic>>[],
  List<String> ranking = const <String>['size_desc'],
}) {
  return <String, dynamic>{
    'version': version,
    'created_at': '2026-10-29T12:00:00Z',
    'updated_at': '2026-10-29T12:00:00Z',
    'rules': <String, dynamic>{
      'schema_version': 1,
      'indexer_kinds': <String>[],
      'indexer_names': indexerNames,
      'min_size_bytes': 1024 * 1024 * 1024,
      'max_size_bytes': 40 * 1024 * 1024 * 1024,
      'min_seeders': minSeeders,
      'max_age_days': null,
      'match_title': true,
      'match_description': true,
      'required_groups': requiredGroups,
      'excluded_terms': <String>[],
      'preferred_groups': <Map<String, dynamic>>[],
      'ranking': ranking,
      'indexer_priority_names': <String>[],
    },
  };
}

void _enqueueMovieNumberParse(
  TestApiBundle bundle, {
  required String query,
  String? movieNumber,
}) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/movies/search/parse-number',
    body: <String, dynamic>{
      'query': query,
      'parsed': movieNumber != null,
      'movie_number': movieNumber,
      'reason': movieNumber == null ? 'movie_number_not_found' : null,
    },
  );
}

Map<String, dynamic> _candidateJson({
  required String uri,
  required String title,
  required bool eligible,
  int? rank,
}) {
  return <String, dynamic>{
    'source_uri': uri,
    'indexer_name': 'mteam',
    'indexer_kind': 'pt',
    'resolved_client_id': 1,
    'resolved_client_name': 'qb',
    'download_clients': <Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'name': 'qb'},
    ],
    'movie_number': 'ABC-001',
    'title': title,
    'size_bytes': 5368709120,
    'seeders': 10,
    'selection_evaluation': <String, dynamic>{
      'eligible': eligible,
      'rejection_reasons': eligible
          ? <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[
              <String, dynamic>{
                'code': 'excluded_term',
                'message': '命中排除词 sample',
                'term': 'sample',
              },
            ],
      'matched_required_group_labels': <String>[],
      'matched_preferred_group_label': null,
      'preference_rank': null,
      'selection_rank': rank,
      'within_attempt_limit': rank != null && rank <= 5,
    },
  };
}
