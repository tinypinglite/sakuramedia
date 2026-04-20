import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';

void main() {
  testWidgets('filter total header uses button height for total container', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Material(
          child: AppFilterTotalHeader(
            leading: SizedBox(height: 32, child: Text('筛选')),
            totalText: '34 位',
            totalKey: Key('header-total'),
          ),
        ),
      ),
    );

    final totalContainer = tester.widget<SizedBox>(
      find.ancestor(
        of: find.byKey(const Key('header-total')),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height != null,
        ),
      ),
    );

    expect(
      totalContainer.height,
      sakuraThemeData.appComponentTokens.buttonHeightSm,
    );
  });

  testWidgets('filter total header centers total text within the first row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Material(
          child: AppFilterTotalHeader(
            leading: SizedBox(height: 32, child: Text('筛选')),
            totalText: '34 位',
            totalKey: Key('header-total'),
          ),
        ),
      ),
    );

    final totalContainerRect = tester.getRect(
      find.ancestor(
        of: find.byKey(const Key('header-total')),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height != null,
        ),
      ),
    );
    final totalTextRect = tester.getRect(find.byKey(const Key('header-total')));

    expect(
      totalTextRect.center.dy,
      moreOrLessEquals(totalContainerRect.center.dy, epsilon: 0.5),
    );
  });

  testWidgets(
    'filter total header keeps total container in the first row when leading wraps',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 260,
                child: AppFilterTotalHeader(
                  leading: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(
                      6,
                      (index) => Container(
                        width: 72,
                        height: 32,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                  totalText: '34 位',
                  totalKey: const Key('header-total'),
                ),
              ),
            ),
          ),
        ),
      );

      final headerRect = tester.getRect(find.byType(AppFilterTotalHeader));
      final totalContainerRect = tester.getRect(
        find.ancestor(
          of: find.byKey(const Key('header-total')),
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.height != null,
          ),
        ),
      );
      final leadingRect = tester.getRect(find.byType(Wrap));

      expect(totalContainerRect.top, headerRect.top);
      expect(
        totalContainerRect.bottom,
        moreOrLessEquals(
          headerRect.top + sakuraThemeData.appComponentTokens.buttonHeightSm,
          epsilon: 0.5,
        ),
      );
      expect(
        leadingRect.bottom,
        greaterThan(
          headerRect.top + sakuraThemeData.appComponentTokens.buttonHeightSm,
        ),
      );
    },
  );
}
