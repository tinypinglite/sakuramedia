import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageRoute;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_back_overlay.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface_readiness.dart';

void main() {
  group('MoviePlayerBackButton', () {
    testWidgets('uses transparent material without elevation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: Scaffold(body: MoviePlayerBackButton(onPressed: () {})),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(MoviePlayerBackButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.type, MaterialType.transparency);
      expect(material.elevation, 0);
      expect(material.color, isNull);
    });
  });

  group('MoviePlayerInfoButton', () {
    testWidgets('renders stable key and triggers callback', (
      WidgetTester tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: Scaffold(
            body: MoviePlayerInfoButton(
              onPressed: () {
                tapped += 1;
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('movie-player-info-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('movie-player-info-button')));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('uses transparent material without elevation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: Scaffold(body: MoviePlayerInfoButton(onPressed: () {})),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(MoviePlayerInfoButton),
          matching: find.byType(Material),
        ),
      );

      expect(material.type, MaterialType.transparency);
      expect(material.elevation, 0);
      expect(material.color, isNull);
    });
  });

  group('MoviePlayerCurrentNumberBadge', () {
    testWidgets('renders trimmed movie number with a stable key', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerCurrentNumberBadge(movieNumber: '  ABP-123  '),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-player-current-number')),
        findsOneWidget,
      );
      expect(find.text('ABP-123'), findsOneWidget);
    });

    testWidgets('keeps single-line ellipsis text behavior', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerCurrentNumberBadge(
              movieNumber: 'ABP-123-VERY-LONG-CURRENT-PLAYING-NUMBER',
            ),
          ),
        ),
      );

      final numberText = tester.widget<Text>(find.textContaining('ABP-123'));
      expect(numberText.maxLines, 1);
      expect(numberText.overflow, TextOverflow.ellipsis);
      expect(numberText.softWrap, isFalse);
    });

    testWidgets('uses transparent material without elevation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerCurrentNumberBadge(movieNumber: 'ABP-123'),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(MoviePlayerCurrentNumberBadge),
          matching: find.byType(Material),
        ),
      );

      expect(material.type, MaterialType.transparency);
      expect(material.elevation, 0);
      expect(material.color, isNull);
    });
  });

  group('MoviePlayerBackOverlay', () {
    testWidgets('stays a small top-left button even under forced-fill '
        '(StackFit.expand) constraints', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  MoviePlayerBackOverlay(onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      final backSize = tester.getSize(
        find.byKey(const Key('movie-player-back-button')),
      );
      // 回归守卫：tight 约束下若未收口，按钮会被撑满（≈800×600）、箭头居中。
      expect(backSize.width, lessThan(100));
      expect(backSize.height, lessThan(100));

      final backTopLeft = tester.getTopLeft(
        find.byKey(const Key('movie-player-back-button')),
      );
      expect(backTopLeft.dx, lessThan(60));
      expect(backTopLeft.dy, lessThan(80));
    });
  });

  group('PlayerSwipeBackGuard', () {
    testWidgets('blocks edge-swipe pop but forwards system back', (
      WidgetTester tester,
    ) async {
      var backCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  key: const Key('open-player'),
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (routeContext) {
                          return PlayerSwipeBackGuard(
                            onBack: () {
                              backCount += 1;
                              Navigator.of(routeContext).pop();
                            },
                            child: const Scaffold(
                              body: Center(child: Text('player-page')),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-player')));
      await tester.pumpAndSettle();
      expect(find.text('player-page'), findsOneWidget);

      final edgeSwipe = await tester.startGesture(const Offset(1, 300));
      await edgeSwipe.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 20));
      await edgeSwipe.moveBy(const Offset(600, 0));
      await edgeSwipe.up();
      await tester.pumpAndSettle();

      expect(find.text('player-page'), findsOneWidget);
      expect(backCount, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(backCount, 1);
      expect(find.text('player-page'), findsNothing);
    });
  });

  group('wrapWithMoviePlayerBackButton', () {
    testWidgets('renders child plus a tappable top-left back button', (
      WidgetTester tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: Scaffold(
            body: wrapWithMoviePlayerBackButton(
              onBackPressed: () => tapped += 1,
              backButtonKey: const Key('unit-back-overlay'),
              child: const Center(child: Text('loading-content')),
            ),
          ),
        ),
      );

      expect(find.text('loading-content'), findsOneWidget);
      expect(find.byKey(const Key('unit-back-overlay')), findsOneWidget);

      await tester.tap(find.byKey(const Key('movie-player-back-button')));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  group('MoviePlayerSurfaceFrame', () {
    testWidgets('shows back button over the not-ready mask and hides it once '
        'ready', (WidgetTester tester) async {
      Widget frame(bool isReady) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        theme: sakuraThemeData,
        home: Scaffold(
          body: MoviePlayerSurfaceFrame(
            isReady: isReady,
            onBackPressed: () {},
            child: const Text('player'),
          ),
        ),
      );

      await tester.pumpWidget(frame(false));
      expect(
        find.byKey(const Key('movie-player-surface-ready-mask')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('movie-player-back-button')), findsOneWidget);

      await tester.pumpWidget(frame(true));
      expect(
        find.byKey(const Key('movie-player-surface-ready-mask')),
        findsNothing,
      );
      expect(find.byKey(const Key('movie-player-back-button')), findsNothing);
    });

    testWidgets('omits back button when onBackPressed is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MoviePlayerSurfaceFrame(
              isReady: false,
              child: Text('player'),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-player-surface-ready-mask')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('movie-player-back-button')), findsNothing);
    });
  });

  group('MoviePlayerBackWithNumberControl', () {
    testWidgets('keeps number badge immediately after back button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraThemeData,
          home: Scaffold(
            body: MoviePlayerBackWithNumberControl(
              onPressed: () {},
              movieNumber: 'SNOS-148',
            ),
          ),
        ),
      );

      final backRect = tester.getRect(
        find.byKey(const Key('movie-player-back-button')),
      );
      final numberRect = tester.getRect(
        find.byKey(const Key('movie-player-current-number')),
      );

      expect(numberRect.left - backRect.right, closeTo(2, 0.01));
      expect(backRect.left, lessThan(numberRect.left));
    });
  });
}
