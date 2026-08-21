import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/image_search/data/image_search_target.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_filter_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

void main() {
  testWidgets('search range defaults to thumbnails and can switch to plot', (
    WidgetTester tester,
  ) async {
    var filter = const ImageSearchFilterState();

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ImageSearchFilterPanel(
                filterState: filter,
                summaryText: '女优：不过滤',
                onSearchTargetChanged: (target) {
                  setState(() {
                    filter = filter.copyWith(searchTarget: target);
                  });
                },
                onCurrentMovieScopeChanged: (_) {},
                onModeChanged: (_) {},
                onSelectActors: () {},
                onSearch: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('搜索范围'), findsOneWidget);
    expect(_button(tester, '缩略图').isSelected, isTrue);
    expect(_button(tester, '剧情图').isSelected, isFalse);

    await tester.tap(find.text('剧情图'));
    await tester.pump();

    expect(filter.searchTarget, ImageSearchTarget.plot);
    expect(_button(tester, '缩略图').isSelected, isFalse);
    expect(_button(tester, '剧情图').isSelected, isTrue);
  });
}

AppButton _button(WidgetTester tester, String label) {
  return tester.widget<AppButton>(find.widgetWithText(AppButton, label));
}
