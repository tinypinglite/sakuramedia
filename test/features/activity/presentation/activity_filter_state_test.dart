import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';

void main() {
  group('ActivityTaskFilterState 排序与筛选分离', () {
    test('默认排序状态', () {
      const state = ActivityTaskFilterState.initial;
      expect(state.sortField, ActivityTaskSortField.startedAt);
      expect(state.sortDirection, SortDirection.desc);
      expect(state.hasActiveFilters, isFalse);
    });

    test('只改排序不算已筛选', () {
      final state = ActivityTaskFilterState.initial.withSortDirection(
        SortDirection.asc,
      );
      expect(state.hasActiveFilters, isFalse);
      expect(state.sortDirection, SortDirection.asc);
    });

    test('字段与方向可以组合成完整排序值', () {
      final state = ActivityTaskFilterState.initial
          .withSortField(ActivityTaskSortField.updatedAt)
          .withSortDirection(SortDirection.asc);
      expect(state.sort, ActivityTaskSort.updatedAtAsc);
    });

    test('resetFilters 保留排序', () {
      final state = ActivityTaskFilterState.initial
          .withSortField(ActivityTaskSortField.createdAt)
          .copyWith(state: 'failed', taskKey: 'movie_import');
      final reset = state.resetFilters();
      expect(reset.hasActiveFilters, isFalse);
      expect(reset.sort, ActivityTaskSort.createdAtDesc);
    });
  });
}
