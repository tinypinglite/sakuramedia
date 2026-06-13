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

  testWidgets(
    'movie filter toolbar selects FC2 number source and resets to default',
    (WidgetTester tester) async {
      var filterState = MovieFilterState.initial;
      MovieFilterState? changedState;

      tester.view.physicalSize = const Size(420, 900);
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
                    yearOptions: const <MovieFilterYearOption>[],
                    onChanged: (nextState) {
                      changedState = nextState;
                      setState(() {
                        filterState = nextState;
                      });
                    },
                    onReset: () {
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

      // 默认筛选下「番号来源」分组存在且选中「全部」。
      expect(find.text('番号来源'), findsOneWidget);
      expect(filterState.numberSource, MovieNumberSourceFilter.all);

      await tester.tap(find.text('FC2'));
      await tester.pumpAndSettle();

      expect(changedState?.numberSource, MovieNumberSourceFilter.fc2);
      expect(filterState.isDefault, isFalse);
      expect(find.text('重置'), findsOneWidget);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      expect(filterState.numberSource, MovieNumberSourceFilter.all);
      expect(filterState.isDefault, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
