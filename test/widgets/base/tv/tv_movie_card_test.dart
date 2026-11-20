import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_card.dart';
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

  testWidgets('TV 影片卡常显番号、标题、订阅状态、清晰度与热度', (tester) async {
    await _pumpCard(tester, bundle, statsEnabled: true);

    expect(
      find.byKey(const Key('tv-movie-card-number-ABC-001')),
      findsOneWidget,
    );
    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text('示例影片'), findsOneWidget);
    expect(
      find.byKey(const Key('tv-movie-card-subscription-ABC-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tv-movie-card-resolution-ABC-001')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('tv-movie-card-heat-ABC-001')), findsOneWidget);
    expect(find.text(formatAppCompactCount(1234)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('没有热度来源时 TV 影片卡不画热度角标', (tester) async {
    await _pumpCard(tester, bundle, statsEnabled: false);

    expect(find.byKey(const Key('tv-movie-card-heat-ABC-001')), findsNothing);
    expect(find.text(formatAppCompactCount(1234)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('非 4K 可播放影片显示可播放标而不是清晰度标', (tester) async {
    await _pumpCard(tester, bundle, statsEnabled: true, maxMediaWidth: 1920);

    expect(
      find.byKey(const Key('tv-movie-card-status-playable-ABC-001')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tv-movie-card-resolution-ABC-001')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV 影片卡复用封面选择：FC2 用主封面完整展示', (tester) async {
    await _pumpCard(
      tester,
      bundle,
      statsEnabled: false,
      movie: _movie(
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
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  TestApiBundle bundle, {
  required bool statsEnabled,
  int maxMediaWidth = 3840,
  MovieListItemDto? movie,
}) async {
  await pumpWithProviders(
    tester,
    bundle: bundle,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          height: 286,
          child: TvMovieCard(
            movie: movie ?? _movie(maxMediaWidth: maxMediaWidth),
            onPressed: () {},
          ),
        ),
      ),
    ),
    theme: buildSakuraTvThemeData(),
    physicalSize: const Size(400, 400),
    overrides: <Override>[
      statsFeaturesEnabledProvider.overrideWithValue(statsEnabled),
    ],
  );
}

MovieListItemDto _movie({
  int maxMediaWidth = 3840,
  String movieNumber = 'ABC-001',
  MovieImageDto? coverImage,
  MovieImageDto? thinCoverImage,
}) {
  return MovieListItemDto(
    movieNumber: movieNumber,
    title: '示例影片',
    seriesName: '示例系列',
    coverImage: coverImage,
    thinCoverImage: thinCoverImage,
    releaseDate: DateTime(2024, 1, 2),
    durationMinutes: 120,
    heat: 1234,
    isSubscribed: true,
    canPlay: true,
    maxMediaWidth: maxMediaWidth,
  );
}
