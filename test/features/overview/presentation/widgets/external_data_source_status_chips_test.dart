import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/external_data_source_status_chips.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('未检测时两枚徽章都显示未检测图标', (WidgetTester tester) async {
    await _pumpChips(
      tester,
      const ExternalDataSourceStatusChips(
        javdbHealthy: null,
        dmmHealthy: null,
        isTesting: false,
      ),
    );

    expect(
      find.byKey(const Key('overview-external-data-source-javdb')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('overview-external-data-source-dmm')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    expect(find.text('JavDB'), findsOneWidget);
    expect(find.text('DMM'), findsOneWidget);
  });

  testWidgets('健康与异常分别显示成功/失败图标', (WidgetTester tester) async {
    await _pumpChips(
      tester,
      const ExternalDataSourceStatusChips(
        javdbHealthy: true,
        dmmHealthy: false,
        isTesting: false,
      ),
    );

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('检测中时两枚徽章都用 spinner 替代图标', (WidgetTester tester) async {
    await _pumpChips(
      tester,
      const ExternalDataSourceStatusChips(
        javdbHealthy: true,
        dmmHealthy: false,
        isTesting: true,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('keyPrefix 决定徽章 Key 前缀', (WidgetTester tester) async {
    await _pumpChips(
      tester,
      const ExternalDataSourceStatusChips(
        javdbHealthy: null,
        dmmHealthy: null,
        isTesting: false,
        keyPrefix: 'mobile-system-overview',
      ),
    );

    expect(
      find.byKey(const Key('mobile-system-overview-external-data-source-javdb')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-system-overview-external-data-source-dmm')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpChips(WidgetTester tester, Widget chips) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(body: Center(child: chips)),
    ),
  );
}
