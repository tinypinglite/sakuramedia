import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_tab_header.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders all chip labels in order', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppMobileTabHeader(
          chips: [
            AppMobileTabChip(label: '全部', isSelected: true, onTap: () {}),
            AppMobileTabChip(label: '最新', isSelected: false, onTap: () {}),
            AppMobileTabChip(label: '热门', isSelected: false, onTap: () {}),
          ],
        ),
      ),
    );

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('最新'), findsOneWidget);
    expect(find.text('热门'), findsOneWidget);
  });

  testWidgets('tapping a chip fires its onTap callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        AppMobileTabHeader(
          chips: [
            AppMobileTabChip(
              key: const Key('chip-a'),
              label: '全部',
              isSelected: true,
              onTap: () {},
            ),
            AppMobileTabChip(
              key: const Key('chip-b'),
              label: '最新',
              isSelected: false,
              onTap: () => taps += 1,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('chip-b')));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('renders filter icon button when onFilterTap is provided', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        AppMobileTabHeader(
          chips: const [],
          filterButtonKey: const Key('filter'),
          onFilterTap: () => tapped += 1,
        ),
      ),
    );

    expect(find.byType(AppIconButton), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter')));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('hides filter icon when onFilterTap is null', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppMobileTabHeader(
          chips: [
            AppMobileTabChip(label: '全部', isSelected: true, onTap: () {}),
          ],
        ),
      ),
    );

    expect(find.byType(AppIconButton), findsNothing);
  });

  testWidgets('chip can carry trailing dimension icon', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppMobileTabHeader(
          chips: [
            AppMobileTabChip(
              label: '周榜',
              isSelected: false,
              trailingIcon: Icons.expand_more,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });
}
