import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movies/movie_filter_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'movie filter toolbar constrains long year list and keeps reset visible',
    (WidgetTester tester) async {
      final yearOptions = List<MovieFilterYearOption>.generate(
        30,
        (index) => MovieFilterYearOption(year: 2026 - index, movieCount: 1),
      );
      var filterState = MovieFilterState.initial.copyWith(year: 2026);
      MovieFilterState? changedState;
      var resetCount = 0;

      tester.view.physicalSize = const Size(360, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return MovieFilterToolbar(
                    filterState: filterState,
                    yearOptions: yearOptions,
                    onChanged: (nextState) {
                      changedState = nextState;
                      setState(() {
                        filterState = nextState;
                      });
                    },
                    onReset: () {
                      resetCount += 1;
                      setState(() {
                        filterState = MovieFilterState.initial;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('movies-filter-panel')), findsOneWidget);
      expect(
        find.byKey(const Key('movies-filter-scroll-view')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const Key('movies-filter-panel'))).height,
        lessThanOrEqualTo(420),
      );
      expect(find.text('重置'), findsOneWidget);

      final scrollable = find.descendant(
        of: find.byKey(const Key('movies-filter-scroll-view')),
        matching: find.byType(Scrollable),
      );

      await tester.scrollUntilVisible(
        find.text('1997(1)'),
        160,
        scrollable: scrollable,
      );
      await tester.tap(find.text('1997(1)'));
      await tester.pumpAndSettle();

      expect(changedState?.year, 1997);
      expect(find.text('重置'), findsOneWidget);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      expect(resetCount, 1);
      expect(filterState.year, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
