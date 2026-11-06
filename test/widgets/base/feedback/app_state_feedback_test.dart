import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('AppErrorState 重试回调只触发一次', (tester) async {
    var retries = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppErrorState(
          title: '失败',
          message: '说明',
          retryKey: const Key('error-retry'),
          onRetry: () => retries++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('error-retry')));

    expect(retries, 1);
  });

  testWidgets('AppEmptyState section 的文字重试可用', (tester) async {
    var retries = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppEmptyState.section(
          title: '空',
          message: '说明',
          retryStyle: AppEmptyStateRetryStyle.text,
          retryKey: const Key('section-retry'),
          onRetry: () => retries++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('section-retry')));

    expect(retries, 1);
  });

  testWidgets('筛选失败保留旧数据时展示详情并可重试', (tester) async {
    var retries = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppFilterUpdateBar(
          state: const FilterUpdateState.failed('后端返回的具体原因'),
          hasPreviousItems: true,
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.byKey(const Key('app-filter-update-error')), findsOneWidget);
    expect(
      find.byKey(const Key('app-filter-update-error-detail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('app-filter-update-empty-error')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('app-filter-update-retry')));

    expect(retries, 1);
  });

  testWidgets('筛选失败且无旧数据时走 section 错误态', (tester) async {
    var retries = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppFilterUpdateBar(
          state: const FilterUpdateState.failed('加载失败'),
          hasPreviousItems: false,
          onRetry: () => retries++,
        ),
      ),
    );

    expect(
      find.byKey(const Key('app-filter-update-empty-error')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('app-filter-update-error')), findsNothing);

    await tester.tap(find.byKey(const Key('app-filter-update-empty-retry')));

    expect(retries, 1);
  });
}
