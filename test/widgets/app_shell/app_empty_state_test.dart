import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

void main() {
  testWidgets('app empty state renders only message text', (
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
    expect(find.byType(DecoratedBox), findsNothing);
  });
}
