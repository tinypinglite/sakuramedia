import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/cloud115_authentication_status_chips.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('shows not tested status initially', (WidgetTester tester) async {
    await _pumpChips(tester);

    expect(find.text('未检测'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });

  testWidgets('shows busy status while testing', (WidgetTester tester) async {
    await _pumpChips(tester, isTesting: true);

    expect(find.text('检测中'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows not configured for an empty summary', (
    WidgetTester tester,
  ) async {
    await _pumpChips(tester, summary: _summary());

    expect(find.text('未配置'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });

  testWidgets('shows all alive count with success icon', (
    WidgetTester tester,
  ) async {
    await _pumpChips(tester, summary: _summary(alive: 3));

    expect(find.text('全部正常'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('shows expired and unavailable as separate statuses', (
    WidgetTester tester,
  ) async {
    await _pumpChips(
      tester,
      summary: _summary(alive: 2, expired: 1, unavailable: 3),
    );

    expect(find.text('认证失效'), findsOneWidget);
    expect(find.text('暂不可用'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('shows request failure instead of unavailable', (
    WidgetTester tester,
  ) async {
    await _pumpChips(tester, requestFailed: true);

    expect(find.text('检测失败'), findsOneWidget);
    expect(find.text('暂不可用'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('status labels contain no emoji characters', (
    WidgetTester tester,
  ) async {
    await _pumpChips(
      tester,
      summary: _summary(alive: 1, expired: 1, unavailable: 1),
    );

    final text =
        tester
            .widgetList<Text>(find.byType(Text))
            .map((Text widget) => widget.data ?? '')
            .join();
    final emoji = RegExp(
      r'[\u{2600}-\u{27BF}\u{1F000}-\u{1FAFF}]',
      unicode: true,
    );
    expect(text, isNot(matches(emoji)));
  });
}

Future<void> _pumpChips(
  WidgetTester tester, {
  StatusCloud115CookieSummaryDto? summary,
  bool isTesting = false,
  bool requestFailed = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: Center(
          child: Cloud115AuthenticationStatusChips(
            summary: summary,
            isTesting: isTesting,
            requestFailed: requestFailed,
          ),
        ),
      ),
    ),
  );
}

StatusCloud115CookieSummaryDto _summary({
  int alive = 0,
  int expired = 0,
  int unavailable = 0,
}) {
  return StatusCloud115CookieSummaryDto(
    total: alive + expired + unavailable,
    alive: alive,
    expired: expired,
    unavailable: unavailable,
  );
}
