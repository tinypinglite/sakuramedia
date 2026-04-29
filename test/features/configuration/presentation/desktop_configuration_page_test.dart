import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_state.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_api.dart';
import 'package:sakuramedia/features/configuration/data/download_clients_api.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_api.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_api.dart';
import 'package:sakuramedia/features/configuration/presentation/desktop_configuration_page.dart';
import 'package:sakuramedia/features/configuration/presentation/llm_settings_copy.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  group('DesktopConfigurationPage', () {
    late SessionStore sessionStore;
    late TestApiBundle bundle;

    setUp(() async {
      sessionStore = await _buildLoggedInSessionStore();
      bundle = await createTestApiBundle(sessionStore);
    });

    tearDown(() {
      bundle.dispose();
    });

    testWidgets('renders configuration tabs including playlists tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );

      final tabs = tester.widgetList<Tab>(find.byType(Tab)).toList();
      expect(tabs.map((tab) => tab.text).toList(), [
        '数据源',
        '媒体库',
        '合集特征',
        'LLM 配置',
        '账号安全',
        '下载器',
        '索引器',
        '播放列表',
      ]);
    });

    testWidgets('loads metadata provider license tab by default', (
      WidgetTester tester,
    ) async {
      _enqueueMetadataProviderLicenseStatus(bundle, active: false);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );

      expect(
        bundle.adapter.hitCount('GET', '/metadata-provider-license/status'),
        1,
      );
      expect(
        find.byKey(const Key('configuration-license-card')),
        findsOneWidget,
      );
      expect(find.text('数据源授权'), findsOneWidget);
      expect(find.text('数据源'), findsOneWidget);
      expect(find.text('未激活'), findsWidgets);
      expect(find.text('授权有效期: 未提供'), findsOneWidget);
      expect(find.text('授权中心: 未检测'), findsOneWidget);
      expect(find.text('过期时间: 未提供'), findsNothing);
      expect(find.text('续租建议: 未提供'), findsNothing);
      expect(find.text('实例 ID: inst_test'), findsNothing);
    });

    testWidgets('aligns metadata provider license actions with input', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueMetadataProviderLicenseStatus(bundle, active: false);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );
      await tester.tap(find.byKey(const Key('configuration-tab-license')));
      await tester.pumpAndSettle();

      final inputCenterY =
          tester
              .getCenter(
                find.byKey(const Key('configuration-license-activation-field')),
              )
              .dy;
      final refreshCenterY =
          tester
              .getCenter(
                find.byKey(const Key('configuration-license-refresh-button')),
              )
              .dy;
      final activateCenterY =
          tester
              .getCenter(
                find.byKey(const Key('configuration-license-activate-button')),
              )
              .dy;

      expect(refreshCenterY, closeTo(inputCenterY, 1));
      expect(activateCenterY, closeTo(inputCenterY, 1));
    });

    testWidgets('refreshes metadata provider license status', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueMetadataProviderLicenseStatus(bundle, active: false);
      _enqueueMetadataProviderLicenseStatus(bundle, active: true);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );
      await tester.tap(find.byKey(const Key('configuration-tab-license')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('configuration-license-refresh-button')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount('GET', '/metadata-provider-license/status'),
        2,
      );
      expect(find.text('已激活'), findsWidgets);
    });

    testWidgets('shows pending sync when business license is still valid', (
      WidgetTester tester,
    ) async {
      _enqueueMetadataProviderLicenseStatus(
        bundle,
        active: false,
        errorCode: 'license_unavailable',
        message: 'License state cannot be validated',
        licenseValidUntil: 4102444800,
      );

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );

      expect(find.text('授权待同步'), findsWidgets);
      expect(find.text('你的授权仍在有效期内，但当前设备需要重新同步授权后才能使用外部数据源。'), findsOneWidget);
    });

    testWidgets('syncs metadata provider authorization', (
      WidgetTester tester,
    ) async {
      _enqueueMetadataProviderLicenseStatus(
        bundle,
        active: false,
        errorCode: 'license_unavailable',
        message: 'License state cannot be validated',
        licenseValidUntil: 4102444800,
      );
      _enqueueMetadataProviderLicenseRenew(bundle);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );
      await tester.tap(
        find.byKey(const Key('configuration-license-sync-button')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount('POST', '/metadata-provider-license/renew'),
        1,
      );
      expect(find.text('已激活'), findsWidgets);
      expect(find.text('授权状态已同步'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('tests metadata provider license center connectivity', (
      WidgetTester tester,
    ) async {
      _enqueueMetadataProviderLicenseStatus(bundle, active: false);
      _enqueueMetadataProviderLicenseConnectivity(bundle, ok: true);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );
      await tester.tap(
        find.byKey(const Key('configuration-license-connectivity-button')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount(
          'GET',
          '/metadata-provider-license/connectivity-test',
        ),
        1,
      );
      expect(find.text('授权中心: 连接正常'), findsOneWidget);
      expect(find.text('授权中心连接正常'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('keeps metadata provider diagnostics collapsed by default', (
      WidgetTester tester,
    ) async {
      _enqueueMetadataProviderLicenseStatus(bundle, active: false);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );

      expect(find.text('诊断信息'), findsOneWidget);
      expect(find.text('实例 ID: inst_test'), findsNothing);

      await tester.tap(
        find.byKey(const Key('configuration-license-diagnostics')),
      );
      await tester.pumpAndSettle();

      expect(find.text('实例 ID: inst_test'), findsOneWidget);
      expect(find.text('错误码: license_required'), findsOneWidget);
    });

    testWidgets('activates metadata provider license', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueMetadataProviderLicenseStatus(bundle, active: false);
      _enqueueMetadataProviderLicenseActivate(bundle);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );
      await tester.tap(find.byKey(const Key('configuration-tab-license')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('configuration-license-activation-field')),
        'SMB-SUPER-SECRET',
      );
      await tester.tap(
        find.byKey(const Key('configuration-license-activate-button')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'POST' &&
            request.path == '/metadata-provider-license/activate',
      );
      expect(request.body['activation_code'], 'SMB-SUPER-SECRET');
      expect(find.text('已激活'), findsWidgets);
      expect(find.text('授权已激活'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('configuration-license-activation-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('validates metadata provider license activation code', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueMetadataProviderLicenseStatus(bundle, active: false);

      await _pumpPage(
        tester,
        bundle,
        sessionStore: sessionStore,
        enqueueDefaultLicenseStatus: false,
      );
      await tester.tap(find.byKey(const Key('configuration-tab-license')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('configuration-license-activate-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('请输入激活码'), findsOneWidget);
      expect(
        bundle.adapter.hitCount('POST', '/metadata-provider-license/activate'),
        0,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('does not expose activation code when activation fails', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueMetadataProviderLicenseStatus(bundle, active: false);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/metadata-provider-license/activate',
        statusCode: 403,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'activation_code_invalid',
            'message': 'Activation code is invalid',
            'details': <String, dynamic>{
              'license_error_code': 'activation_code_invalid',
            },
          },
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-license')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('configuration-license-activation-field')),
        'SMB-SUPER-SECRET',
      );
      await tester.tap(
        find.byKey(const Key('configuration-license-activate-button')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Activation code is invalid'), findsOneWidget);
      expect(find.text('SMB-SUPER-SECRET'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('loads download clients lazily when switching tabs', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, libraries: const []);
      _enqueueDownloadClientsList(bundle, clients: const []);
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      expect(bundle.adapter.hitCount('GET', '/download-clients'), 0);
      expect(bundle.adapter.hitCount('GET', '/media-libraries'), 0);
      expect(bundle.adapter.hitCount('GET', '/collection-number-features'), 0);
      expect(
        bundle.adapter.hitCount('GET', '/movie-desc-translation-settings'),
        0,
      );
      expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 0);
      expect(bundle.adapter.hitCount('GET', '/playlists'), 0);
      expect(
        bundle.adapter.hitCount('GET', '/metadata-provider-license/status'),
        1,
      );
      expect(find.text('还没有媒体库'), findsNothing);

      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/download-clients'), 1);
      expect(bundle.adapter.hitCount('GET', '/media-libraries'), 1);
      expect(find.text('还没有下载器配置'), findsOneWidget);
    });

    testWidgets('loads collection number features lazily', (
      WidgetTester tester,
    ) async {
      _enqueueCollectionNumberFeatures(bundle, features: const ['FC2', 'OFJE']);
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      expect(bundle.adapter.hitCount('GET', '/collection-number-features'), 0);
      await tester.tap(
        find.byKey(const Key('configuration-tab-collection-features')),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('configuration-collection-features-field')),
      );
      expect(field.controller?.text, 'FC2\nOFJE');
      expect(bundle.adapter.hitCount('GET', '/collection-number-features'), 1);
    });

    testWidgets('loads llm settings section lazily', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      expect(
        bundle.adapter.hitCount('GET', '/movie-desc-translation-settings'),
        0,
      );
      await tester.tap(find.byKey(const Key('configuration-tab-llm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('configuration-llm-card')), findsOneWidget);
      expect(find.text('LLM 配置'), findsWidgets);
      expect(
        find.byKey(const Key('configuration-llm-base-url-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuration-llm-test-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuration-llm-save-button')),
        findsOneWidget,
      );
      expect(find.text('可保存'), findsOneWidget);
      expect(find.text(LlmSettingsCopy.sharedUsageDescription), findsOneWidget);
      expect(
        find.text(LlmSettingsCopy.sharedEndpointDescription),
        findsOneWidget,
      );
      expect(
        bundle.adapter.hitCount('GET', '/movie-desc-translation-settings'),
        1,
      );
      expect(find.text(LlmSettingsCopy.baseUrlHelperText), findsOneWidget);
      expect(find.text(LlmSettingsCopy.modelHintText), findsOneWidget);
    });

    testWidgets('shows llm example config hints when draft is empty', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, includeLlmSettings: false);
      _enqueueMovieDescTranslationSettings(bundle, baseUrl: '', model: '');

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(tester, const Key('configuration-tab-llm'));

      expect(find.text(LlmSettingsCopy.baseUrlHelperText), findsOneWidget);
      expect(find.text(LlmSettingsCopy.modelHintText), findsOneWidget);
    });

    testWidgets('saves llm settings and applies returned state', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/movie-desc-translation-settings',
        body: _buildMovieDescTranslationSettingsJson(
          enabled: true,
          baseUrl: 'http://127.0.0.1:8000',
          apiKey: 'secret-token',
          model: 'gpt-4.1-mini',
          timeoutSeconds: 120,
          connectTimeoutSeconds: 5,
        ),
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(tester, const Key('configuration-tab-llm'));

      await tester.ensureVisible(
        find.byKey(const Key('configuration-llm-enabled-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-llm-enabled-button')),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-base-url-field')),
        'http://127.0.0.1:8000',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-api-key-field')),
        'secret-token',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-model-field')),
        'gpt-4.1-mini',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-timeout-field')),
        '120',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-connect-timeout-field')),
        '5',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-llm-save-button')),
      );
      await tester.tap(find.byKey(const Key('configuration-llm-save-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' &&
            request.path == '/movie-desc-translation-settings',
      );
      expect(patchRequest.body['enabled'], isTrue);
      expect(patchRequest.body['base_url'], 'http://127.0.0.1:8000');
      expect(patchRequest.body['model'], 'gpt-4.1-mini');
      expect(patchRequest.body['timeout_seconds'], 120.0);
      expect(find.text('已启用'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('tests llm draft without triggering save', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/movie-desc-translation-settings/test',
        body: const <String, dynamic>{'ok': true},
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(tester, const Key('configuration-tab-llm'));

      await tester.enterText(
        find.byKey(const Key('configuration-llm-base-url-field')),
        'http://127.0.0.1:9000',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-model-field')),
        'gpt-4.1-mini',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-llm-test-button')),
      );
      await tester.tap(find.byKey(const Key('configuration-llm-test-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        bundle.adapter.hitCount(
          'POST',
          '/movie-desc-translation-settings/test',
        ),
        1,
      );
      expect(
        bundle.adapter.hitCount('PATCH', '/movie-desc-translation-settings'),
        0,
      );
      expect(find.text('测试通过'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('validates llm fields before save', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(tester, const Key('configuration-tab-llm'));

      await tester.enterText(
        find.byKey(const Key('configuration-llm-base-url-field')),
        'not-url',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-model-field')),
        '',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-timeout-field')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-connect-timeout-field')),
        '-1',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-llm-save-button')),
      );
      await tester.tap(find.byKey(const Key('configuration-llm-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('请输入合法的 http/https 地址'), findsOneWidget);
      expect(find.text('请输入模型名称'), findsOneWidget);
      expect(find.text('请求超时必须是正数'), findsOneWidget);
      expect(find.text('连接超时必须是正数'), findsOneWidget);
      expect(
        bundle.adapter.hitCount('PATCH', '/movie-desc-translation-settings'),
        0,
      );
    });

    testWidgets('failed llm test updates recent test state', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueResponder(
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

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(tester, const Key('configuration-tab-llm'));

      await tester.ensureVisible(
        find.byKey(const Key('configuration-llm-test-button')),
      );
      await tester.tap(find.byKey(const Key('configuration-llm-test-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('测试失败'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows llm error state and retries successfully', (
      WidgetTester tester,
    ) async {
      bundle.adapter.enqueueResponder(
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
      _enqueueMediaLibraries(bundle, includeLlmSettings: false);
      _enqueueMovieDescTranslationSettings(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(tester, const Key('configuration-tab-llm'));

      expect(
        find.byKey(const Key('configuration-llm-error-state')),
        findsOneWidget,
      );
      expect(find.text('LLM 配置加载失败，请稍后重试。'), findsOneWidget);

      await tester.tap(find.byKey(const Key('configuration-llm-retry-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('configuration-llm-card')), findsOneWidget);
      expect(
        find.byKey(const Key('configuration-llm-save-button')),
        findsOneWidget,
      );
    });

    testWidgets('keeps llm draft when saving fails', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueResponder(
        method: 'PATCH',
        path: '/movie-desc-translation-settings',
        responder: (_, __) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': <String, dynamic>{
                'code': 'invalid_movie_desc_translation_base_url',
                'message': 'Base URL 不合法',
              },
            }),
            422,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(tester, const Key('configuration-tab-llm'));

      await tester.enterText(
        find.byKey(const Key('configuration-llm-base-url-field')),
        'http://127.0.0.1:9000',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-llm-model-field')),
        'gpt-4.1-mini',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-llm-save-button')),
      );
      await tester.tap(find.byKey(const Key('configuration-llm-save-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('configuration-llm-base-url-field')),
      );
      expect(field.controller?.text, 'http://127.0.0.1:9000');
      expect(find.text('Base URL 不合法'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'collection feature action controls are right aligned and fixed width',
      (WidgetTester tester) async {
        _enqueueCollectionNumberFeatures(bundle, features: const ['FC2']);
        _enqueueMediaLibraries(bundle);

        await _pumpPage(tester, bundle, sessionStore: sessionStore);
        await _openConfigurationTab(
          tester,
          const Key('configuration-tab-collection-features'),
        );
        await tester.ensureVisible(
          find.byKey(
            const Key('configuration-collection-features-save-button'),
          ),
        );
        await tester.pumpAndSettle();

        final selectRect = tester.getRect(
          find.byKey(const Key('configuration-collection-apply-now-field')),
        );
        final buttonRect = tester.getRect(
          find.byKey(
            const Key('configuration-collection-features-save-button'),
          ),
        );
        final fieldRect = tester.getRect(
          find.byKey(const Key('configuration-collection-features-field')),
        );

        expect(selectRect.width, buttonRect.width);
        expect(
          selectRect.height,
          moreOrLessEquals(buttonRect.height, epsilon: 0.1),
        );
        expect(selectRect.width, lessThan(fieldRect.width));
        expect(
          (fieldRect.right - buttonRect.right).abs(),
          lessThanOrEqualTo(1),
        );
      },
    );

    testWidgets('saves collection number features with apply_now false', (
      WidgetTester tester,
    ) async {
      _enqueueCollectionNumberFeatures(bundle, features: const ['FC2']);
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/collection-number-features',
        body: {
          'features': ['OFJE', 'FC2'],
          'sync_stats': null,
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-collection-features'),
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-collection-features-field')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('configuration-collection-features-field')),
        ' ofje \nFC2\n',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-collection-apply-now-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-collection-apply-now-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('仅保存特征配置').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('configuration-collection-features-save-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-collection-features-save-button')),
      );
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' &&
            request.path == '/collection-number-features',
      );
      expect(patchRequest.body['features'], ['ofje', 'FC2']);
      expect(patchRequest.uri.queryParameters['apply_now'], 'false');

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('configuration-collection-features-field')),
      );
      expect(field.controller?.text, 'OFJE\nFC2');
      expect(find.text('最近一次即时重算结果'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('saves collection number features with sync stats', (
      WidgetTester tester,
    ) async {
      _enqueueCollectionNumberFeatures(bundle, features: const ['FC2']);
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/collection-number-features',
        body: {
          'features': ['FC2', 'OFJE'],
          'sync_stats': {
            'total_movies': 100,
            'matched_count': 20,
            'updated_to_collection_count': 5,
            'updated_to_single_count': 3,
            'unchanged_count': 92,
          },
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-collection-features'),
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-collection-features-field')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('configuration-collection-features-field')),
        'FC2\nOFJE',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-collection-features-save-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-collection-features-save-button')),
      );
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' &&
            request.path == '/collection-number-features',
      );
      expect(patchRequest.uri.queryParameters['apply_now'], 'true');
      expect(find.text('最近一次即时重算结果'), findsOneWidget);
      expect(find.text('影片总数: 100'), findsOneWidget);
      expect(find.text('更新为合集: 5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('keeps input when saving collection features fails', (
      WidgetTester tester,
    ) async {
      _enqueueCollectionNumberFeatures(bundle, features: const ['FC2']);
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueResponder(
        method: 'PATCH',
        path: '/collection-number-features',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'invalid_collection_number_feature',
                'message': '特征值不合法',
              },
            }),
            422,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-collection-features'),
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-collection-features-field')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('configuration-collection-features-field')),
        'FC2\n??',
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-collection-features-save-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-collection-features-save-button')),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('configuration-collection-features-field')),
      );
      expect(field.controller?.text, 'FC2\n??');
      expect(
        bundle.adapter.hitCount('PATCH', '/collection-number-features'),
        1,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('loads playlists lazily and hides system playlists', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 1,
            'name': '最近播放',
            'kind': 'recently_played',
            'description': '系统自动维护的最近播放影片列表',
            'is_system': true,
            'is_mutable': false,
            'is_deletable': false,
            'movie_count': 1,
            'created_at': '2026-03-12T10:00:00Z',
            'updated_at': '2026-03-12T10:00:00Z',
          },
          {
            'id': 2,
            'name': '我的收藏',
            'kind': 'custom',
            'description': 'Favorite movies',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 2,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T11:20:00Z',
          },
        ],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      expect(bundle.adapter.hitCount('GET', '/playlists'), 0);

      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/playlists'), 1);
      final request = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'GET' && item.path == '/playlists',
      );
      expect(request.uri.queryParameters['include_system'], 'false');
      expect(find.text('我的收藏'), findsOneWidget);
      expect(find.text('最近播放'), findsNothing);
    });

    testWidgets('creates playlist from configuration playlists tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueuePlaylists(bundle, playlists: const []);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/playlists',
        statusCode: 201,
        body: {
          'id': 3,
          'name': '稍后再看',
          'kind': 'custom',
          'description': 'Need watch later',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 0,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T10:10:00Z',
        },
      );
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 3,
            'name': '稍后再看',
            'kind': 'custom',
            'description': 'Need watch later',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 0,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T10:10:00Z',
          },
        ],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-playlist-create-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('create-playlist-name-field')),
        '稍后再看',
      );
      await tester.enterText(
        find.byKey(const Key('create-playlist-description-field')),
        'Need watch later',
      );
      await tester.tap(find.byKey(const Key('create-playlist-submit-button')));
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'POST' && item.path == '/playlists',
      );
      expect(request.body['name'], '稍后再看');
      expect(request.body['description'], 'Need watch later');
      expect(find.text('稍后再看'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('edits playlist from configuration playlists tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 2,
            'name': '我的收藏',
            'kind': 'custom',
            'description': 'Favorite movies',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 2,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T11:20:00Z',
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/playlists/2',
        body: {
          'id': 2,
          'name': '收藏补完',
          'kind': 'custom',
          'description': 'Updated',
          'is_system': false,
          'is_mutable': true,
          'is_deletable': true,
          'movie_count': 2,
          'created_at': '2026-03-12T10:10:00Z',
          'updated_at': '2026-03-12T11:30:00Z',
        },
      );
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 2,
            'name': '收藏补完',
            'kind': 'custom',
            'description': 'Updated',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 2,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T11:30:00Z',
          },
        ],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('playlist-edit-2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('configuration-playlist-name-field')),
        '收藏补完',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-playlist-description-field')),
        'Updated',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final request = bundle.adapter.requests.firstWhere(
        (item) => item.method == 'PATCH' && item.path == '/playlists/2',
      );
      expect(request.body['name'], '收藏补完');
      expect(request.body['description'], 'Updated');
      expect(find.text('收藏补完'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('deletes playlist from configuration playlists tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueuePlaylists(
        bundle,
        playlists: const [
          {
            'id': 2,
            'name': '我的收藏',
            'kind': 'custom',
            'description': 'Favorite movies',
            'is_system': false,
            'is_mutable': true,
            'is_deletable': true,
            'movie_count': 2,
            'created_at': '2026-03-12T10:10:00Z',
            'updated_at': '2026-03-12T11:20:00Z',
          },
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/playlists/2',
        statusCode: 204,
      );
      _enqueuePlaylists(bundle, playlists: const []);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);

      await tester.tap(find.byKey(const Key('configuration-tab-playlists')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('playlist-delete-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('DELETE', '/playlists/2'), 1);
      expect(find.text('我的收藏'), findsNothing);
      expect(find.text('还没有自定义播放列表'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('creates a media library and refreshes the list', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, libraries: const []);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/media-libraries',
        statusCode: 201,
        body: {
          'id': 2,
          'name': 'Archive Library',
          'root_path': '/media/library/archive',
          'created_at': '2026-03-09T09:30:00Z',
          'updated_at': '2026-03-09T09:30:00Z',
        },
      );
      _enqueueMediaLibraries(
        bundle,
        libraries: const [
          {
            'id': 2,
            'name': 'Archive Library',
            'root_path': '/media/library/archive',
            'created_at': '2026-03-09T09:30:00Z',
            'updated_at': '2026-03-09T09:30:00Z',
          },
        ],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openMediaLibrariesTab(tester);
      await tester.tap(
        find.byKey(const Key('configuration-media-library-create-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('media-library-name-field')),
        'Archive Library',
      );
      await tester.enterText(
        find.byKey(const Key('media-library-root-path-field')),
        '/media/library/archive',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final postRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'POST' && request.path == '/media-libraries',
      );
      expect(postRequest.body['name'], 'Archive Library');
      expect(postRequest.body['root_path'], '/media/library/archive');
      expect(find.text('Archive Library'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows media library id on configuration cards', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openMediaLibrariesTab(tester);

      expect(find.text('ID: 1'), findsOneWidget);
    });

    testWidgets('edits a media library and refreshes download tab libraries', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/media-libraries/1',
        body: {
          'id': 1,
          'name': 'Main Library Updated',
          'root_path': '/media/library/updated',
          'created_at': '2026-03-08T09:30:00Z',
          'updated_at': '2026-03-10T09:30:00Z',
        },
      );
      _enqueueMediaLibraries(
        bundle,
        libraries: const [
          {
            'id': 1,
            'name': 'Main Library Updated',
            'root_path': '/media/library/updated',
            'created_at': '2026-03-08T09:30:00Z',
            'updated_at': '2026-03-10T09:30:00Z',
          },
        ],
      );
      _enqueueDownloadClientsList(bundle, clients: const []);
      _enqueueMediaLibraries(
        bundle,
        libraries: const [
          {
            'id': 1,
            'name': 'Main Library Updated',
            'root_path': '/media/library/updated',
            'created_at': '2026-03-08T09:30:00Z',
            'updated_at': '2026-03-10T09:30:00Z',
          },
        ],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openMediaLibrariesTab(tester);
      await tester.tap(find.byKey(const Key('media-library-edit-1')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('media-library-name-field')),
        'Main Library Updated',
      );
      await tester.enterText(
        find.byKey(const Key('media-library-root-path-field')),
        '/media/library/updated',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' && request.path == '/media-libraries/1',
      );
      expect(patchRequest.body['name'], 'Main Library Updated');
      expect(patchRequest.body['root_path'], '/media/library/updated');
      expect(find.text('Main Library Updated'), findsWidgets);

      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-download-client-create-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('download-client-media-library-field')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Main Library Updated'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('deletes a media library and refreshes the list', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media-libraries/1',
        statusCode: 204,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-libraries',
        body: const <Map<String, Object?>>[],
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openMediaLibrariesTab(tester);
      await tester.tap(find.byKey(const Key('media-library-delete-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('DELETE', '/media-libraries/1'), 1);
      expect(find.text('Main Library'), findsNothing);
      expect(find.text('还没有媒体库'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'does not call delete api when media library deletion canceled',
      (WidgetTester tester) async {
        _enqueueMediaLibraries(bundle);

        await _pumpPage(tester, bundle, sessionStore: sessionStore);
        await _openMediaLibrariesTab(tester);
        await tester.tap(find.byKey(const Key('media-library-delete-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消').last);
        await tester.pumpAndSettle();

        expect(bundle.adapter.hitCount('DELETE', '/media-libraries/1'), 0);
        expect(find.byKey(const Key('media-library-card-1')), findsOneWidget);
        expect(find.text('Main Library'), findsOneWidget);
      },
    );

    testWidgets('shows backend error when deleting a media library fails', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueResponder(
        method: 'DELETE',
        path: '/media-libraries/1',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'media_library_in_use',
                'message': '媒体库仍被业务数据引用，无法删除',
              },
            }),
            409,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openMediaLibrariesTab(tester);
      await tester.tap(find.byKey(const Key('media-library-delete-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('DELETE', '/media-libraries/1'), 1);
      expect(find.byKey(const Key('media-library-card-1')), findsOneWidget);
      expect(find.text('媒体库仍被业务数据引用，无法删除'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('prevents creating a media library with a relative root path', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, libraries: const []);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openMediaLibrariesTab(tester);
      await tester.tap(
        find.byKey(const Key('configuration-media-library-create-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('media-library-name-field')),
        'Archive Library',
      );
      await tester.enterText(
        find.byKey(const Key('media-library-root-path-field')),
        'relative/path',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/media-libraries'), 0);
      expect(find.text('请输入路径'), findsOneWidget);
    });

    testWidgets('shows backend error when creating a media library fails', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle, libraries: const []);
      bundle.adapter.enqueueResponder(
        method: 'POST',
        path: '/media-libraries',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'media_library_conflict',
                'message': '媒体库名称已存在',
              },
            }),
            409,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openMediaLibrariesTab(tester);
      await tester.tap(
        find.byKey(const Key('configuration-media-library-create-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('media-library-name-field')),
        'Main Library',
      );
      await tester.enterText(
        find.byKey(const Key('media-library-root-path-field')),
        '/media/library/main',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      expect(find.text('媒体库名称已存在'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('renders account security form in account tab', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );

      expect(find.text('账号安全'), findsWidgets);
      expect(
        find.byKey(const Key('configuration-password-current-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuration-password-new-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('configuration-password-confirm-field')),
        findsOneWidget,
      );
    });

    testWidgets('validates required password fields before submit', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('请输入当前密码'), findsOneWidget);
      expect(find.text('请输入新密码'), findsOneWidget);
      expect(find.text('请再次输入新密码'), findsOneWidget);
      expect(bundle.adapter.hitCount('POST', '/account/password'), 0);
    });

    testWidgets('prevents reusing current password as new password', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'same-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'same-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'same-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('新密码不能与当前密码相同'), findsOneWidget);
      expect(bundle.adapter.hitCount('POST', '/account/password'), 0);
    });

    testWidgets('prevents submit when password confirmation mismatches', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'old-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'other-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('两次输入的新密码不一致'), findsOneWidget);
      expect(bundle.adapter.hitCount('POST', '/account/password'), 0);
    });

    testWidgets('submits password change request and clears fields on reset', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/account',
        body: {
          'username': 'account',
          'created_at': '2026-03-08T09:00:00Z',
          'last_login_at': '2026-03-08T10:00:00Z',
        },
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/account/password',
        statusCode: 204,
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/auth/tokens',
        body: {
          'access_token': 'verified-access-token',
          'refresh_token': 'verified-refresh-token',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'expires_at': '2026-03-10T13:00:00Z',
          'refresh_expires_at': '2026-03-17T13:00:00Z',
          'user': {'username': 'account'},
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'old-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'new-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final postRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'POST' && request.path == '/account/password',
      );
      expect(postRequest.body, <String, dynamic>{
        'current_password': 'old-password',
        'new_password': 'new-password',
      });
      final verifyRequest = bundle.adapter.requests.firstWhere(
        (request) => request.method == 'POST' && request.path == '/auth/tokens',
      );
      expect(verifyRequest.body, <String, dynamic>{
        'username': 'account',
        'password': 'new-password',
      });
      expect(sessionStore.hasSession, isFalse);

      await sessionStore.saveTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'stale-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'reset-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'reset-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-reset-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-reset-button')),
      );
      await tester.pump();

      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('configuration-password-current-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('configuration-password-new-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('configuration-password-confirm-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows backend error when password change fails', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/account',
        body: {
          'username': 'account',
          'created_at': '2026-03-08T09:00:00Z',
          'last_login_at': '2026-03-08T10:00:00Z',
        },
      );
      await sessionStore.saveTokens(
        accessToken: 'access-token',
        refreshToken: '',
        expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
      );
      bundle.adapter.enqueueResponder(
        method: 'POST',
        path: '/account/password',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'invalid_credentials',
                'message': 'Current password is incorrect',
                'details': null,
              },
            }),
            401,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'wrong-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'new-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Current password is incorrect'), findsOneWidget);
      expect(find.byKey(const Key('configuration-page')), findsOneWidget);
      expect(sessionStore.accessToken, 'access-token');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('keeps session when new password verification fails', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/account',
        body: {
          'username': 'account',
          'created_at': '2026-03-08T09:00:00Z',
          'last_login_at': '2026-03-08T10:00:00Z',
        },
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/account/password',
        statusCode: 204,
      );
      bundle.adapter.enqueueResponder(
        method: 'POST',
        path: '/auth/tokens',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {'code': 'invalid_credentials', 'message': '用户名或密码错误'},
            }),
            401,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await _openConfigurationTab(
        tester,
        const Key('configuration-tab-account-security'),
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-current-field')),
        'old-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-new-field')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('configuration-password-confirm-field')),
        'new-password',
      );

      await tester.ensureVisible(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-password-submit-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('密码已修改，但新密码登录校验失败，请重新登录确认'), findsOneWidget);
      expect(sessionStore.hasSession, isTrue);
      expect(find.byKey(const Key('configuration-page')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('creates a download client and refreshes the list', (
      WidgetTester tester,
    ) async {
      _enqueueDownloadClientsList(bundle, clients: const []);
      _enqueueMediaLibraries(bundle);
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/download-clients',
        statusCode: 201,
        body: {
          'id': 1,
          'name': 'client-a',
          'base_url': 'http://localhost:8080',
          'username': 'alice',
          'client_save_path': '/downloads/a',
          'local_root_path': '/mnt/qb/downloads/a',
          'media_library_id': 1,
          'has_password': true,
          'created_at': '2026-03-10T08:00:00Z',
          'updated_at': '2026-03-10T08:00:00Z',
        },
      );
      _enqueueDownloadClientsList(
        bundle,
        clients: [
          const {
            'id': 1,
            'name': 'client-a',
            'base_url': 'http://localhost:8080',
            'username': 'alice',
            'client_save_path': '/downloads/a',
            'local_root_path': '/mnt/qb/downloads/a',
            'media_library_id': 1,
            'has_password': true,
            'created_at': '2026-03-10T08:00:00Z',
            'updated_at': '2026-03-10T08:00:00Z',
          },
        ],
      );
      _enqueueMediaLibraries(bundle);
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-download-client-create-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('添加下载器'), findsOneWidget);
      expect(find.text('给下载器起个名字，例如：pt 专属'), findsOneWidget);
      expect(find.text('填写完整内网地址，例如：http://192.168.1.2:8080'), findsOneWidget);
      expect(find.text('输入用于登录下载器的用户名'), findsOneWidget);
      expect(find.text('输入用于登录下载器的密码'), findsOneWidget);
      expect(
        find.text('填写 qBittorrent 容器内使用的路径，例如：/downloads'),
        findsOneWidget,
      );
      expect(
        find.text('填写 SakuraMediaBE 中的实际下载绝对路径，例如:/mnt/downloads'),
        findsOneWidget,
      );

      final usernameRows =
          tester
              .elementList(
                find.ancestor(
                  of: find.byKey(const Key('download-client-username-field')),
                  matching: find.byType(Row),
                ),
              )
              .toSet();
      final passwordRows =
          tester
              .elementList(
                find.ancestor(
                  of: find.byKey(const Key('download-client-password-field')),
                  matching: find.byType(Row),
                ),
              )
              .toSet();
      expect(usernameRows.intersection(passwordRows), isNotEmpty);

      await tester.enterText(
        find.byKey(const Key('download-client-name-field')),
        'client-a',
      );
      await tester.enterText(
        find.byKey(const Key('download-client-base-url-field')),
        'http://localhost:8080',
      );
      await tester.enterText(
        find.byKey(const Key('download-client-username-field')),
        'alice',
      );
      await tester.enterText(
        find.byKey(const Key('download-client-password-field')),
        'secret',
      );
      await tester.enterText(
        find.byKey(const Key('download-client-client-save-path-field')),
        '/downloads/a',
      );
      await tester.ensureVisible(
        find.byKey(const Key('download-client-local-root-path-field')),
      );
      await tester.enterText(
        find.byKey(const Key('download-client-local-root-path-field')),
        '/mnt/qb/downloads/a',
      );
      await tester.ensureVisible(
        find.byKey(const Key('download-client-media-library-field')),
      );
      await tester.tap(
        find.byKey(const Key('download-client-media-library-field')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Main Library'), findsOneWidget);
      await tester.tap(find.text('Main Library').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final postRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'POST' && request.path == '/download-clients',
      );
      expect(postRequest.body['password'], 'secret');
      expect(postRequest.body['media_library_id'], 1);
      expect(postRequest.body['client_save_path'], '/downloads/a');
      expect(postRequest.body['local_root_path'], '/mnt/qb/downloads/a');
      expect(find.text('client-a'), findsWidgets);
      expect(
        find.textContaining('qBittorrent保存路径: /downloads/a'),
        findsOneWidget,
      );
      expect(
        find.textContaining('本地访问路径: /mnt/qb/downloads/a'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('download client dialog uses custom dialog layout', (
      WidgetTester tester,
    ) async {
      _enqueueDownloadClientsList(bundle, clients: const []);
      _enqueueMediaLibraries(bundle);
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-download-client-create-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('添加下载器'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('editing a download client omits password when left blank', (
      WidgetTester tester,
    ) async {
      _enqueueDownloadClientsList(
        bundle,
        clients: [
          const {
            'id': 1,
            'name': 'client-a',
            'base_url': 'http://localhost:8080',
            'username': 'alice',
            'client_save_path': '/downloads/a',
            'local_root_path': '/mnt/qb/downloads/a',
            'media_library_id': 1,
            'has_password': true,
            'created_at': '2026-03-10T08:00:00Z',
            'updated_at': '2026-03-10T08:00:00Z',
          },
        ],
      );
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/download-clients/1',
        body: {
          'id': 1,
          'name': 'client-a',
          'base_url': 'http://localhost:8080',
          'username': 'bob',
          'client_save_path': '/downloads/a',
          'local_root_path': '/mnt/qb/downloads/a',
          'media_library_id': 1,
          'has_password': true,
          'created_at': '2026-03-10T08:00:00Z',
          'updated_at': '2026-03-10T08:10:00Z',
        },
      );
      _enqueueDownloadClientsList(
        bundle,
        clients: [
          const {
            'id': 1,
            'name': 'client-a',
            'base_url': 'http://localhost:8080',
            'username': 'bob',
            'client_save_path': '/downloads/a',
            'local_root_path': '/mnt/qb/downloads/a',
            'media_library_id': 1,
            'has_password': true,
            'created_at': '2026-03-10T08:00:00Z',
            'updated_at': '2026-03-10T08:10:00Z',
          },
        ],
      );
      _enqueueMediaLibraries(bundle);
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download-client-edit-1')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('download-client-username-field')),
        'bob',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' && request.path == '/download-clients/1',
      );
      expect(patchRequest.body['username'], 'bob');
      expect(patchRequest.body.containsKey('password'), isFalse);
      expect(
        find.textContaining('qBittorrent保存路径: /downloads/a'),
        findsOneWidget,
      );
      expect(
        find.textContaining('本地访问路径: /mnt/qb/downloads/a'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('prevents creating a download client with a relative path', (
      WidgetTester tester,
    ) async {
      _enqueueDownloadClientsList(bundle, clients: const []);
      _enqueueMediaLibraries(bundle);
      _enqueueMediaLibraries(bundle);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-download-client-create-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('download-client-name-field')),
        'client-a',
      );
      await tester.enterText(
        find.byKey(const Key('download-client-base-url-field')),
        'http://localhost:8080',
      );
      await tester.enterText(
        find.byKey(const Key('download-client-username-field')),
        'alice',
      );
      await tester.enterText(
        find.byKey(const Key('download-client-password-field')),
        'secret',
      );
      await tester.enterText(
        find.byKey(const Key('download-client-client-save-path-field')),
        'downloads/a',
      );
      await tester.enterText(
        find.byKey(const Key('download-client-local-root-path-field')),
        '/mnt/qb/downloads/a',
      );
      await tester.tap(
        find.byKey(const Key('download-client-media-library-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main Library').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('POST', '/download-clients'), 0);
      expect(find.text('请输入路径'), findsOneWidget);
    });

    testWidgets('shows backend error when deleting a client fails', (
      WidgetTester tester,
    ) async {
      _enqueueDownloadClientsList(
        bundle,
        clients: [
          const {
            'id': 1,
            'name': 'client-a',
            'base_url': 'http://localhost:8080',
            'username': 'alice',
            'client_save_path': '/downloads/a',
            'local_root_path': '/mnt/qb/downloads/a',
            'media_library_id': 1,
            'has_password': true,
            'created_at': '2026-03-10T08:00:00Z',
            'updated_at': '2026-03-10T08:00:00Z',
          },
        ],
      );
      _enqueueMediaLibraries(bundle);
      _enqueueMediaLibraries(bundle);
      bundle.adapter.enqueueResponder(
        method: 'DELETE',
        path: '/download-clients/1',
        responder: (options, requestBody) async {
          return ResponseBody.fromString(
            jsonEncode({
              'error': {
                'code': 'download_client_in_use',
                'message': '下载器仍被任务引用',
              },
            }),
            409,
            headers: const {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-downloads')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download-client-delete-1')));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(find.text('下载器仍被任务引用'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'loads indexer settings and download clients when switching tabs',
      (WidgetTester tester) async {
        _enqueueMediaLibraries(bundle);
        _enqueueIndexerSettings(bundle, indexers: const []);
        _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

        await _pumpPage(tester, bundle, sessionStore: sessionStore);

        expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 0);
        expect(bundle.adapter.hitCount('GET', '/download-clients'), 0);

        await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
        await tester.pumpAndSettle();

        expect(bundle.adapter.hitCount('GET', '/indexer-settings'), 1);
        expect(bundle.adapter.hitCount('GET', '/download-clients'), 1);
      },
    );

    testWidgets('disables creating indexer when no download clients exist', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(bundle, indexers: const []);
      _enqueueDownloadClientsList(bundle, clients: const []);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();

      final createButton = tester.widget<AppButton>(
        find.byKey(const Key('configuration-indexer-create-button')),
      );
      expect(createButton.onPressed, isNull);
      expect(find.text('请先在下载器 Tab 创建下载器'), findsOneWidget);
    });

    testWidgets('requires selecting a download client when creating indexer', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(bundle, indexers: const []);
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-indexer-create-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('indexer-entry-name-field')),
        'mteam',
      );
      await tester.enterText(
        find.byKey(const Key('indexer-entry-url-field')),
        'https://mirror.example.com/torznab',
      );
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      expect(find.text('请选择下载器'), findsWidgets);
    });

    testWidgets(
      'saves indexers with download client binding and shows client name',
      (WidgetTester tester) async {
        _enqueueMediaLibraries(bundle);
        _enqueueIndexerSettings(bundle, indexers: const []);
        _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);
        bundle.adapter.enqueueJson(
          method: 'PATCH',
          path: '/indexer-settings',
          body: {
            'type': 'jackett',
            'api_key': 'secret-key',
            'indexers': [
              {
                'id': 1,
                'name': 'mteam',
                'url': 'https://mirror.example.com/torznab',
                'kind': 'pt',
                'download_client_id': 1,
                'download_client_name': 'client-a',
              },
            ],
          },
        );

        await _pumpPage(tester, bundle, sessionStore: sessionStore);
        await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('configuration-indexer-create-button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('indexer-entry-name-field')),
          'mteam',
        );
        await tester.enterText(
          find.byKey(const Key('indexer-entry-url-field')),
          'https://mirror.example.com/torznab',
        );
        await tester.tap(
          find.byKey(const Key('indexer-entry-download-client-field')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('client-a').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存').last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('configuration-indexer-save-button')),
        );
        await tester.pumpAndSettle();

        final patchRequest = bundle.adapter.requests.firstWhere(
          (request) =>
              request.method == 'PATCH' && request.path == '/indexer-settings',
        );
        expect(patchRequest.body['indexers'][0]['download_client_id'], 1);
        expect(find.textContaining('下载器: client-a'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('searches indexers by bound download client name', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(
        bundle,
        indexers: const [
          {
            'id': 1,
            'name': 'mteam',
            'url': 'https://mirror.example.com/torznab',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
          {
            'id': 2,
            'name': 'dmhy',
            'url': 'https://public.example.com/torznab',
            'kind': 'bt',
            'download_client_id': 2,
            'download_client_name': 'client-b',
          },
        ],
      );
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'client-b');
      await tester.pumpAndSettle();

      expect(find.text('dmhy'), findsOneWidget);
      expect(find.text('mteam'), findsNothing);
    });

    testWidgets('edits indexer with prefilled download client binding', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(
        bundle,
        indexers: const [
          {
            'id': 1,
            'name': 'mteam',
            'url': 'https://mirror.example.com/torznab',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
        ],
      );
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/indexer-settings',
        body: {
          'type': 'jackett',
          'api_key': 'secret-key',
          'indexers': [
            {
              'id': 1,
              'name': 'mteam',
              'url': 'https://mirror.example.com/torznab',
              'kind': 'pt',
              'download_client_id': 2,
              'download_client_name': 'client-b',
            },
          ],
        },
      );

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('indexer-entry-edit-0')));
      await tester.pumpAndSettle();

      expect(find.text('client-a'), findsWidgets);
      await tester.tap(
        find.byKey(const Key('indexer-entry-download-client-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-b').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-indexer-save-button')),
      );
      await tester.pumpAndSettle();

      final patchRequest = bundle.adapter.requests.firstWhere(
        (request) =>
            request.method == 'PATCH' && request.path == '/indexer-settings',
      );
      expect(patchRequest.body['indexers'][0]['download_client_id'], 2);
      expect(find.textContaining('下载器: client-b'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('prevents duplicate indexer names before saving', (
      WidgetTester tester,
    ) async {
      _enqueueMediaLibraries(bundle);
      _enqueueIndexerSettings(
        bundle,
        indexers: const [
          {
            'id': 1,
            'name': 'mteam',
            'url': 'https://example.com/torznab',
            'kind': 'pt',
            'download_client_id': 1,
            'download_client_name': 'client-a',
          },
        ],
      );
      _enqueueDownloadClientsList(bundle, clients: _defaultDownloadClients);

      await _pumpPage(tester, bundle, sessionStore: sessionStore);
      await tester.tap(find.byKey(const Key('configuration-tab-indexers')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('configuration-indexer-create-button')),
      );
      await tester.tap(
        find.byKey(const Key('configuration-indexer-create-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('indexer-entry-name-field')),
        'mteam',
      );
      await tester.enterText(
        find.byKey(const Key('indexer-entry-url-field')),
        'https://mirror.example.com/torznab',
      );
      await tester.tap(
        find.byKey(const Key('indexer-entry-download-client-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-a').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('configuration-indexer-save-button')),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('PATCH', '/indexer-settings'), 0);
      expect(find.text('索引器名称重复: mteam'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('successful password change returns to login through router', (
    WidgetTester tester,
  ) async {
    final sessionStore = await _buildLoggedInSessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    _enqueueOverviewResponses(bundle);
    _enqueueMetadataProviderLicenseStatus(bundle, active: true);
    _enqueueMediaLibraries(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/account',
      body: {
        'username': 'account',
        'created_at': '2026-03-08T09:00:00Z',
        'last_login_at': '2026-03-08T10:00:00Z',
      },
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/account/password',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/auth/tokens',
      body: {
        'access_token': 'verified-access-token',
        'refresh_token': 'verified-refresh-token',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'expires_at': '2026-03-10T13:00:00Z',
        'refresh_expires_at': '2026-03-17T13:00:00Z',
        'user': {'username': 'account'},
      },
    );

    final router = buildDesktopRouter(sessionStore: sessionStore);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppShellController()),
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
          Provider<AccountApi>.value(value: bundle.accountApi),
          Provider<AuthApi>.value(value: bundle.authApi),
          Provider<CollectionNumberFeaturesApi>.value(
            value: bundle.collectionNumberFeaturesApi,
          ),
          Provider<DownloadClientsApi>.value(value: bundle.downloadClientsApi),
          Provider<MediaLibrariesApi>.value(value: bundle.mediaLibrariesApi),
          Provider<IndexerSettingsApi>.value(value: bundle.indexerSettingsApi),
          Provider<MetadataProviderLicenseApi>.value(
            value: bundle.metadataProviderLicenseApi,
          ),
          Provider<MovieDescTranslationSettingsApi>.value(
            value: bundle.movieDescTranslationSettingsApi,
          ),
          Provider<StatusApi>.value(value: bundle.statusApi),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
        ],
        child: OKToast(
          child: MaterialApp.router(
            theme: sakuraThemeData,
            routerConfig: router,
          ),
        ),
      ),
    );
    addTearDown(tester.view.reset);

    router.go(desktopConfigurationPath);
    await tester.pumpAndSettle();
    await _openConfigurationTab(
      tester,
      const Key('configuration-tab-account-security'),
    );

    await tester.enterText(
      find.byKey(const Key('configuration-password-current-field')),
      'old-password',
    );
    await tester.enterText(
      find.byKey(const Key('configuration-password-new-field')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('configuration-password-confirm-field')),
      'new-password',
    );
    await tester.ensureVisible(
      find.byKey(const Key('configuration-password-submit-button')),
    );
    await tester.tap(
      find.byKey(const Key('configuration-password-submit-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(sessionStore.hasSession, isFalse);
    expect(find.byKey(const Key('login-form-base-url')), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, loginPath);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  TestApiBundle bundle, {
  required SessionStore sessionStore,
  bool enqueueDefaultLicenseStatus = true,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;

  if (enqueueDefaultLicenseStatus) {
    _enqueueMetadataProviderLicenseStatus(bundle, active: true);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
        Provider<AccountApi>.value(value: bundle.accountApi),
        Provider<AuthApi>.value(value: bundle.authApi),
        Provider<CollectionNumberFeaturesApi>.value(
          value: bundle.collectionNumberFeaturesApi,
        ),
        Provider<DownloadClientsApi>.value(value: bundle.downloadClientsApi),
        Provider<MediaLibrariesApi>.value(value: bundle.mediaLibrariesApi),
        Provider<IndexerSettingsApi>.value(value: bundle.indexerSettingsApi),
        Provider<MetadataProviderLicenseApi>.value(
          value: bundle.metadataProviderLicenseApi,
        ),
        Provider<MovieDescTranslationSettingsApi>.value(
          value: bundle.movieDescTranslationSettingsApi,
        ),
        Provider<PlaylistsApi>.value(value: bundle.playlistsApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: DesktopConfigurationPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(tester.view.reset);
}

Future<void> _openConfigurationTab(WidgetTester tester, Key tabKey) async {
  await tester.tap(find.byKey(tabKey));
  await tester.pumpAndSettle();
}

Future<void> _openMediaLibrariesTab(WidgetTester tester) async {
  await _openConfigurationTab(
    tester,
    const Key('configuration-tab-media-libraries'),
  );
}

void _enqueueDownloadClientsList(
  TestApiBundle bundle, {
  required List<Map<String, Object?>> clients,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/download-clients',
    body: clients,
  );
}

const List<Map<String, Object?>> _defaultDownloadClients = [
  {
    'id': 1,
    'name': 'client-a',
    'base_url': 'http://localhost:8080',
    'username': 'alice',
    'client_save_path': '/downloads/a',
    'local_root_path': '/mnt/qb/downloads/a',
    'media_library_id': 1,
    'has_password': true,
    'created_at': '2026-03-10T08:00:00Z',
    'updated_at': '2026-03-10T08:00:00Z',
  },
  {
    'id': 2,
    'name': 'client-b',
    'base_url': 'http://localhost:8081',
    'username': 'bob',
    'client_save_path': '/downloads/b',
    'local_root_path': '/mnt/qb/downloads/b',
    'media_library_id': 1,
    'has_password': true,
    'created_at': '2026-03-10T09:00:00Z',
    'updated_at': '2026-03-10T09:00:00Z',
  },
];

void _enqueueIndexerSettings(
  TestApiBundle bundle, {
  List<Map<String, Object?>> indexers = const [],
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/indexer-settings',
    body: {'type': 'jackett', 'api_key': 'secret-key', 'indexers': indexers},
  );
}

void _enqueuePlaylists(
  TestApiBundle bundle, {
  required List<Map<String, Object?>> playlists,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/playlists',
    body: playlists,
  );
}

void _enqueueMediaLibraries(
  TestApiBundle bundle, {
  bool includeLlmSettings = true,
  List<Map<String, Object?>> libraries = const [
    {
      'id': 1,
      'name': 'Main Library',
      'root_path': '/media/library/main',
      'created_at': '2026-03-08T09:30:00Z',
      'updated_at': '2026-03-08T09:30:00Z',
    },
  ],
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-libraries',
    body: libraries,
  );
  _enqueueCollectionNumberFeatures(bundle);
  if (includeLlmSettings) {
    _enqueueMovieDescTranslationSettings(bundle);
  }
}

void _enqueueCollectionNumberFeatures(
  TestApiBundle bundle, {
  List<String> features = const ['CJOB', 'DVAJ'],
  Map<String, Object?>? syncStats,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/collection-number-features',
    body: {'features': features, 'sync_stats': syncStats},
  );
}

void _enqueueMovieDescTranslationSettings(
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
    body: _buildMovieDescTranslationSettingsJson(
      enabled: enabled,
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      timeoutSeconds: timeoutSeconds,
      connectTimeoutSeconds: connectTimeoutSeconds,
    ),
  );
}

void _enqueueMetadataProviderLicenseStatus(
  TestApiBundle bundle, {
  required bool active,
  String? errorCode,
  String? message,
  int? licenseValidUntil,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/metadata-provider-license/status',
    body: _buildMetadataProviderLicenseStatusJson(
      active: active,
      errorCode: errorCode,
      message: message,
      licenseValidUntil: licenseValidUntil,
    ),
  );
}

void _enqueueMetadataProviderLicenseActivate(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/metadata-provider-license/activate',
    body: _buildMetadataProviderLicenseStatusJson(active: true),
  );
}

void _enqueueMetadataProviderLicenseRenew(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/metadata-provider-license/renew',
    body: _buildMetadataProviderLicenseStatusJson(active: true),
  );
}

void _enqueueMetadataProviderLicenseConnectivity(
  TestApiBundle bundle, {
  required bool ok,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/metadata-provider-license/connectivity-test',
    body: <String, dynamic>{
      'ok': ok,
      'url': 'https://license.example.com/',
      'proxy_enabled': true,
      'elapsed_ms': 128,
      'status_code': ok ? 200 : null,
      'error': ok ? null : 'timeout',
    },
  );
}

Map<String, dynamic> _buildMetadataProviderLicenseStatusJson({
  required bool active,
  String? errorCode,
  String? message,
  int? licenseValidUntil,
}) {
  return <String, dynamic>{
    'configured': true,
    'active': active,
    'instance_id': 'inst_test',
    'expires_at': active ? 1777181126 : null,
    'license_valid_until': licenseValidUntil ?? (active ? 4102444800 : null),
    'renew_after_seconds': active ? 21600 : null,
    'error_code': active ? null : (errorCode ?? 'license_required'),
    'message': active ? null : (message ?? 'License activation is required'),
  };
}

Map<String, dynamic> _buildMovieDescTranslationSettingsJson({
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
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
  );
  return store;
}

void _enqueueOverviewResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    body: <String, dynamic>{
      'actors': <String, dynamic>{'female_total': 12, 'female_subscribed': 8},
      'movies': <String, dynamic>{
        'total': 120,
        'subscribed': 35,
        'playable': 88,
      },
      'media_files': <String, dynamic>{
        'total': 156,
        'total_size_bytes': 987654321,
      },
      'media_libraries': <String, dynamic>{'total': 3},
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    body: <String, dynamic>{
      'healthy': true,
      'joytag': <String, dynamic>{'healthy': true, 'used_device': 'GPU'},
      'indexing': <String, dynamic>{
        'pending_thumbnails': 23,
        'failed_thumbnails': 2,
      },
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/latest',
    body: <String, dynamic>{
      'items': List<Map<String, dynamic>>.generate(
        8,
        (index) => <String, dynamic>{
          'javdb_id': 'MovieA${index + 1}',
          'movie_number': 'ABC-${(index + 1).toString().padLeft(3, '0')}',
          'title': 'Movie ${index + 1}',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'is_subscribed': index.isEven,
          'can_play': true,
        },
      ),
      'page': 1,
      'page_size': 8,
      'total': 8,
    },
  );
}
