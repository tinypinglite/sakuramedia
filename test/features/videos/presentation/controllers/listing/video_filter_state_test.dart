import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  final l10n = AppLocalizationsZh();

  group('VideoFilterState 排序与筛选分离', () {
    test('initial 是默认筛选与默认排序', () {
      const state = VideoFilterState.initial;
      expect(state.hasActiveFilters, isFalse);
      expect(state.sortField, VideoSortField.createdAt);
      expect(state.sortDirection, SortDirection.desc);
      expect(state.triggerLabel(l10n), '全部');
    });

    test('只改排序不影响筛选默认态', () {
      const state = VideoFilterState(
        sortField: VideoSortField.title,
        sortDirection: SortDirection.asc,
      );
      expect(state.hasActiveFilters, isFalse);
      expect(state.sortField, VideoSortField.title);
      expect(state.sortDirection, SortDirection.asc);
      expect(state.triggerLabel(l10n), '全部');
    });

    test('未归类筛选不改排序摘要', () {
      const state = VideoFilterState(uncollected: true);
      expect(state.hasActiveFilters, isTrue);
      expect(state.triggerLabel(l10n), '未归类');
    });

    test('resetFilters 清筛选但保留排序', () {
      const state = VideoFilterState(
        uncollected: true,
        sortField: VideoSortField.duration,
        sortDirection: SortDirection.asc,
      );
      final reset = state.resetFilters();
      expect(reset.hasActiveFilters, isFalse);
      expect(reset.sortField, VideoSortField.duration);
      expect(reset.sortDirection, SortDirection.asc);
    });
  });
}
