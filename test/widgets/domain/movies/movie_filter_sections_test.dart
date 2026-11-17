import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_interaction_filter_options_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  testWidgets('interaction filter group follows the stats capability', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(statsEnabled: false));

    expect(
      find.byKey(const Key('movie-filter-interaction-group-title')),
      findsNothing,
    );

    await tester.pumpWidget(_wrap(statsEnabled: true));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-filter-interaction-group-title')),
      findsOneWidget,
    );
  });
}

Widget _wrap({required bool statsEnabled}) {
  return ProviderScope(
    overrides: [
      statsFeaturesEnabledProvider.overrideWithValue(statsEnabled),
      movieInteractionFilterOptionsProvider.overrideWith(
        (ref) async => testInteractionFilterOptions,
      ),
    ],
    child: MaterialApp(
      theme: sakuraThemeData,
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: MovieFilterSectionGroup(
            filterState: MovieFilterState.initial,
            onChanged: (_) {},
          ),
        ),
      ),
    ),
  );
}
