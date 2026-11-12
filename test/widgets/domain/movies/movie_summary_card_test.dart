import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';

void main() {
  testWidgets('heat badge follows the stats capability', (tester) async {
    await tester.pumpWidget(_wrap(statsEnabled: false));

    expect(
      find.byKey(const Key('movie-summary-card-heat-ABC-001')),
      findsNothing,
    );

    await tester.pumpWidget(_wrap(statsEnabled: true));

    expect(
      find.byKey(const Key('movie-summary-card-heat-ABC-001')),
      findsOneWidget,
    );
  });
}

Widget _wrap({required bool statsEnabled}) {
  return ProviderScope(
    overrides: [statsFeaturesEnabledProvider.overrideWithValue(statsEnabled)],
    child: MaterialApp(
      theme: sakuraThemeData,
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 220,
            height: 320,
            child: MovieSummaryCard(
              movie: MovieListItemDto(
                id: 1,
                movieNumber: 'ABC-001',
                title: 'Movie',
                coverImage: null,
                releaseDate: DateTime(2024, 1, 2),
                durationMinutes: 120,
                heat: 100,
                isSubscribed: false,
                canPlay: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
