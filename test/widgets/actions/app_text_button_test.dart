import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app text button renders selected and unselected states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Column(
            children: [
              AppTextButton(label: '最新', isSelected: true, onPressed: () {}),
              AppTextButton(label: '最早', onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    final containers = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final selectedDecoration = containers.first.decoration! as BoxDecoration;
    final unselectedDecoration = containers.last.decoration! as BoxDecoration;
    final labels = tester.widgetList<Text>(find.byType(Text)).toList();

    expect(
      selectedDecoration.color,
      sakuraThemeData.colorScheme.primary.withValues(alpha: 0.08),
    );
    expect(unselectedDecoration.color, Colors.transparent);
    expect(labels.first.style?.color, sakuraThemeData.appTextPalette.accent);
    expect(labels.last.style?.color, sakuraThemeData.appTextPalette.muted);
  });

  testWidgets('app text button supports muted background style', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Column(
            children: [
              AppTextButton(
                label: '全部',
                backgroundStyle: AppTextButtonBackgroundStyle.muted,
                onPressed: () {},
              ),
              AppTextButton(
                label: '最新订阅',
                backgroundStyle: AppTextButtonBackgroundStyle.muted,
                isSelected: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final containers = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    final mutedDecoration = containers.first.decoration! as BoxDecoration;
    final selectedDecoration = containers.last.decoration! as BoxDecoration;

    expect(mutedDecoration.color, sakuraThemeData.appColors.surfaceMuted);
    expect(
      selectedDecoration.color,
      sakuraThemeData.colorScheme.primary.withValues(alpha: 0.08),
    );
  });

  testWidgets('app text button maps compact sizes to token values', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Column(
            children: [
              AppTextButton(
                label: '小',
                size: AppTextButtonSize.small,
                onPressed: () {},
              ),
              AppTextButton(
                label: '极小',
                size: AppTextButtonSize.xxSmall,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final containers = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    final labels = tester.widgetList<Text>(find.byType(Text)).toList();

    expect(
      tester.getSize(find.byWidget(containers.first)).height,
      sakuraThemeData.appComponentTokens.buttonHeightSm,
    );
    expect(
      tester.getSize(find.byWidget(containers.last)).height,
      sakuraThemeData.appComponentTokens.buttonHeight2xs,
    );
    expect(labels.first.style?.fontSize, sakuraThemeData.appTextScale.s14);
    expect(labels.last.style?.fontSize, sakuraThemeData.appTextScale.s10);
    expect(labels.last.style?.height, 1);
    expect(
      labels.last.style?.leadingDistribution,
      TextLeadingDistribution.even,
    );
  });

  testWidgets('app text button uses mobile theme tokens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraMobileThemeData,
        home: Scaffold(
          body: AppTextButton(
            label: '切换',
            size: AppTextButtonSize.xSmall,
            onPressed: () {},
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final label = tester.widget<Text>(find.text('切换'));

    expect(
      tester.getSize(find.byWidget(container)).height,
      sakuraMobileThemeData.appComponentTokens.buttonHeightXs,
    );
    expect(label.style?.fontSize, sakuraMobileThemeData.appTextScale.s12);
  });

  testWidgets('app text button renders leading and trailing icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppTextButton(
            label: '全部',
            icon: const Icon(Icons.filter_alt_outlined),
            trailingIcon: const Icon(Icons.expand_more),
            size: AppTextButtonSize.small,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    final iconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.filter_alt_outlined),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(iconTheme.data.size, sakuraThemeData.appComponentTokens.iconSizeSm);
  });
}
