import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';

void main() {
  group('MediaBrowseFilterState 排序与筛选分离', () {
    test('默认走后端排序且不算筛选', () {
      const state = MediaBrowseFilterState.initial;
      expect(state.sortField, isNull);
      expect(state.sortDirection, SortDirection.desc);
      expect(state.hasActiveFilters, isFalse);
    });

    test('只改排序不影响筛选默认态', () {
      const state = MediaBrowseFilterState(
        sortField: MediaBrowseSortField.heat,
        sortDirection: SortDirection.asc,
      );
      expect(state.hasActiveFilters, isFalse);
      expect(state.sortDirection, SortDirection.asc);
    });

    test('归属筛选才算筛选', () {
      const state = MediaBrowseFilterState(kind: MediaListItemKind.jav);
      expect(state.hasActiveFilters, isTrue);
    });

    test('文件名搜索去除首尾空白并计入筛选', () {
      const state = MediaBrowseFilterState(search: '  abc-001  ');
      expect(state.trimmedSearch, 'abc-001');
      expect(state.hasActiveFilters, isTrue);
    });

    test('resetFilters 保留排序', () {
      const state = MediaBrowseFilterState(
        kind: MediaListItemKind.video,
        libraryId: 3,
        search: 'abc',
        sortField: MediaBrowseSortField.fileSize,
        sortDirection: SortDirection.asc,
      );
      final reset = state.resetFilters();
      expect(reset.hasActiveFilters, isFalse);
      expect(reset.search, isEmpty);
      expect(reset.sortField, MediaBrowseSortField.fileSize);
      expect(reset.sortDirection, SortDirection.asc);
    });
  });
}
