import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/mobile_llm_settings_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';

import '../../../support/test_api_bundle.dart';

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

    expect(find.byKey(const Key('mobile-settings-llm')), findsOneWidget);
    expect(find.byKey(const Key('mobile-llm-overview-card')), findsOneWidget);
    expect(find.byKey(const Key('mobile-llm-form-card')), findsOneWidget);
    expect(find.byKey(const Key('mobile-llm-test-button')), findsOneWidget);
    expect(find.byKey(const Key('mobile-llm-save-button')), findsOneWidget);
    expect(find.text('可保存'), findsOneWidget);
  });

  testWidgets('shows fatal error and retries successfully', (
    WidgetTester tester,
  ) async {
    _bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/movie-desc-translation-settings',
      responder: (_, __) async {
        return ResponseBody.fromString(
          jsonEncode({
            'error': <String, dynamic>{
              'code': 'server_error',
              'message': 'LLM 配置加载失败，请稍后重试。',
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

    expect(find.byKey(const Key('mobile-llm-error-state')), findsOneWidget);
    expect(find.text('LLM 配置加载失败，请稍后重试。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-llm-retry-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-llm-overview-card')), findsOneWidget);
  });

  testWidgets('saves current draft and applies returned state', (
    WidgetTester tester,
  ) async {
    _enqueueSettings(_bundle);
    _bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/movie-desc-translation-settings',
      body: _buildSettingsJson(
        enabled: true,
        baseUrl: 'http://127.0.0.1:8000',
        apiKey: 'secret-token',
        model: 'gpt-4.1-mini',
        timeoutSeconds: 120,
        connectTimeoutSeconds: 5,
      ),
    );

    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('mobile-llm-enabled-button')));
    await tester.enterText(
      find.byKey(const Key('mobile-llm-base-url-field')),
      'http://127.0.0.1:8000',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-llm-api-key-field')),
      'secret-token',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-llm-model-field')),
      'gpt-4.1-mini',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-llm-timeout-field')),
      '120',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-llm-connect-timeout-field')),
      '5',
    );
    await tester.tap(find.byKey(const Key('mobile-llm-save-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    final patchRequest = _bundle.adapter.requests.firstWhere(
      (request) =>
          request.method == 'PATCH' &&
          request.path == '/movie-desc-translation-settings',
    );
    expect(patchRequest.body['enabled'], isTrue);
    expect(patchRequest.body['model'], 'gpt-4.1-mini');
    expect(patchRequest.body['timeout_seconds'], 120.0);
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
      find.byKey(const Key('mobile-llm-base-url-field')),
      'http://127.0.0.1:9000',
    );
    await tester.enterText(
      find.byKey(const Key('mobile-llm-model-field')),
      'gpt-4.1-mini',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('mobile-llm-test-button')));
    await tester.tap(find.byKey(const Key('mobile-llm-test-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      _bundle.adapter.hitCount('POST', '/movie-desc-translation-settings/test'),
      1,
    );
    expect(
      _bundle.adapter.hitCount('PATCH', '/movie-desc-translation-settings'),
      0,
    );
    expect(find.text('测试通过'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'validation blocks invalid url empty model and non-positive timeouts',
    (WidgetTester tester) async {
      _enqueueSettings(_bundle);

      await _pumpPage(tester);

      await tester.enterText(
        find.byKey(const Key('mobile-llm-base-url-field')),
        'not-url',
      );
      await tester.enterText(
        find.byKey(const Key('mobile-llm-model-field')),
        '',
      );
      await tester.enterText(
        find.byKey(const Key('mobile-llm-timeout-field')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('mobile-llm-connect-timeout-field')),
        '-1',
      );
      await tester.tap(find.byKey(const Key('mobile-llm-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('请输入合法的 http/https 地址'), findsOneWidget);
      expect(find.text('请输入模型名称'), findsOneWidget);
      expect(find.text('请求超时必须是正数'), findsOneWidget);
      expect(find.text('连接超时必须是正数'), findsOneWidget);
      expect(
        _bundle.adapter.hitCount('PATCH', '/movie-desc-translation-settings'),
        0,
      );
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
    expect(find.text('LLM 配置加载失败，请稍后重试。'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('mobile-llm-test-button')));
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
    MultiProvider(
      providers: [
        Provider<MovieDescTranslationSettingsApi>.value(
          value: api ?? _bundle.movieDescTranslationSettingsApi,
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobileLlmSettingsPage()),
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
    path: '/movie-desc-translation-settings',
    body: _buildSettingsJson(
      enabled: enabled,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      timeoutSeconds: timeoutSeconds,
      connectTimeoutSeconds: connectTimeoutSeconds,
    ),
  );
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
