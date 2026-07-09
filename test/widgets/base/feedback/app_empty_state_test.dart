import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

void main() {
  testWidgets('app empty state renders only message text by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: AppEmptyState(message: '暂无数据')),
      ),
    );

    expect(find.text('暂无数据'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('app empty state renders icon when provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          body: AppEmptyState(
            message: '加载失败',
            icon: Icons.error_outline,
          ),
        ),
      ),
    );

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('app empty state renders retry button and invokes callback', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppEmptyState(
            message: '加载失败',
            onRetry: () => tapped += 1,
            retryKey: const Key('retry-button'),
          ),
        ),
      ),
    );

    expect(find.byType(AppButton), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry-button')));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('app empty state respects custom retry label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: AppEmptyState(
            message: '加载失败',
            onRetry: () {},
            retryLabel: '刷新',
          ),
        ),
      ),
    );

    expect(find.text('刷新'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });
}
