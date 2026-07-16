import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/api/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/movie_desc_translation_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/llm_settings_page.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/llm_settings_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/llm_settings_copy.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pull_to_refresh.dart';

import '../../../../support/test_api_bundle.dart';

late SessionStore _sessionStore;
late TestApiBundle _bundle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _sessionStore = await _buildLoggedInSessionStore();
    _bundle = await createTestApiBundle(_sessionStore);
  });

  tearDown(() {
    _bundle.dispose();
  });

  testWidgets('loads overview card, form card and bottom actions', (
    WidgetTester tester,
  ) async {
    _enqueueSettings(_bundle);

    await _pumpPage(tester);

    expect(find.byKey(const Key('llm-settings-page')), findsOneWidget);
    expect(find.byKey(const Key('llm-overview-card')), findsOneWidget);
    expect(find.byKey(const Key('llm-form-card')), findsOneWidget);
    expect(find.byKey(const Key('llm-test-button')), findsOneWidget);
    expect(find.byKey(const Key('llm-save-button')), findsOneWidget);
    expect(find.text('启用'), findsOneWidget);
    expect(find.text('停用'), findsOneWidget);
    expect(find.text('可保存'), findsOneWidget);
    expect(find.text(LlmSettingsCopy.sharedUsageDescription), findsOneWidget);
    expect(
      find.text(LlmSettingsCopy.sharedEndpointDescription),
      findsOneWidget,
    );
    expect(find.text(LlmSettingsCopy.baseUrlHelperText), findsOneWidget);
    expect(find.text(LlmSettingsCopy.modelHintText), findsOneWidget);
    expect(find.text(LlmSettingsCopy.modelRecommendationText), findsOneWidget);
  });

  testWidgets('shows llm example config hints when draft is empty', (
    WidgetTester tester,
  ) async {
    _enqueueSettings(_bundle, baseUrl: '', model: '');

    await _pumpPage(tester);

    expect(find.text(LlmSettingsCopy.baseUrlHelperText), findsOneWidget);
    expect(find.text(LlmSettingsCopy.modelHintText), findsOneWidget);
    expect(find.text(LlmSettingsCopy.modelRecommendationText), findsOneWidget);
  });

  testWidgets('shows fatal error and retries successfully', (
    WidgetTester tester,
  ) async {
    _bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/config',
      responder: (_, __) async {
        return ResponseBody.fromString(
          jsonEncode({
            'error': <String, dynamic>{
              'code': 'server_error',
              'message': 'LLM 配置加载失败',
            },
          }),
          500,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );
    _enqueueSettings(_bundle);

    await _pumpPage(tester);

    expect(find.byKey(const Key('llm-error-state')), findsOneWidget);
    expect(find.text('LLM 配置加载失败'), findsWidgets);

    await tester.tap(find.byKey(const Key('llm-retry-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('llm-overview-card')), findsOneWidget);
  });

  testWidgets('saves current draft and applies returned state', (
    WidgetTester tester,
  ) async {
    _enqueueSettings(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/config',
      body: _buildConfigPatchResponseJson(
        section: _buildSettingsJson(
          enabled: true,
          baseUrl: 'http://127.0.0.1:8000',
          apiKey: 'secret-token',
          model: 'gpt-4.1-mini',
          timeoutSeconds: 120,
          connectTimeoutSeconds: 5,
        ),
      ),
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('llm-enabled-button')));
    await tester.enterText(
      find.byKey(const Key('llm-base-url-field')),
      'http://127.0.0.1:8000',
    );
    await tester.enterText(
      find.byKey(const Key('llm-api-key-field')),
      'secret-token',
    );
    await tester.enterText(
      find.byKey(const Key('llm-model-field')),
      'gpt-4.1-mini',
    );
    await tester.enterText(find.byKey(const Key('llm-timeout-field')), '120');
    await tester.enterText(
      find.byKey(const Key('llm-connect-timeout-field')),
      '5',
    );
    await tester.tap(find.byKey(const Key('llm-save-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) => request.method == 'PATCH' && request.path == '/config',
    );
    final patchSection =
        patchRequest.body['movie_info_translation'] as Map<String, dynamic>;
    expect(patchSection['enabled'], isTrue);
    expect(patchSection['model'], 'gpt-4.1-mini');
    expect(patchSection['timeout_seconds'], 120.0);
    expect(find.text('已启用'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('tests current draft without triggering save', (
    WidgetTester tester,
  ) async {
    _enqueueSettings(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movie-desc-translation-settings/test',
      body: const <String, dynamic>{'ok': true},
    );

    await _pumpPage(tester);

    await tester.enterText(
      find.byKey(const Key('llm-base-url-field')),
      'http://127.0.0.1:9000',
    );
    await tester.enterText(
      find.byKey(const Key('llm-model-field')),
      'gpt-4.1-mini',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('llm-test-button')));
    await tester.tap(find.byKey(const Key('llm-test-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      _bundle.adapter.hitCount('POST', '/movie-desc-translation-settings/test'),
      1,
    );
    expect(_bundle.adapter.hitCount('PATCH', '/config'), 0);
    expect(find.text('测试通过'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'validation blocks invalid url empty model and non-positive timeouts',
    (WidgetTester tester) async {
      _enqueueSettings(_bundle);

      await _pumpPage(tester);

      await tester.enterText(
        find.byKey(const Key('llm-base-url-field')),
        'not-url',
      );
      await tester.enterText(find.byKey(const Key('llm-model-field')), '');
      await tester.enterText(find.byKey(const Key('llm-timeout-field')), '0');
      await tester.enterText(
        find.byKey(const Key('llm-connect-timeout-field')),
        '-1',
      );
      await tester.tap(find.byKey(const Key('llm-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('请输入合法的 http/https 地址'), findsOneWidget);
      expect(find.text('请输入模型名称'), findsOneWidget);
      expect(find.text('请求超时必须是正数'), findsOneWidget);
      expect(find.text('连接超时必须是正数'), findsOneWidget);
      expect(_bundle.adapter.hitCount('PATCH', '/config'), 0);
    },
  );

  testWidgets('refresh failure keeps current content and shows toast', (
    WidgetTester tester,
  ) async {
    final api = _RefreshFailureMovieDescTranslationSettingsApi(
      apiClient: _bundle.apiClient,
      initialSettings: MovieDescTranslationSettingsDto.fromJson(
        _buildSettingsJson(
          enabled: true,
          baseUrl: 'http://llm.internal:8000',
          model: 'gpt-4o-mini',
        ),
      ),
    );

    await _pumpPage(tester, api: api);

    expect(find.text('http://llm.internal:8000'), findsOneWidget);

    final refresh = tester.widget<AppPullToRefresh>(
      find.byType(AppPullToRefresh),
    );
    await refresh.onRefresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('http://llm.internal:8000'), findsOneWidget);
    expect(find.text('LLM 配置加载失败'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('failed test updates recent test state', (
    WidgetTester tester,
  ) async {
    _enqueueSettings(_bundle);
    _bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/movie-desc-translation-settings/test',
      responder: (_, __) async {
        return ResponseBody.fromString(
          jsonEncode({
            'error': <String, dynamic>{
              'code': 'movie_desc_translation_failed',
              'message': '测试失败',
            },
          }),
          500,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('llm-test-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('测试失败'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  MovieDescTranslationSettingsApi? api,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        llmSettingsApiProvider.overrideWithValue(
          api ?? _bundle.movieDescTranslationSettingsApi,
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: LlmSettingsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _enqueueSettings(
  TestApiBundle bundle, {
  bool enabled = false,
  String baseUrl = 'http://llm.internal:8000',
  String apiKey = '',
  String model = 'gpt-4o-mini',
  double timeoutSeconds = 300,
  double connectTimeoutSeconds = 3,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/config',
    body: <String, dynamic>{
      'values': <String, dynamic>{
        'movie_info_translation': _buildSettingsJson(
          enabled: enabled,
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: model,
          timeoutSeconds: timeoutSeconds,
          connectTimeoutSeconds: connectTimeoutSeconds,
        ),
      },
      'effects': <String, dynamic>{'movie_info_translation': 'hot'},
    },
  );
}

Map<String, dynamic> _buildConfigPatchResponseJson({
  required Map<String, dynamic> section,
}) {
  return <String, dynamic>{
    'values': <String, dynamic>{'movie_info_translation': section},
    'applied': <String>['movie_info_translation'],
    'pending_restart': <dynamic>[],
  };
}

Map<String, dynamic> _buildSettingsJson({
  bool enabled = false,
  String baseUrl = 'http://llm.internal:8000',
  String apiKey = '',
  String model = 'gpt-4o-mini',
  double timeoutSeconds = 300,
  double connectTimeoutSeconds = 3,
}) {
  return <String, dynamic>{
    'enabled': enabled,
    'base_url': baseUrl,
    'api_key': apiKey,
    'model': model,
    'timeout_seconds': timeoutSeconds,
    'connect_timeout_seconds': connectTimeoutSeconds,
  };
}

Future<SessionStore> _buildLoggedInSessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'mobile-access-token',
    refreshToken: 'mobile-refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}

class _RefreshFailureMovieDescTranslationSettingsApi
    extends MovieDescTranslationSettingsApi {
  _RefreshFailureMovieDescTranslationSettingsApi({
    required super.apiClient,
    required this.initialSettings,
  });

  final MovieDescTranslationSettingsDto initialSettings;
  int _requestCount = 0;

  @override
  Future<MovieDescTranslationSettingsDto> getSettings() async {
    _requestCount += 1;
    if (_requestCount == 1) {
      return initialSettings;
    }
    throw Exception('refresh failed');
  }
}
