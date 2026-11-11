import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';
import '../support/test_api_bundle.dart';

void main() {
  testWidgets(
    'primary navigation preserves scroll, data and active refresh; logout releases pages',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1100, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = SessionStore.inMemory();
      await session.saveBaseUrl('https://api.example.com');
      await session.saveTokens(
        accessToken: 'test',
        refreshToken: 'test',
        expiresAt: DateTime(2099),
      );
      final bundle = await createTestApiBundle(session);
      addTearDown(bundle.dispose);
      void enqueueMovies() => bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/movies',
        body: {
          'items': List.generate(
            40,
            (i) => {
              'movie_number': 'ABC-${i.toString().padLeft(3, '0')}',
              'title': '影片 $i',
              'cover_image': null,
              'release_date': '2024-01-02',
              'duration_minutes': 120,
              'is_subscribed': false,
              'can_play': true,
            },
          ),
          'page': 1,
          'page_size': 40,
          'total': 40,
        },
      );
      enqueueMovies();
      bundle.adapter.enqueueJson(method: 'GET', path: '/playlists', body: []);
      final router = buildDesktopRouter(sessionStore: session)
        ..go(desktopMoviesPath);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: bundle.riverpodOverrides(),
          child: MaterialApp.router(
            theme: sakuraThemeData,
            locale: const Locale('zh'),
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            builder: (context, child) =>
                OKToast(child: child ?? const SizedBox.shrink()),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final movieScroll = find.byKey(
        const PageStorageKey<String>('desktop:movies:list'),
      );
      final scrollable = find
          .descendant(of: movieScroll, matching: find.byType(Scrollable))
          .first;
      final original = tester.state<ScrollableState>(scrollable);
      original.position.jumpTo(500);
      await tester.pumpAndSettle();
      final offset = original.position.pixels;
      expect(offset, greaterThan(0));
      router.go(desktopPlaylistsPath);
      await tester.pumpAndSettle();
      final playlistRequests = bundle.adapter.hitCount('GET', '/playlists');
      expect(playlistRequests, 1);
      router.go(desktopMoviesPath);
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable), same(original));
      expect(original.position.pixels, offset);
      expect(bundle.adapter.hitCount('GET', '/movies'), 1);
      // A detail remains on the outer shell stack, then returns to the same list.
      router.push('/desktop/library/movies/ABC-000');
      await tester.pumpAndSettle();
      router.pop();
      await tester.pump();
      // 侧栏选中态动画结束后，原实现仍会继续播 180ms 的壳层边距过渡。
      await tester.pump(const Duration(milliseconds: 130));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable), same(original));
      expect(original.position.pixels, offset);
      enqueueMovies();
      await tester.tap(find.byKey(const Key('topbar-refresh-button')));
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('GET', '/movies'), 2);
      expect(bundle.adapter.hitCount('GET', '/playlists'), playlistRequests);
      router.go(desktopPlaylistsPath);
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('GET', '/playlists'), playlistRequests);
      await session.clearSession();
      await tester.pumpAndSettle();
      expect(original.mounted, isFalse);
    },
  );
}
