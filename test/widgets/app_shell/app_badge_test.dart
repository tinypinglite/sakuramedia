import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';

void main() {
  testWidgets('app badge uses semantic colors from theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppBadge(label: '错误', tone: AppBadgeTone.error),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;
    final text = tester.widget<Text>(find.text('错误'));

    expect(decoration.color, sakuraThemeData.appColors.errorSurface);
    expect(text.style?.color, sakuraThemeData.appColors.errorForeground);
  });

  testWidgets('app badge compact size reduces vertical padding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Row(
            children: const [
              AppBadge(key: Key('regular'), label: '常规'),
              AppBadge(
                key: Key('compact'),
                label: '紧凑',
                size: AppBadgeSize.compact,
              ),
            ],
          ),
        ),
      ),
    );

    final regular = tester.widget<Container>(
      find.descendant(of: find.byKey(const Key('regular')), matching: find.byType(Container)),
    );
    final compact = tester.widget<Container>(
      find.descendant(of: find.byKey(const Key('compact')), matching: find.byType(Container)),
    );
    final regularPadding = regular.padding! as EdgeInsets;
    final compactPadding = compact.padding! as EdgeInsets;

    expect(compactPadding.vertical, lessThan(regularPadding.vertical));
  });
}
