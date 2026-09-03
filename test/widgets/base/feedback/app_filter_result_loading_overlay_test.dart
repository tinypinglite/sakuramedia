import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';

void main() {
  Widget wrap({required bool isLoading, required bool hasPreviousItems}) {
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: SizedBox.expand(
          child: AppFilterResultLoadingOverlay(
            isLoading: isLoading,
            hasPreviousItems: hasPreviousItems,
            indicatorDelay: const Duration(milliseconds: 100),
            child: const Center(child: Text('上一批结果')),
          ),
        ),
      ),
    );
  }

  testWidgets('有旧结果时仅在慢请求中显示居中进度', (tester) async {
    await tester.pumpWidget(wrap(isLoading: false, hasPreviousItems: true));
    expect(
      find.byKey(const Key('app-filter-result-loading-overlay')),
      findsNothing,
    );

    await tester.pumpWidget(wrap(isLoading: true, hasPreviousItems: true));
    await tester.pump(const Duration(milliseconds: 99));
    expect(
      find.byKey(const Key('app-filter-result-loading-overlay')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 1));
    expect(
      find.byKey(const Key('app-filter-result-loading-overlay')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在更新筛选结果'), findsNothing);

    await tester.pumpWidget(wrap(isLoading: false, hasPreviousItems: true));
    expect(
      find.byKey(const Key('app-filter-result-loading-overlay')),
      findsNothing,
    );
  });

  testWidgets('没有旧结果时请求中立即显示结果区进度', (tester) async {
    await tester.pumpWidget(wrap(isLoading: true, hasPreviousItems: false));

    expect(
      find.byKey(const Key('app-filter-result-loading-overlay')),
      findsOneWidget,
    );
  });
}
