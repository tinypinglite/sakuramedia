import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/overview/presentation/mobile_system_overview_page.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('mobile system overview shows grouped system information', (
    WidgetTester tester,
  ) async {
    _enqueueSystemOverviewResponses(bundle);

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-system-overview-page')),
      findsOneWidget,
    );
    expect(find.text('系统概览'), findsOneWidget);
    expect(find.text('媒体资产'), findsOneWidget);
    expect(find.text('服务健康'), findsOneWidget);
    expect(find.text('影片总数'), findsOneWidget);
    expect(find.text('JoyTag 健康'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('正常'), findsOneWidget);
  });

  testWidgets('mobile system overview retries status failure', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/status',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'server_error',
          'message': 'server error',
        },
      },
    );
    _enqueueImageSearchStatus(bundle);

    await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('系统信息加载失败，请稍后重试'), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/status'), 1);

    _enqueueSystemOverviewResponses(bundle);
    await tester.tap(
      find.byKey(const Key('mobile-system-overview-retry-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('GET', '/status'), 2);
    expect(find.text('媒体资产'), findsOneWidget);
  });

  testWidgets(
    'mobile system overview pull refresh reloads all status sources',
    (WidgetTester tester) async {
      _enqueueSystemOverviewResponses(bundle);
      _enqueueSystemOverviewResponses(bundle);

      await _pumpPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/status'), 2);
      expect(bundle.adapter.hitCount('GET', '/status/image-search'), 2);
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<StatusApi>.value(value: bundle.statusApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(body: MobileSystemOverviewPage()),
        ),
      ),
    ),
  );
}

void _enqueueSystemOverviewResponses(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status',
    statusCode: 200,
    body: _statusJson(),
  );
  _enqueueImageSearchStatus(bundle);
}

void _enqueueImageSearchStatus(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/status/image-search',
    statusCode: 200,
    body: <String, dynamic>{
      'healthy': true,
      'joytag': <String, dynamic>{'healthy': true, 'used_device': 'GPU'},
      'indexing': <String, dynamic>{
        'pending_thumbnails': 23,
        'failed_thumbnails': 2,
      },
    },
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
