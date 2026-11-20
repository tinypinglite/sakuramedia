import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_poster_cover.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/logged_in_session_store.dart';
import '../../../support/pump_with_providers.dart';
import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('FC2 番号用主封面完整展示', (tester) async {
    await _pump(
      tester,
      bundle,
      _cover(
        movieNumber: 'FC2-PPV-123',
        coverImage: const MovieImageDto(
          id: 1,
          origin: 'https://cdn.example.com/cover.jpg',
        ),
        thinCoverImage: const MovieImageDto(
          id: 2,
          origin: 'https://cdn.example.com/thin.jpg',
        ),
      ),
    );

    final image = tester.widget<MaskedImage>(find.byType(MaskedImage));
    expect(image.url, 'https://cdn.example.com/cover.jpg');
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('普通影片优先瘦封面', (tester) async {
    await _pump(
      tester,
      bundle,
      _cover(
        movieNumber: 'ABC-001',
        coverImage: const MovieImageDto(
          id: 1,
          origin: 'https://cdn.example.com/cover.jpg',
        ),
        thinCoverImage: const MovieImageDto(
          id: 2,
          origin: 'https://cdn.example.com/thin.jpg',
        ),
      ),
    );

    final image = tester.widget<MaskedImage>(find.byType(MaskedImage));
    expect(image.url, 'https://cdn.example.com/thin.jpg');
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('缺瘦封面时退回主封面完整展示', (tester) async {
    await _pump(
      tester,
      bundle,
      _cover(
        movieNumber: 'ABC-001',
        coverImage: const MovieImageDto(
          id: 1,
          origin: 'https://cdn.example.com/cover.jpg',
        ),
        thinCoverImage: null,
      ),
    );

    final image = tester.widget<MaskedImage>(find.byType(MaskedImage));
    expect(image.url, 'https://cdn.example.com/cover.jpg');
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('两图都缺失时渲染纯色占位', (tester) async {
    await _pump(
      tester,
      bundle,
      _cover(movieNumber: 'ABC-001', placeholderKeyPrefix: 'tv-movie-card'),
    );

    expect(
      find.byKey(const Key('tv-movie-card-placeholder-ABC-001')),
      findsOneWidget,
    );
    expect(find.byType(MaskedImage), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  TestApiBundle bundle,
  MoviePosterCover cover,
) {
  return pumpWithProviders(
    tester,
    bundle: bundle,
    home: Scaffold(body: SizedBox(width: 200, height: 286, child: cover)),
    physicalSize: const Size(400, 400),
  );
}

MoviePosterCover _cover({
  required String movieNumber,
  MovieImageDto? coverImage,
  MovieImageDto? thinCoverImage,
  String placeholderKeyPrefix = 'movie-summary-card',
}) {
  return MoviePosterCover(
    movie: MovieListItemDto(
      movieNumber: movieNumber,
      title: movieNumber,
      coverImage: coverImage,
      thinCoverImage: thinCoverImage,
      releaseDate: null,
      durationMinutes: 0,
      heat: 0,
      isSubscribed: false,
      canPlay: false,
    ),
    placeholderKeyPrefix: placeholderKeyPrefix,
  );
}
