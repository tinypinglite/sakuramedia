import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_sort_menu_button.dart';

void main() {
  testWidgets('影片排序切换字段时清空个人评分维度', (tester) async {
    final state = MovieFilterState.initial.copyWith(
      sortField: MovieSortField.myScore,
      dimensionSortId: 7,
    );
    MovieFilterState? applied;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              height: 44,
              child: MovieSortMenuButton(
                triggerKey: const Key('movies-sort-trigger'),
                panelKey: const Key('movies-sort-panel'),
                filterState: state,
                onChanged: (next) => applied = next,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('movies-sort-trigger')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('热度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('热度'));
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
    expect(applied!.sortField, MovieSortField.heat);
    expect(applied!.dimensionSortId, isNull);
  });
}
