import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/configuration/presentation/mobile_data_sources_page.dart';
import 'package:sakuramedia/theme.dart';

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

  testWidgets('loads overview, activation card and bottom action', (
    WidgetTester tester,
  ) async {
    _enqueueLicenseStatus(_bundle, active: true);

    await _pumpPage(tester);

    expect(
      find.byKey(const Key('mobile-settings-data-sources')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-data-sources-overview-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-data-sources-activation-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-data-sources-diagnostics')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-data-sources-activate-button')),
      findsOneWidget,
    );
    expect(find.text('数据源授权'), findsOneWidget);
    expect(find.text('已激活'), findsWidgets);
    expect(find.textContaining('有效至'), findsOneWidget);
    expect(find.text('未检测'), findsOneWidget);
  });

  testWidgets('maps pending status label', (WidgetTester tester) async {
    _enqueueLicenseStatus(
      _bundle,
      active: false,
      licenseValidUntil: 4102444800,
      errorCode: null,
    );
    await _pumpPage(tester);
    expect(find.text('授权待同步'), findsWidgets);
    expect(find.textContaining('重新同步授权'), findsOneWidget);
  });

  testWidgets('maps expired status label', (WidgetTester tester) async {
    _enqueueLicenseStatus(
      _bundle,
      active: false,
      licenseValidUntil: 1,
      errorCode: 'license_expired',
    );
    await _pumpPage(tester);
    expect(find.text('授权已到期'), findsWidgets);
    expect(find.textContaining('授权已到期，请使用新的激活码'), findsOneWidget);
  });

  testWidgets('maps inactive status label', (WidgetTester tester) async {
    _enqueueLicenseStatus(
      _bundle,
      active: false,
      licenseValidUntil: null,
      errorCode: 'license_required',
    );
    await _pumpPage(tester);
    expect(find.text('未激活'), findsWidgets);
  });

  testWidgets('shows fatal error and retries successfully', (
    WidgetTester tester,
  ) async {
    _bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/metadata-provider-license/status',
      responder: (_, __) async {
        return ResponseBody.fromString(
          jsonEncode({
            'error': <String, dynamic>{
              'code': 'server_error',
              'message': '授权状态加载失败，请稍后重试。',
            },
          }),
          500,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );
    _enqueueLicenseStatus(_bundle, active: true);

    await _pumpPage(tester);

    expect(
      find.byKey(const Key('mobile-data-sources-error-state')),
      findsOneWidget,
    );
    expect(find.text('授权状态加载失败，请稍后重试。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-data-sources-retry-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-data-sources-overview-card')),
      findsOneWidget,
    );
  });

  testWidgets('validates empty activation code before submitting', (
    WidgetTester tester,
  ) async {
    _enqueueLicenseStatus(_bundle, active: false);

    await _pumpPage(tester);

    await tester.tap(
      find.byKey(const Key('mobile-data-sources-activate-button')),
    );
    await tester.pump();

    expect(find.text('请输入激活码'), findsOneWidget);
    expect(
      _bundle.adapter.hitCount('POST', '/metadata-provider-license/activate'),
      0,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('activates license and clears activation field', (
    WidgetTester tester,
  ) async {
    _enqueueLicenseStatus(_bundle, active: false);
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/metadata-provider-license/activate',
      body: _licenseStatusJson(active: true),
    );

    await _pumpPage(tester);
    await tester.enterText(
      find.byKey(const Key('mobile-data-sources-activation-field')),
      'SMB-SUPER-SECRET',
    );
    await tester.tap(
      find.byKey(const Key('mobile-data-sources-activate-button')),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('mobile-data-sources-activation-field')),
    );
    expect(field.controller?.text, isEmpty);
    expect(find.text('已激活'), findsWidgets);
    expect(
      _bundle.adapter.requests
          .where(
            (request) =>
                request.method == 'POST' &&
                request.path == '/metadata-provider-license/activate',
          )
          .single
          .body['activation_code'],
      'SMB-SUPER-SECRET',
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('tests connectivity and updates diagnostics', (
    WidgetTester tester,
  ) async {
    _enqueueLicenseStatus(_bundle, active: true);
    _bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/metadata-provider-license/connectivity-test',
      body: const <String, dynamic>{
        'ok': true,
        'url': 'https://license.example.com/',
        'proxy_enabled': true,
        'elapsed_ms': 128,
        'status_code': 200,
        'error': null,
      },
    );

    await _pumpPage(tester);
    await tester.tap(
      find.byKey(const Key('mobile-data-sources-connectivity-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('连接正常'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('mobile-data-sources-diagnostics')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('诊断信息'));
    await tester.pumpAndSettle();
    expect(find.text('授权中心 URL: https://license.example.com/'), findsOneWidget);
    expect(find.text('代理: 已启用'), findsOneWidget);
    expect(find.text('耗时: 128 ms'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('syncs authorization and applies returned status', (
    WidgetTester tester,
  ) async {
    _enqueueLicenseStatus(
      _bundle,
      active: false,
      licenseValidUntil: 4102444800,
      errorCode: null,
    );
    _bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/metadata-provider-license/renew',
      body: _licenseStatusJson(active: true),
    );

    await _pumpPage(tester);
    expect(find.text('授权待同步'), findsWidgets);

    await tester.tap(find.byKey(const Key('mobile-data-sources-sync-button')));
    await tester.pumpAndSettle();

    expect(find.text('已激活'), findsWidgets);
    expect(
      _bundle.adapter.hitCount('POST', '/metadata-provider-license/renew'),
      1,
    );
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<MetadataProviderLicenseApi>.value(
          value: _bundle.metadataProviderLicenseApi,
        ),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: MobileDataSourcesPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _enqueueLicenseStatus(
  TestApiBundle bundle, {
  required bool active,
  bool configured = true,
  int? licenseValidUntil = 4102444800,
  String? errorCode,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/metadata-provider-license/status',
    body: _licenseStatusJson(
      active: active,
      configured: configured,
      licenseValidUntil: licenseValidUntil,
      errorCode: errorCode,
    ),
  );
}

Map<String, dynamic> _licenseStatusJson({
  required bool active,
  bool configured = true,
  int? licenseValidUntil = 4102444800,
  String? errorCode,
}) {
  return <String, dynamic>{
    'configured': configured,
    'active': active,
    'instance_id': 'inst_test',
    'expires_at': active ? 1777181126 : null,
    'license_valid_until': licenseValidUntil,
    'renew_after_seconds': active ? 21600 : null,
    'error_code': errorCode,
    'message': errorCode == null ? null : 'License status message',
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
