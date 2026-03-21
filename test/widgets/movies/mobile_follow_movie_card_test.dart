import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/movies/mobile_follow_movie_card.dart';

void main() {
  testWidgets('mobile follow movie card cover uses fixed visible anchor', (
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
              width: 360,
              child: MobileFollowMovieCard(
                movie: MovieListItemDto(
                  javdbId: 'movie-1',
                  movieNumber: 'ABP-100',
                  title: 'Movie 100',
                  coverImage: const MovieImageDto(
                    id: 1,
                    origin: '/cover-origin.jpg',
                    small: '/cover-small.jpg',
                    medium: '/cover-medium.jpg',
                    large: '/cover-large.jpg',
                  ),
                  releaseDate: DateTime(2024, 1, 1),
                  durationMinutes: 120,
                  isSubscribed: true,
                  canPlay: true,
                ),
                onTap: () {},
                onSubscriptionTap: () {},
                isSubscriptionUpdating: false,
                isDetailLoading: false,
                detailStillImageUrls: const <String>[],
                detailSummary: null,
                detailThinCoverUrl: null,
              ),
            ),
          ),
        ),
      ),
    );

    final maskedImage = tester.widget<MaskedImage>(find.byType(MaskedImage));
    expect(
      maskedImage.visibleWidthFactor,
      AppComponentTokens.defaults().movieCardCoverVisibleWidthFactor,
    );
    expect(maskedImage.visibleAlignment, Alignment.centerRight);
  });

  testWidgets(
    'mobile follow movie card shows placeholder when cover image missing',
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
                width: 360,
                child: MobileFollowMovieCard(
                  movie: MovieListItemDto(
                    javdbId: 'movie-2',
                    movieNumber: 'ABP-101',
                    title: 'Movie 101',
                    coverImage: null,
                    releaseDate: DateTime(2024, 1, 1),
                    durationMinutes: 120,
                    isSubscribed: false,
                    canPlay: false,
                  ),
                  onTap: () {},
                  onSubscriptionTap: () {},
                  isSubscriptionUpdating: false,
                  isDetailLoading: false,
                  detailStillImageUrls: const <String>[],
                  detailSummary: null,
                  detailThinCoverUrl: null,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const Key('mobile-follow-movie-card-cover-placeholder-ABP-101'),
        ),
        findsOneWidget,
      );
      expect(find.byType(MaskedImage), findsNothing);
    },
  );
}
