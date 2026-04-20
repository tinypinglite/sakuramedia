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

  testWidgets('app button xxSmall and xxxSmall use smaller tokens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Column(
            children: [
              AppButton(
                label: '更小',
                icon: const Icon(Icons.remove),
                size: AppButtonSize.xxSmall,
                onPressed: () {},
              ),
              AppButton(
                label: '最小',
                icon: const Icon(Icons.close),
                size: AppButtonSize.xxxSmall,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final containers = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(
      tester.getSize(find.byWidget(containers.first)).height,
      AppComponentTokens.defaults().buttonHeight2xs,
    );
    expect(
      tester.getSize(find.byWidget(containers.last)).height,
      AppComponentTokens.defaults().buttonHeight3xs,
    );

    final xxSmallIconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.remove),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(
      xxSmallIconTheme.data.size,
      AppComponentTokens.defaults().iconSize2xs,
    );

    final xxxSmallIconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.close),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(
      xxxSmallIconTheme.data.size,
      AppComponentTokens.defaults().iconSize3xs,
    );

    final labels = tester.widgetList<Text>(find.textContaining('小')).toList();
    expect(labels.first.style?.fontSize, sakuraThemeData.appTextScale.s10);
    expect(labels.last.style?.fontSize, sakuraThemeData.appTextScale.s10);
    expect(labels.first.style?.height, 1);
    expect(
      labels.first.style?.leadingDistribution,
      TextLeadingDistribution.even,
    );
    expect(labels.last.style?.height, 1);
    expect(
      labels.last.style?.leadingDistribution,
      TextLeadingDistribution.even,
    );
  });

  testWidgets('app button uses mobile typography and size tokens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: AppButton(
            label: '保存',
            size: AppButtonSize.medium,
            onPressed: () {},
          ),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('保存'));

    expect(
      tester.getSize(find.byType(AnimatedContainer).first).height,
      sakuraMobileThemeData.appComponentTokens.buttonHeightMd,
    );
    expect(label.style?.fontSize, sakuraMobileThemeData.appTextScale.s14);
  });
}
