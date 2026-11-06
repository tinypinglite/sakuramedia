import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';

import '../../../../support/pump_with_providers.dart';

void main() {
  testWidgets('首次加载渲染骨架，不触发重试或翻页', (tester) async {
    var reloads = 0;
    var loadMores = 0;
    await _pumpSection(
      tester,
      asyncState: const AsyncLoading<PagedListState<int>>(),
      onReload: () => reloads++,
      onLoadMore: () => loadMores++,
    );

    expect(find.byKey(const Key('section-skeleton')), findsOneWidget);
    expect(reloads, 0);
    expect(loadMores, 0);
  });

  testWidgets('首次失败渲染错误态并可重试', (tester) async {
    var reloads = 0;
    var loadMores = 0;
    await _pumpSection(
      tester,
      asyncState: AsyncError<PagedListState<int>>(
        StateError('boom'),
        StackTrace.empty,
      ),
      onReload: () => reloads++,
      onLoadMore: () => loadMores++,
    );

    expect(find.byKey(const Key('paged-async-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('section-initial-retry')));

    expect(reloads, 1);
    expect(loadMores, 0);
  });

  testWidgets('空结果渲染空态且不显示翻页页脚', (tester) async {
    var loadMores = 0;
    await _pumpSection(
      tester,
      asyncState: const AsyncData<PagedListState<int>>(PagedListState<int>()),
      onReload: () {},
      onLoadMore: () => loadMores++,
    );

    expect(find.byKey(const Key('paged-async-empty')), findsOneWidget);
    expect(find.byKey(const Key('paged-async-load-more-footer')), findsNothing);
    expect(loadMores, 0);
  });

  testWidgets('有数据时渲染条目，翻页失败可重试', (tester) async {
    var loadMores = 0;
    await _pumpSection(
      tester,
      asyncState: const AsyncData<PagedListState<int>>(
        PagedListState<int>(
          items: <int>[0, 1],
          total: 10,
          hasMore: true,
          loadMoreErrorMessage: '下一页失败',
        ),
      ),
      onReload: () {},
      onLoadMore: () => loadMores++,
    );

    expect(find.byKey(const Key('item-0')), findsOneWidget);
    expect(
      find.byKey(const Key('paged-async-load-more-footer')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('paged-async-load-more-retry')));

    expect(loadMores, 1);
  });
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required AsyncValue<PagedListState<int>> asyncState,
  required VoidCallback onReload,
  required VoidCallback onLoadMore,
}) {
  return pumpWithProviders(
    tester,
    home: Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverPagedAsyncSection<PagedListState<int>, int>(
            asyncState: asyncState,
            pagedOf: (state) => state,
            itemBuilder: (context, item, index) =>
                SizedBox(key: Key('item-$item'), height: 40),
            itemSpacing: 8,
            initialErrorMessage: '首次加载失败',
            emptyMessage: '暂无数据',
            onReload: onReload,
            onLoadMore: onLoadMore,
            initialRetryKey: const Key('section-initial-retry'),
            skeletonBuilder: (context) =>
                const SizedBox(key: Key('section-skeleton'), height: 120),
          ),
        ],
      ),
    ),
    physicalSize: const Size(390, 700),
  );
}
