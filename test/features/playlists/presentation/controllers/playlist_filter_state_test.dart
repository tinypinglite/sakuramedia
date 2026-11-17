import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  final l10n = AppLocalizationsZh();

  group('PlaylistFilterState', () {
    test('initial is default and keeps null sort/resolution', () {
      const state = PlaylistFilterState.initial;

      expect(state.hasActiveFilters, isFalse);
      expect(state.sortField, isNull);
      expect(state.sortDirection, SortDirection.desc);
      expect(state.resolution, isNull);
      expect(state.sortExpression, isNull);
      expect(state.triggerLabel(l10n), '全部');
    });

    test('sortExpression renders field:direction only when sortField set', () {
      final state = PlaylistFilterState.initial.copyWith(
        sortField: PlaylistSortField.heat,
      );

      expect(state.sortExpression, 'heat:desc');
      expect(
        state.copyWith(sortDirection: SortDirection.asc).sortExpression,
        'heat:asc',
      );
    });

    test('copyWith clears sortField back to null (sentinel)', () {
      final filtered = PlaylistFilterState.initial.copyWith(
        sortField: PlaylistSortField.bitrate,
      );
      expect(filtered.sortField, PlaylistSortField.bitrate);

      final cleared = filtered.copyWith(sortField: null);
      expect(cleared.sortField, isNull);
      expect(cleared.hasActiveFilters, isFalse);
    });

    test('copyWith clears resolution back to null (sentinel)', () {
      final filtered = PlaylistFilterState.initial.copyWith(
        resolution: PlaylistResolutionFilter.k4k,
      );
      expect(filtered.resolution, PlaylistResolutionFilter.k4k);

      final cleared = filtered.copyWith(resolution: null);
      expect(cleared.resolution, isNull);
      expect(cleared.hasActiveFilters, isFalse);
    });

    test('triggerLabel 只反映分辨率，不再混入排序', () {
      expect(
        PlaylistFilterState.initial
            .copyWith(resolution: PlaylistResolutionFilter.k4k)
            .triggerLabel(l10n),
        '4K',
      );
      expect(
        PlaylistFilterState.initial
            .copyWith(sortField: PlaylistSortField.addedAt)
            .triggerLabel(l10n),
        '全部',
      );
      expect(
        PlaylistFilterState.initial
            .copyWith(
              resolution: PlaylistResolutionFilter.k4k,
              sortField: PlaylistSortField.bitrate,
            )
            .triggerLabel(l10n),
        '4K',
      );
    });

    test('只改排序不影响筛选默认态', () {
      const state = PlaylistFilterState(
        sortField: PlaylistSortField.heat,
        sortDirection: SortDirection.asc,
      );
      expect(state.hasActiveFilters, isFalse);
      expect(state.sortField, PlaylistSortField.heat);
      expect(state.sortDirection, SortDirection.asc);
    });

    test('resetFilters 保留排序', () {
      const state = PlaylistFilterState(
        sortField: PlaylistSortField.bitrate,
        sortDirection: SortDirection.asc,
        resolution: PlaylistResolutionFilter.k4k,
      );
      final reset = state.resetFilters();
      expect(reset.hasActiveFilters, isFalse);
      expect(reset.sortField, PlaylistSortField.bitrate);
      expect(reset.sortDirection, SortDirection.asc);
    });

    test('matches compares all fields', () {
      const a = PlaylistFilterState.initial;
      const b = PlaylistFilterState.initial;
      final c = a.copyWith(sortField: PlaylistSortField.heat);

      expect(a.matches(b), isTrue);
      expect(a.matches(c), isFalse);
    });

    test('withoutStatsFeatures 清空热度排序', () {
      final heat = PlaylistFilterState.initial.copyWith(
        sortField: PlaylistSortField.heat,
      );
      final bitrate = PlaylistFilterState.initial.copyWith(
        sortField: PlaylistSortField.bitrate,
      );

      expect(heat.withoutStatsFeatures().sortField, isNull);
      expect(
        bitrate.withoutStatsFeatures().sortField,
        PlaylistSortField.bitrate,
      );
    });
  });

  group('PlaylistResolutionFilter', () {
    test('fromApiValue round-trips known labels and rejects unknown', () {
      for (final filter in PlaylistResolutionFilter.values) {
        expect(PlaylistResolutionFilterX.fromApiValue(filter.apiValue), filter);
      }
      expect(PlaylistResolutionFilterX.fromApiValue('5K'), isNull);
    });

    test('8K and 4K are distinct buckets', () {
      expect(
        PlaylistResolutionFilter.k8k.apiValue,
        isNot(PlaylistResolutionFilter.k4k.apiValue),
      );
    });
  });
}
