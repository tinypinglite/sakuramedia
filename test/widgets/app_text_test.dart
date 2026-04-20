import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('app text resolves numeric size scale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: Column(
            children: [
              AppText('20', size: AppTextSize.s20),
              AppText('18', size: AppTextSize.s18),
              AppText('16', size: AppTextSize.s16),
              AppText('14', size: AppTextSize.s14),
              AppText('12', size: AppTextSize.s12),
              AppText('10', size: AppTextSize.s10),
            ],
          ),
        ),
      ),
    );

    expect(tester.widget<Text>(find.text('20')).style?.fontSize, 20);
    expect(
      tester.widget<Text>(find.text('20')).style?.fontWeight,
      FontWeight.w400,
    );
    expect(tester.widget<Text>(find.text('18')).style?.fontSize, 18);
    expect(
      tester.widget<Text>(find.text('18')).style?.fontWeight,
      FontWeight.w400,
    );
    expect(tester.widget<Text>(find.text('16')).style?.fontSize, 16);
    expect(tester.widget<Text>(find.text('14')).style?.fontSize, 14);
    expect(tester.widget<Text>(find.text('12')).style?.fontSize, 12);
    expect(tester.widget<Text>(find.text('10')).style?.fontSize, 10);
  });

  testWidgets('app text resolves weight tokens', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: Column(
            children: [
              AppText('regular', size: AppTextSize.s14),
              AppText(
                'medium',
                size: AppTextSize.s14,
                weight: AppTextWeight.medium,
              ),
              AppText(
                'semibold',
                size: AppTextSize.s14,
                weight: AppTextWeight.semibold,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('regular')).style?.fontWeight,
      sakuraThemeData.appTextWeights.regular,
    );
    expect(
      tester.widget<Text>(find.text('medium')).style?.fontWeight,
      sakuraThemeData.appTextWeights.medium,
    );
    expect(
      tester.widget<Text>(find.text('semibold')).style?.fontWeight,
      sakuraThemeData.appTextWeights.semibold,
    );
  });

  testWidgets('app text resolves tone colors from text palette', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: Column(
            children: [
              AppText('primary', size: AppTextSize.s14),
              AppText(
                'secondary',
                size: AppTextSize.s14,
                tone: AppTextTone.secondary,
              ),
              AppText(
                'tertiary',
                size: AppTextSize.s12,
                tone: AppTextTone.tertiary,
              ),
              AppText('muted', size: AppTextSize.s12, tone: AppTextTone.muted),
              AppText(
                'onMedia',
                size: AppTextSize.s14,
                tone: AppTextTone.onMedia,
              ),
              AppText('info', size: AppTextSize.s12, tone: AppTextTone.info),
              AppText(
                'warning',
                size: AppTextSize.s12,
                tone: AppTextTone.warning,
              ),
              AppText('error', size: AppTextSize.s12, tone: AppTextTone.error),
              AppText(
                'success',
                size: AppTextSize.s12,
                tone: AppTextTone.success,
              ),
              AppText(
                'accent',
                size: AppTextSize.s12,
                tone: AppTextTone.accent,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('primary')).style?.color,
      sakuraThemeData.appTextPalette.primary,
    );
    expect(
      tester.widget<Text>(find.text('secondary')).style?.color,
      sakuraThemeData.appTextPalette.secondary,
    );
    expect(
      tester.widget<Text>(find.text('tertiary')).style?.color,
      sakuraThemeData.appTextPalette.tertiary,
    );
    expect(
      tester.widget<Text>(find.text('muted')).style?.color,
      sakuraThemeData.appTextPalette.muted,
    );
    expect(
      tester.widget<Text>(find.text('onMedia')).style?.color,
      sakuraThemeData.appTextPalette.onMedia,
    );
    expect(
      tester.widget<Text>(find.text('info')).style?.color,
      sakuraThemeData.appTextPalette.info,
    );
    expect(
      tester.widget<Text>(find.text('warning')).style?.color,
      sakuraThemeData.appTextPalette.warning,
    );
    expect(
      tester.widget<Text>(find.text('error')).style?.color,
      sakuraThemeData.appTextPalette.error,
    );
    expect(
      tester.widget<Text>(find.text('success')).style?.color,
      sakuraThemeData.appTextPalette.success,
    );
    expect(
      tester.widget<Text>(find.text('accent')).style?.color,
      sakuraThemeData.appTextPalette.accent,
    );
  });
}
