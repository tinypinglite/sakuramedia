import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_similar_movie_strip.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

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
    sessionStore.dispose();
  });

  testWidgets('similar movie card uses the shared subscription action', (
    WidgetTester tester,
  ) async {
    var movieTapCount = 0;
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/SIM-001/subscription',
      statusCode: 204,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: OKToast(
          child: MaterialApp(
            theme: sakuraThemeData,
            home: Scaffold(
              body: MovieSimilarMovieStrip(
                movies: const <MovieListItemDto>[
                  MovieListItemDto(
                    javdbId: 'SimilarA1',
                    movieNumber: 'SIM-001',
                    title: 'Similar Movie',
                    coverImage: null,
                    releaseDate: null,
                    durationMinutes: 120,
                    heat: 12,
                    isSubscribed: false,
                    canPlay: false,
                  ),
                ],
                isLoading: false,
                onMovieTap: (_) => movieTapCount += 1,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('movie-summary-card-SIM-001'))) +
          const Offset(16, 16),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(movieTapCount, 0);
    expect(bundle.adapter.hitCount('PUT', '/movies/SIM-001/subscription'), 1);
    await tester.pump(const Duration(seconds: 3));
  });
}
