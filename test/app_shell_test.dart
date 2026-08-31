import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';

import 'support/test_api_bundle.dart';

void main() {
  testWidgets(
    'desktop app boots with overview stats and recent movies section',
    (WidgetTester tester) async {
      final sessionStore = await _buildLoggedInSessionStore();
      final bundle = await createTestApiBundle(sessionStore);
      addTearDown(bundle.dispose);
      // overview 页 sliver 化后靠视口惰性 build；默认 800×600 装不下
      // SystemDiagnosticsStrip + stats + xxl 间距，'最近添加' sliver 会
      // 落在视口外不构建。撑高视口让所有 sliver 同时进 cacheExtent。
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      _enqueueOverviewResponses(bundle);

      await _pumpDesktopApp(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(find.text('SakuraMedia'), findsNothing);
      expect(find.text('SA'), findsNothing);
      expect(find.text('概览'), findsWidgets);
      expect(find.text('影片'), findsWidgets);
      expect(find.text('女优'), findsWidgets);
      expect(find.text('播放列表'), findsWidgets);
      expect(find.text('系统信息'), findsOneWidget);
      expect(find.text('最近添加'), findsOneWidget);
      expect(find.text('ABC-001'), findsOneWidget);
      expect(
        find.byKey(const Key('overview-stat-movies-total')),
        findsOneWidget,
      );
    },
  );
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

Future<void> _pumpDesktopApp(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) async {
  final router = buildDesktopRouter(sessionStore: sessionStore);
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    ),
  );
}

void _enqueueOverviewResponses(TestApiBundle bundle) {
  // Riverpod 迁移后：/status 至少被两个消费方触发（概览统计条 +
  // 侧边栏版本行的 appVersionInfoProvider.load），用 fallback 兜住多次调用。
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/status',
    body: <String, dynamic>{
      'backend_version': 'v0.2.0',
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
      'items': [
        <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABC-001',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': '2024-01-02',
          'duration_minutes': 120,
          'is_subscribed': true,
          'can_play': true,
        },
      ],
      'page': 1,
      'page_size': 8,
      'total': 1,
    },
  );
}
