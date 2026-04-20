import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_pill_wrap.dart';

void main() {
  testWidgets(
    'movie detail pill wrap shows empty message when items are empty',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MovieDetailPillWrap(
              items: <MovieDetailPillItem>[],
              emptyMessage: '暂无数据',
            ),
          ),
        ),
      );

      expect(find.text('暂无数据'), findsOneWidget);
    },
  );

  testWidgets(
    'movie detail pill wrap renders static items without tap handler',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(
            body: MovieDetailPillWrap(
              emptyMessage: '暂无数据',
              items: <MovieDetailPillItem>[MovieDetailPillItem(label: '单体作品')],
            ),
          ),
        ),
      );

      expect(find.text('单体作品'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    },
  );

  testWidgets(
    'movie detail pill wrap triggers tap and applies selected weight',
    (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: MovieDetailPillWrap(
              emptyMessage: '暂无数据',
              items: <MovieDetailPillItem>[
                const MovieDetailPillItem(label: '普通 1.0 GB', isSelected: true),
                MovieDetailPillItem(
                  label: '导演剪辑版 500.0 MB',
                  onTap: () {
                    tapped = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      final selectedText = tester.widget<Text>(find.text('普通 1.0 GB'));
      final unselectedText = tester.widget<Text>(find.text('导演剪辑版 500.0 MB'));

      expect(
        selectedText.style?.fontWeight,
        sakuraThemeData.appTextWeights.semibold,
      );
      expect(
        unselectedText.style?.fontWeight,
        sakuraThemeData.appTextWeights.medium,
      );
      expect(selectedText.style?.fontSize, sakuraThemeData.appTextScale.s12);

      await tester.tap(find.text('导演剪辑版 500.0 MB'));
      await tester.pump();

      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'movie detail pill wrap uses component token spacing for padding',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: MovieDetailPillWrap(
              emptyMessage: '暂无数据',
              items: const <MovieDetailPillItem>[
                MovieDetailPillItem(label: 'A'),
                MovieDetailPillItem(label: 'B'),
              ],
            ),
          ),
        ),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      final paddings =
          tester.widgetList<Padding>(find.byType(Padding)).toList();
      final pillPadding = paddings.firstWhere(
        (widget) =>
            widget.padding is EdgeInsets &&
            (widget.child is Text || widget.child is Material),
      );
      final edgeInsets = pillPadding.padding as EdgeInsets;

      expect(wrap.spacing, AppComponentTokens.defaults().movieDetailPillGap);
      expect(wrap.runSpacing, AppComponentTokens.defaults().movieDetailPillGap);
      expect(
        edgeInsets.horizontal / 2,
        AppComponentTokens.defaults().movieDetailPillHorizontalPadding,
      );
      expect(
        edgeInsets.vertical / 2,
        AppComponentTokens.defaults().movieDetailPillVerticalPadding,
      );
    },
  );

  testWidgets('movie detail pill wrap uses compact radius for pill shape', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: MovieDetailPillWrap(
            emptyMessage: '暂无数据',
            items: <MovieDetailPillItem>[MovieDetailPillItem(label: 'A')],
          ),
        ),
      ),
    );

    final pillDecoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.borderRadius != null);

    expect(pillDecoration.borderRadius, sakuraThemeData.appRadius.xsBorder);
  });
}
