import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app button renders trailing icon and selected state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppButton(
            label: '已订阅',
            icon: const Icon(Icons.filter_alt_outlined),
            trailingIcon: const Icon(Icons.expand_more),
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            isSelected: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('已订阅'), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, isNotNull);
    expect(decoration.border, isNotNull);

    final leadingIconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.filter_alt_outlined),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(
      leadingIconTheme.data.size,
      AppComponentTokens.defaults().iconSizeSm,
    );
    final trailingIconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.expand_more),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(
      trailingIconTheme.data.size,
      AppComponentTokens.defaults().iconSizeSm,
    );
  });

  testWidgets('app button xSmall uses xs icon token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppButton(
            label: '筛选',
            icon: const Icon(Icons.tune_rounded),
            size: AppButtonSize.xSmall,
            onPressed: () {},
          ),
        ),
      ),
    );

    final iconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.tune_rounded),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(iconTheme.data.size, AppComponentTokens.defaults().iconSizeXs);
  });
}
