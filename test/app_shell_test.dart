import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_state.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
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
      _enqueueOverviewResponses(bundle);

      await _pumpDesktopApp(
        tester,
        sessionStore: sessionStore,
        statusApi: bundle.statusApi,
        moviesApi: bundle.moviesApi,
      );
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
  required StatusApi statusApi,
  required MoviesApi moviesApi,
}) async {
  final router = buildDesktopRouter(sessionStore: sessionStore);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ChangeNotifierProvider(create: (_) => AppShellController()),
        Provider<StatusApi>.value(value: statusApi),
        Provider<MoviesApi>.value(value: moviesApi),
      ],
      child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
    ),
  );
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
