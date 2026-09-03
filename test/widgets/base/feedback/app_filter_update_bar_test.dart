import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';

void main() {
  Widget wrap(AppFilterUpdateBar bar) {
    return MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: bar),
      ),
    );
  }

  testWidgets('idle、等待和请求中都不占据顶栏空间', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppFilterUpdateBar(
          state: FilterUpdateState.idle(),
          hasPreviousItems: true,
        ),
      ),
    );
    expect(find.byKey(const Key('app-filter-update-loading')), findsNothing);
    expect(tester.getSize(find.byType(AppFilterUpdateBar)).height, 0);

    await tester.pumpWidget(
      wrap(
        const AppFilterUpdateBar(
          state: FilterUpdateState.waiting(),
          hasPreviousItems: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('正在更新筛选结果'), findsNothing);
    expect(tester.getSize(find.byType(AppFilterUpdateBar)).height, 0);

    await tester.pumpWidget(
      wrap(
        const AppFilterUpdateBar(
          state: FilterUpdateState.loading(),
          hasPreviousItems: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('正在更新筛选结果'), findsNothing);
    expect(tester.getSize(find.byType(AppFilterUpdateBar)).height, 0);
  });

  testWidgets('已有旧结果时失败显示轻量提示并可重试', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      wrap(
        AppFilterUpdateBar(
          state: const FilterUpdateState.failed('网络错误'),
          hasPreviousItems: true,
          onRetry: () => retries += 1,
        ),
      ),
    );

    expect(find.text('筛选结果更新失败，仍显示上一次结果'), findsOneWidget);
    expect(
      find.byKey(const Key('app-filter-update-empty-error')),
      findsNothing,
    );

    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('没有旧结果时失败使用明确空态而非暂无匹配结果', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      wrap(
        AppFilterUpdateBar(
          state: const FilterUpdateState.failed('服务暂时不可用'),
          hasPreviousItems: false,
          onRetry: () => retries += 1,
        ),
      ),
    );

    expect(
      find.byKey(const Key('app-filter-update-empty-error')),
      findsOneWidget,
    );
    expect(find.text('筛选结果更新失败'), findsOneWidget);
    expect(find.text('服务暂时不可用'), findsOneWidget);
    expect(find.textContaining('暂无匹配'), findsNothing);

    await tester.tap(find.byKey(const Key('app-filter-update-empty-retry')));
    await tester.pump();
    expect(retries, 1);
  });
}
