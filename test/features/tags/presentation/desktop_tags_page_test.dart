import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_collection_type_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/desktop_tags_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late TagsApi tagsApi;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    tagsApi = TagsApi(apiClient: bundle.apiClient);
  });

  tearDown(() {
    bundle.dispose();
  });

  Map<String, dynamic> moviesPage() => <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'javdb_id': 'MovieA1',
            'movie_number': 'ABC-001',
            'title': 'Movie 1',
            'cover_image': null,
            'release_date': '2024-01-02',
            'duration_minutes': 120,
            'is_subscribed': false,
            'can_play': true,
          },
        ],
        'page': 1,
        'page_size': 24,
        'total': 1,
      };

  List<String?> movieTagMatches() => bundle.adapter.requests
      .where((request) => request.uri.path == '/movies')
      .map((request) => request.uri.queryParameters['tag_match'])
      .toList(growable: false);

  Future<void> pumpTagsPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<MoviesApi>.value(value: bundle.moviesApi),
          Provider<TagsApi>.value(value: tagsApi),
          ChangeNotifierProvider(
            create: (_) => MovieSubscriptionChangeNotifier(),
          ),
          ChangeNotifierProvider(
            create: (_) => MovieCollectionTypeChangeNotifier(),
          ),
        ],
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            home: const Scaffold(body: DesktopTagsPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'caps popular tags to popularLimit and hides 展开全部',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/tags',
        body: <Map<String, dynamic>>[
          for (var i = 0; i < 30; i++)
            <String, dynamic>{
              'tag_id': i,
              'name': 'tag$i',
              'movie_count': 100 - i,
            },
        ],
      );

      await pumpTagsPage(tester);

      // popularLimit=15：仅展示前 15 个热门标签，更多标签靠搜索，不出现「展开全部」。
      expect(find.byKey(const Key('tags-option-14')), findsOneWidget);
      expect(find.byKey(const Key('tags-option-15')), findsNothing);
      expect(find.text('展开全部'), findsNothing);
    },
  );

  testWidgets(
    'shows all popular tags when fewer than popularLimit',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/tags',
        body: <Map<String, dynamic>>[
          for (var i = 0; i < 5; i++)
            <String, dynamic>{
              'tag_id': i,
              'name': 'tag$i',
              'movie_count': 100 - i,
            },
        ],
      );

      await pumpTagsPage(tester);

      expect(find.byKey(const Key('tags-option-4')), findsOneWidget);
      expect(find.text('展开全部'), findsNothing);
    },
  );

  testWidgets(
    'switching tag match mode reloads movies with tag_match=and',
    (WidgetTester tester) async {
      bundle.adapter
        ..enqueueJson(
          method: 'GET',
          path: '/tags',
          body: <Map<String, dynamic>>[
            <String, dynamic>{'tag_id': 1, 'name': '巨乳', 'movie_count': 100},
            <String, dynamic>{'tag_id': 2, 'name': '单体作品', 'movie_count': 80},
          ],
        )
        ..enqueueJson(method: 'GET', path: '/movies', body: moviesPage())
        ..enqueueJson(method: 'GET', path: '/movies', body: moviesPage());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
            Provider<MoviesApi>.value(value: bundle.moviesApi),
            Provider<TagsApi>.value(value: tagsApi),
            ChangeNotifierProvider(
              create: (_) => MovieSubscriptionChangeNotifier(),
            ),
            ChangeNotifierProvider(
              create: (_) => MovieCollectionTypeChangeNotifier(),
            ),
          ],
          child: OKToast(
            child: MaterialApp(
              theme: sakuraThemeData,
              home: const Scaffold(
                body: DesktopTagsPage(initialTagId: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 预选标签首拉影片默认走 or。
      expect(movieTagMatches(), <String?>['or']);

      await tester.tap(find.byKey(const Key('tags-match-and')));
      await tester.pumpAndSettle();

      // 切到「全部」后追加一次 and 请求。
      expect(movieTagMatches(), <String?>['or', 'and']);
    },
  );
}
