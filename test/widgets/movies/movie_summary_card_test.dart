import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_card.dart';

void main() {
  test(
    'movie summary card uses tokens for media colors and component sizing',
    () {
      final source =
          File('lib/widgets/movies/movie_summary_card.dart').readAsStringSync();

      expect(source, contains('context.appComponentTokens'));
      expect(source, contains('colors.textOnMedia'));
      expect(source, contains('colors.mediaOverlaySoft'));
      expect(source, contains('colors.mediaOverlayStrong'));
      expect(source, contains('colors.subscriptionHeartIcon'));
      expect(source, contains('colors.movieCardPlayableBadgeBackground'));
      expect(source, isNot(contains('Colors.white')));
      expect(source, isNot(contains('Colors.black')));
      expect(source, isNot(contains('withValues(alpha: 0.92)')));
      expect(source, contains('movieCardCoverVisibleWidthFactor'));
      expect(source, isNot(contains('0.47')));
      expect(source, isNot(contains('size: 36')));
      expect(source, isNot(contains('size: 32')));
      expect(source, isNot(contains('width: 18')));
      expect(source, isNot(contains('height: 18')));
      expect(source, isNot(contains('strokeWidth: 2')));
      expect(source, isNot(contains('width: 28')));
      expect(source, isNot(contains('height: 28')));
      expect(source, isNot(contains('size: 16')));
    },
  );

  testWidgets('movie summary card uses poster-only presentation', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: MovieListItemDto(
                  javdbId: 'MovieA1',
                  movieNumber: 'ABC-001',
                  title: 'Movie 1',
                  coverImage: const MovieImageDto(
                    id: 1,
                    origin: '/poster-origin.jpg',
                    small: '/poster-small.jpg',
                    medium: '/poster-medium.jpg',
                    large: '/poster-large.jpg',
                  ),
                  releaseDate: DateTime(2024, 1, 1),
                  durationMinutes: 120,
                  isSubscribed: true,
                  canPlay: true,
                ),
                onSubscriptionTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ABC-001'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-summary-card-status-playable-ABC-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-summary-card-subscription-ABC-001')),
      findsOneWidget,
    );
    expect(find.text('Movie 1'), findsNothing);
    expect(find.text('2024-01-01'), findsNothing);
    expect(find.text('120 分钟'), findsNothing);
    expect(find.byType(MaskedImage), findsOneWidget);

    final maskedImage = tester.widget<MaskedImage>(find.byType(MaskedImage));
    expect(
      maskedImage.visibleWidthFactor,
      AppComponentTokens.defaults().movieCardCoverVisibleWidthFactor,
    );
    expect(maskedImage.visibleAlignment, Alignment.centerRight);

    final playableBadgeContainer = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('movie-summary-card-status-playable-ABC-001')),
        matching: find.byType(Container),
      ),
    );
    final playableBadgeDecoration =
        playableBadgeContainer.decoration as BoxDecoration;
    expect(
      playableBadgeDecoration.color,
      AppColors.defaults().movieCardPlayableBadgeBackground,
    );

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(
      icons.where((icon) => icon.icon == Icons.play_arrow_rounded).single.color,
      AppColors.defaults().textOnMedia,
    );
    final subscriptionIcon =
        icons.where((icon) => icon.icon == Icons.favorite_rounded).single;
    expect(subscriptionIcon.color, AppColors.defaults().subscriptionHeartIcon);
    expect(subscriptionIcon.size, AppComponentTokens.defaults().iconSizeXl);
  });

  testWidgets(
    'movie summary card shows poster placeholder when image missing',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: MovieListItemDto(
                    javdbId: 'MovieA2',
                    movieNumber: 'ABC-002',
                    title: 'Movie 2',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    isSubscribed: false,
                    canPlay: false,
                  ),
                  onSubscriptionTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('movie-summary-card-placeholder-ABC-002')),
        findsOneWidget,
      );
      expect(find.byType(MaskedImage), findsNothing);
      expect(find.text('ABC-002'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-summary-card-subscription-ABC-002')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'movie summary card shows loading indicator while subscription updates',
    (WidgetTester tester) async {
      final sessionStore = SessionStore.inMemory();
      await sessionStore.saveBaseUrl('https://api.example.com');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          ],
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: MovieSummaryCard(
                  movie: MovieListItemDto(
                    javdbId: 'MovieA3',
                    movieNumber: 'ABC-003',
                    title: 'Movie 3',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 0,
                    isSubscribed: true,
                    canPlay: false,
                  ),
                  onSubscriptionTap: () {},
                  isSubscriptionUpdating: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const Key('movie-summary-card-subscription-loading-ABC-003'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('movie summary card forwards secondary tap menu position', (
    WidgetTester tester,
  ) async {
    Offset? menuPosition;
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: const MovieListItemDto(
                  javdbId: 'MovieA4',
                  movieNumber: 'OFJE-888',
                  title: 'Movie 4',
                  coverImage: null,
                  releaseDate: null,
                  durationMinutes: 0,
                  isSubscribed: false,
                  canPlay: false,
                ),
                onRequestMenu: (position) => menuPosition = position,
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(
      find.byKey(const Key('movie-summary-card-OFJE-888')),
    );
    await tester.tapAt(center, buttons: kSecondaryMouseButton);
    await tester.pump();

    expect(menuPosition, equals(center));
  });

  testWidgets('movie summary card forwards long press menu position', (
    WidgetTester tester,
  ) async {
    Offset? menuPosition;
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ],
        child: MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: MovieSummaryCard(
                movie: const MovieListItemDto(
                  javdbId: 'MovieA5',
                  movieNumber: 'OFJE-889',
                  title: 'Movie 5',
                  coverImage: null,
                  releaseDate: null,
                  durationMinutes: 0,
                  isSubscribed: false,
                  canPlay: false,
                ),
                onRequestMenu: (position) => menuPosition = position,
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(
      find.byKey(const Key('movie-summary-card-OFJE-889')),
    );
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout);
    await gesture.up();

    expect(menuPosition, equals(center));
  });
}
