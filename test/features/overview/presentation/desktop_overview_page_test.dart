import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/overview/presentation/desktop_overview_page.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('desktop overview page leaves outer page inset to the shell', () {
    final source =
        File(
          'lib/features/overview/presentation/desktop_overview_page.dart',
        ).readAsStringSync();

    expect(source, isNot(contains('AppPageInsets.desktopStandard')));
    expect(source, isNot(contains('EdgeInsets.all(24)')));
  });

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
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
  });

  testWidgets('desktop overview shows stats strip and latest movies', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle);
    _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('系统信息'), findsOneWidget);
    expect(find.byKey(const Key('overview-stat-movies-total')), findsOneWidget);
    expect(find.text('最近添加'), findsOneWidget);
    expect(find.text('展示最近入库的 8 部影片，便于快速查看当前收录情况。'), findsNothing);
    expect(find.byType(MovieSummaryCard), findsNWidgets(24));
    expect(find.text('ABC-001'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-status-playable-ABC-001')),
      findsOneWidget,
    );
    expect(find.text('Movie 1'), findsNothing);
    expect(find.text('120 分钟'), findsNothing);
    expect(find.text('2024-01-01'), findsNothing);
    expect(find.text('0.9 GB'), findsOneWidget);
    expect(find.textContaining('MB'), findsNothing);
    expect(
      find.byKey(const Key('overview-stat-joytag-health')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('overview-stat-joytag-device')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('overview-stat-joytag-indexing-backlog')),
      findsOneWidget,
    );
    expect(find.text('待索引'), findsOneWidget);
    expect(find.text('正常'), findsOneWidget);
    expect(find.text('GPU'), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(
      find.byKey(const Key('overview-stat-metadata-provider-license')),
      findsOneWidget,
    );
    expect(find.text('数据源授权'), findsOneWidget);
    expect(find.text('已激活'), findsOneWidget);
    expect(
      find.byKey(const Key('overview-stat-license-center-connectivity')),
      findsOneWidget,
    );
    expect(find.text('授权中心'), findsOneWidget);
    expect(find.text('未检测'), findsOneWidget);
    expect(
      find.byKey(const Key('overview-stat-external-data-sources')),
      findsOneWidget,
    );
    expect(find.text('外部数据源'), findsOneWidget);
    expect(find.text('未检测 JavDB / DMM'), findsOneWidget);
    expect(
      find.byKey(const Key('overview-external-data-sources')),
      findsNothing,
    );
    expect(
      bundle.adapter.hitCount('GET', '/status/metadata-providers/javdb/test'),
      0,
    );
    expect(
      bundle.adapter.hitCount('GET', '/status/metadata-providers/dmm/test'),
      0,
    );
  });

  testWidgets('desktop overview shows inactive license status', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle, enqueueLicenseStatus: false);
    _enqueueMetadataProviderLicenseStatus(
      bundle,
      active: false,
      errorCode: 'license_required',
      message: 'License activation is required',
    );
    _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final licenseTile = find.byKey(
      const Key('overview-stat-metadata-provider-license'),
    );
    expect(licenseTile, findsOneWidget);
    expect(
      find.descendant(of: licenseTile, matching: find.text('未激活')),
      findsOneWidget,
    );
  });

  testWidgets('desktop overview shows unavailable license status on failure', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle, enqueueLicenseStatus: false);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/metadata-provider-license/status',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'license_unavailable',
          'message': 'License service is unavailable',
        },
      },
    );
    _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final licenseTile = find.byKey(
      const Key('overview-stat-metadata-provider-license'),
    );
    expect(licenseTile, findsOneWidget);
    expect(
      find.descendant(of: licenseTile, matching: find.text('不可用')),
      findsOneWidget,
    );
  });

  testWidgets('desktop overview tests license center connectivity on demand', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle);
    _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);
    _enqueueMetadataProviderLicenseConnectivity(bundle, ok: true);

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('overview-license-center-test-button')),
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
    expect(find.text('连接正常'), findsOneWidget);
    expect(find.text('未检测'), findsNothing);
  });

  testWidgets('desktop overview shows failed license center connectivity', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle);
    _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);
    _enqueueMetadataProviderLicenseConnectivity(bundle, ok: false);

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('overview-license-center-test-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('连接异常'), findsOneWidget);
    expect(find.text('最近添加'), findsOneWidget);
  });

  testWidgets('desktop overview tests external data sources on demand', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle);
    _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);
    _enqueueMetadataProviderTest(bundle, provider: 'javdb', healthy: true);
    _enqueueMetadataProviderTest(bundle, provider: 'dmm', healthy: false);

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('overview-external-data-sources-test-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount('GET', '/status/metadata-providers/javdb/test'),
      1,
    );
    expect(
      bundle.adapter.hitCount('GET', '/status/metadata-providers/dmm/test'),
      1,
    );
    expect(find.text('✅ JavDB ❌ DMM'), findsOneWidget);
    expect(find.text('未检测 JavDB / DMM'), findsNothing);
  });

  testWidgets(
    'desktop overview treats external data source request errors as failed',
    (WidgetTester tester) async {
      _enqueueStatusSuccess(bundle);
      _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);
      _enqueueMetadataProviderTest(bundle, provider: 'javdb', healthy: true);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/status/metadata-providers/dmm/test',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'server_error',
            'message': 'server error',
          },
        },
      );

      await _pumpOverviewPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('overview-external-data-sources-test-button')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('✅ JavDB ❌ DMM'), findsOneWidget);
    },
  );

  testWidgets('desktop overview uses a denser poster grid on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _enqueueStatusSuccess(bundle);
    _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final gridView = tester.widget<GridView>(
      find.byKey(const Key('movie-summary-grid')),
    );
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 6);
  });

  testWidgets('desktop overview shows total size in gigabytes when zero', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 200,
      body: _statusJson(totalSizeBytes: 0),
    );
    _enqueueImageSearchStatusSuccess(bundle);
    _enqueueMetadataProviderLicenseStatus(bundle);
    _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('0.0 GB'), findsOneWidget);
  });

  testWidgets(
    'desktop overview shows joytag loading values before image search status resolves',
    (WidgetTester tester) async {
      final imageSearchStatusCompleter = Completer<void>();
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/status',
        statusCode: 200,
        body: _statusJson(),
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/status/image-search',
        responder: (options, body) async {
          await imageSearchStatusCompleter.future;
          return ResponseBody.fromString(
            jsonEncode(_imageSearchStatusJson()),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );
      _enqueueMetadataProviderLicenseStatus(bundle);
      _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);

      await _pumpOverviewPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );

      final joyTagHealthTile = find.byKey(
        const Key('overview-stat-joytag-health'),
      );
      final joyTagDeviceTile = find.byKey(
        const Key('overview-stat-joytag-device'),
      );
      final joyTagIndexingTile = find.byKey(
        const Key('overview-stat-joytag-indexing-backlog'),
      );

      for (var i = 0; i < 10; i++) {
        if (joyTagHealthTile.evaluate().isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(joyTagHealthTile, findsOneWidget);
      expect(joyTagDeviceTile, findsOneWidget);
      expect(joyTagIndexingTile, findsOneWidget);
      expect(
        find.byKey(const Key('overview-stat-loading-joytag-health')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('overview-stat-loading-joytag-device')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('overview-stat-loading-joytag-indexing-backlog')),
        findsOneWidget,
      );

      imageSearchStatusCompleter.complete();
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: joyTagHealthTile, matching: find.text('正常')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: joyTagDeviceTile, matching: find.text('GPU')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: joyTagIndexingTile, matching: find.text('23')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('overview-stat-loading-joytag-health')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('overview-stat-loading-joytag-device')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('overview-stat-loading-joytag-indexing-backlog')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'desktop overview shows fallback joytag values when image search status fails',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/status',
        statusCode: 200,
        body: _statusJson(),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/status/image-search',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'server_error',
            'message': 'server error',
          },
        },
      );
      _enqueueMetadataProviderLicenseStatus(bundle);
      _enqueueLatestMoviesSuccess(bundle, count: 24, total: 24);

      await _pumpOverviewPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      final joyTagHealthTile = find.byKey(
        const Key('overview-stat-joytag-health'),
      );
      final joyTagDeviceTile = find.byKey(
        const Key('overview-stat-joytag-device'),
      );
      final joyTagIndexingTile = find.byKey(
        const Key('overview-stat-joytag-indexing-backlog'),
      );

      expect(joyTagHealthTile, findsOneWidget);
      expect(joyTagDeviceTile, findsOneWidget);
      expect(joyTagIndexingTile, findsOneWidget);
      expect(
        find.descendant(of: joyTagHealthTile, matching: find.text('不可用')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: joyTagDeviceTile, matching: find.text('未知')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: joyTagIndexingTile, matching: find.text('不可用')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('overview-stat-loading-joytag-health')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('overview-stat-loading-joytag-device')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('overview-stat-loading-joytag-indexing-backlog')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'desktop overview shows loading placeholders before data resolves',
    (WidgetTester tester) async {
      final statusCompleter = Completer<void>();
      final moviesCompleter = Completer<void>();
      _enqueueImageSearchStatusSuccess(bundle);
      _enqueueMetadataProviderLicenseStatus(bundle);

      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/status',
        responder: (options, body) async {
          await statusCompleter.future;
          return ResponseBody.fromString(
            jsonEncode(_statusJson()),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/movies/latest',
        responder: (options, body) async {
          await moviesCompleter.future;
          return ResponseBody.fromString(
            jsonEncode(_latestMoviesJson(count: 24, total: 24)),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpOverviewPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pump();

      expect(find.byKey(const Key('movie-summary-grid')), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-skeleton-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-summary-card-skeleton-poster-0')),
        findsOneWidget,
      );

      statusCompleter.complete();
      moviesCompleter.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('desktop overview shows empty latest movies state', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/latest',
      statusCode: 200,
      body: _latestMoviesJson(count: 0, total: 0),
    );

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('暂无最新入库影片'), findsOneWidget);
  });

  testWidgets('desktop overview shows latest movies error state', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/latest',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': 'server error',
        },
      },
    );

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('最新入库影片加载失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('desktop overview does not expose pull to refresh', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle);
    _enqueueImageSearchStatusSuccess(bundle);
    _enqueueLatestMoviesSuccess(bundle, count: 1, total: 1);

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.text('ABC-001'), findsOneWidget);
  });

  testWidgets(
    'desktop overview loads the next page when scrolled near the bottom',
    (WidgetTester tester) async {
      _enqueueStatusSuccess(bundle);
      _enqueueLatestMoviesSuccess(bundle, count: 24, total: 30);
      _enqueueLatestMoviesSuccess(
        bundle,
        count: 6,
        page: 2,
        total: 30,
        startIndex: 25,
      );

      await _pumpOverviewPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/movies/latest'), 1);
      expect(find.byType(MovieSummaryCard), findsNWidgets(24));
      expect(find.byKey(const Key('movie-summary-card-ABC-025')), findsNothing);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2800),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/movies/latest'), 2);
      expect(find.byType(MovieSummaryCard), findsNWidgets(30));
      expect(
        find.byKey(const Key('movie-summary-card-ABC-025')),
        findsOneWidget,
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/movies/latest'), 2);
    },
  );

  testWidgets(
    'desktop overview keeps existing movies and allows retry when load more fails',
    (WidgetTester tester) async {
      _enqueueStatusSuccess(bundle);
      _enqueueLatestMoviesSuccess(bundle, count: 24, total: 30);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies/latest',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'server_error',
            'message': 'server error',
          },
        },
      );

      await _pumpOverviewPage(
        tester,
        sessionStore: sessionStore,
        bundle: bundle,
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2800),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(MovieSummaryCard), findsNWidgets(24));
      expect(find.text('加载更多失败，请点击重试'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '重试'), findsOneWidget);

      _enqueueLatestMoviesSuccess(
        bundle,
        count: 6,
        page: 2,
        total: 30,
        startIndex: 25,
      );

      await tester.ensureVisible(find.widgetWithText(TextButton, '重试'));
      await tester.tap(find.widgetWithText(TextButton, '重试'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/movies/latest'), 3);
      expect(find.byType(MovieSummaryCard), findsNWidgets(30));
      expect(
        find.byKey(const Key('movie-summary-card-ABC-025')),
        findsOneWidget,
      );
      expect(find.text('加载更多失败，请点击重试'), findsNothing);
    },
  );

  testWidgets('desktop overview toggles latest movie subscription', (
    WidgetTester tester,
  ) async {
    _enqueueStatusSuccess(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/latest',
      statusCode: 200,
      body: _latestMoviesJson(count: 1, total: 1),
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABC-001/subscription',
      statusCode: 204,
    );

    await _pumpOverviewPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.hitCount('DELETE', '/movies/ABC-001/subscription'),
      1,
    );
    expect(find.text('已取消订阅影片'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpOverviewPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<MetadataProviderLicenseApi>.value(
          value: bundle.metadataProviderLicenseApi,
        ),
        Provider<StatusApi>.value(value: bundle.statusApi),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        ChangeNotifierProvider(
          create: (_) => MovieSubscriptionChangeNotifier(),
        ),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: OKToast(child: const DesktopOverviewPage()),
      ),
    ),
  );
}

void _enqueueStatusSuccess(
  TestApiBundle bundle, {
  bool enqueueLicenseStatus = true,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    statusCode: 200,
    body: _statusJson(),
  );
  _enqueueImageSearchStatusSuccess(bundle);
  if (enqueueLicenseStatus) {
    _enqueueMetadataProviderLicenseStatus(bundle);
  }
}

void _enqueueMetadataProviderLicenseStatus(
  TestApiBundle bundle, {
  bool active = true,
  String? errorCode,
  String? message,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/metadata-provider-license/status',
    statusCode: 200,
    body: <String, dynamic>{
      'configured': true,
      'active': active,
      'instance_id': 'inst_test',
      'expires_at': active ? 1777181126 : null,
      'license_valid_until': active ? 4102444800 : null,
      'renew_after_seconds': active ? 21600 : null,
      'error_code': errorCode,
      'message': message,
    },
  );
}

void _enqueueMetadataProviderLicenseConnectivity(
  TestApiBundle bundle, {
  required bool ok,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/metadata-provider-license/connectivity-test',
    statusCode: 200,
    body: <String, dynamic>{
      'ok': ok,
      'url': 'https://license.example.com/',
      'proxy_enabled': false,
      'elapsed_ms': 128,
      'status_code': ok ? 200 : null,
      'error': ok ? null : 'timeout',
    },
  );
}

void _enqueueImageSearchStatusSuccess(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    statusCode: 200,
    body: _imageSearchStatusJson(),
  );
}

void _enqueueMetadataProviderTest(
  TestApiBundle bundle, {
  required String provider,
  required bool healthy,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/metadata-providers/$provider/test',
    statusCode: 200,
    body: <String, dynamic>{
      'healthy': healthy,
      'provider': provider,
      'error':
          healthy
              ? null
              : <String, dynamic>{'message': 'metadata request failed'},
    },
  );
}

void _enqueueLatestMoviesSuccess(
  TestApiBundle bundle, {
  required int count,
  required int total,
  int page = 1,
  int pageSize = 24,
  int startIndex = 1,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/latest',
    statusCode: 200,
    body: _latestMoviesJson(
      count: count,
      total: total,
      page: page,
      pageSize: pageSize,
      startIndex: startIndex,
    ),
  );
}

Map<String, dynamic> _statusJson({int totalSizeBytes = 987654321}) {
  return <String, dynamic>{
    'actors': <String, dynamic>{'female_total': 12, 'female_subscribed': 8},
    'movies': <String, dynamic>{'total': 120, 'subscribed': 35, 'playable': 88},
    'media_files': <String, dynamic>{
      'total': 156,
      'total_size_bytes': totalSizeBytes,
    },
    'media_libraries': <String, dynamic>{'total': 3},
  };
}

Map<String, dynamic> _imageSearchStatusJson({
  bool healthy = true,
  bool joyTagHealthy = true,
  String? usedDevice = 'GPU',
  int pendingThumbnails = 23,
  int failedThumbnails = 2,
}) {
  return <String, dynamic>{
    'healthy': healthy,
    'checked_at': '2026-03-16T07:30:00Z',
    'joytag': <String, dynamic>{
      'healthy': joyTagHealthy,
      'used_device': usedDevice,
    },
    'indexing': <String, dynamic>{
      'pending_thumbnails': pendingThumbnails,
      'failed_thumbnails': failedThumbnails,
      'success_thumbnails': 15295,
    },
  };
}

Map<String, dynamic> _latestMoviesJson({
  required int count,
  required int total,
  int page = 1,
  int pageSize = 24,
  int startIndex = 1,
}) {
  return <String, dynamic>{
    'items': List<Map<String, dynamic>>.generate(
      count,
      (index) => <String, dynamic>{
        'javdb_id': 'MovieA${startIndex + index}',
        'movie_number':
            'ABC-${(startIndex + index).toString().padLeft(3, '0')}',
        'title': 'Movie ${startIndex + index}',
        'cover_image': null,
        'release_date':
            '2024-01-${((startIndex + index - 1) % 28 + 1).toString().padLeft(2, '0')}',
        'duration_minutes': 120 + startIndex + index - 1,
        'is_subscribed': index.isEven,
        'can_play': true,
      },
    ),
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}
