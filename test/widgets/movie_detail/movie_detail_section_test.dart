import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_section.dart';

void main() {
  testWidgets('movie detail section uses default token spacing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: MovieDetailSection(title: '系列', child: Text('Series 1')),
        ),
      ),
    );

    final padding = tester.widget<Padding>(find.byType(Padding));
    final bottomPadding = padding.padding as EdgeInsets;
    expect(
      bottomPadding.bottom,
      AppComponentTokens.defaults().movieDetailSectionGap,
    );

    final sizedBoxes =
        tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
    expect(
      sizedBoxes.any(
        (widget) =>
            widget.height ==
            AppComponentTokens.defaults().movieDetailSectionTitleGap,
      ),
      isTrue,
    );
  });
}
