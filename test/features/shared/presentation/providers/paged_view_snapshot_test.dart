import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';

void main() {
  test('ignores load-more status and page cursor until items change', () {
    const first = PagedListState<int>(
      items: <int>[1, 2],
      currentPage: 1,
      total: 4,
      hasMore: true,
    );
    final idle = pagedViewSnapshot<PagedListState<int>, int>(
      const AsyncData(first),
      (state) => state,
    );
    final loading = pagedViewSnapshot<PagedListState<int>, int>(
      AsyncData(first.copyWith(isLoadingMore: true)),
      (state) => state,
    );
    final failed = pagedViewSnapshot<PagedListState<int>, int>(
      AsyncData(
        first.copyWith(isLoadingMore: false, loadMoreErrorMessage: 'failed'),
      ),
      (state) => state,
    );
    final pageCursorAdvanced = pagedViewSnapshot<PagedListState<int>, int>(
      AsyncData(first.copyWith(currentPage: 2)),
      (state) => state,
    );

    expect(loading, idle);
    expect(failed, idle);
    expect(pageCursorAdvanced, idle);

    final appended = pagedViewSnapshot<PagedListState<int>, int>(
      const AsyncData(
        PagedListState<int>(items: <int>[1, 2, 3, 4], currentPage: 2, total: 4),
      ),
      (state) => state,
    );
    expect(appended, isNot(idle));
    expect(appended.items, <int>[1, 2, 3, 4]);

    final filtered = pagedViewSnapshot<PagedListState<int>, int>(
      AsyncData(
        first.copyWith(filterUpdate: const FilterUpdateState.loading()),
      ),
      (state) => state,
    );
    final totalChanged = pagedViewSnapshot<PagedListState<int>, int>(
      AsyncData(first.copyWith(total: 5)),
      (state) => state,
    );
    expect(filtered, isNot(idle));
    expect(totalChanged, isNot(idle));
  });

  test('keeps initial loading and initial error distinct', () {
    final loading = pagedViewSnapshot<PagedListState<int>, int>(
      const AsyncLoading(),
      (state) => state,
    );
    final error = pagedViewSnapshot<PagedListState<int>, int>(
      AsyncError(StateError('failed'), StackTrace.empty),
      (state) => state,
    );

    expect(loading.isInitialLoading, isTrue);
    expect(loading.initialError, isNull);
    expect(error.isInitialLoading, isFalse);
    expect(error.initialError, isA<StateError>());
  });
}
