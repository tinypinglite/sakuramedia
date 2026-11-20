import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  final l10n = AppLocalizationsZh();

  group('PlaylistFilterState', () {
    test('initial has no filters and delegates sort to the list default', () {
      const state = PlaylistFilterState.initial;

      expect(state.hasActiveFilters, isFalse);
      expect(state.sortField, isNull);
      expect(state.sortDirection, SortDirection.desc);
      expect(state.statuses, isEmpty);
      expect(state.watchStatuses, isEmpty);
      expect(state.years, isEmpty);
      expect(state.resolutions, isEmpty);
      expect(state.mediaTagIds, isEmpty);
      expect(state.sortExpression, isNull);
      expect(state.triggerLabel(l10n), '全部');
    });

    test('fromSmartFilter prefills supported saved dimensions', () {
      final state = PlaylistFilterState.fromSmartFilter(
        const SmartPlaylistFilterDto(
          statuses: <String>['playable', 'subscribed'],
          statusMatch: 'and',
          watchStatuses: <String>['unwatched'],
          watchMatch: 'or',
          years: <int>[2024, 2023],
          resolutions: <String>['4K', '1080P'],
          mediaTagIds: <int>[3, 5],
          mediaTagMatch: 'and',
          sort: 'heat:asc',
        ),
      );

      expect(state.statuses, <MovieStatusFilter>{
        MovieStatusFilter.playable,
        MovieStatusFilter.subscribed,
      });
      expect(state.statusMatch, TagMatchMode.and);
      expect(state.watchStatuses, <MovieWatchStatusFilter>{
        MovieWatchStatusFilter.unwatched,
      });
      expect(state.years, <int>{2023, 2024});
      expect(state.resolutions, <PlaylistResolutionFilter>{
        PlaylistResolutionFilter.k4k,
        PlaylistResolutionFilter.f1080p,
      });
      expect(state.mediaTagIds, <int>[3, 5]);
      expect(state.mediaTagMatch, TagMatchMode.and);
      expect(state.sortField, isNull);
    });

    test('triggerLabel combines common temporary dimensions', () {
      final state = PlaylistFilterState.initial.copyWith(
        statuses: const <MovieStatusFilter>{MovieStatusFilter.playable},
        resolutions: const <PlaylistResolutionFilter>{
          PlaylistResolutionFilter.k4k,
        },
      );

      expect(state.triggerLabel(l10n), '可播放 · 4K');
    });

    test('copyWith uses sentinels to clear nullable sort and collections', () {
      final filtered = PlaylistFilterState.initial.copyWith(
        sortField: PlaylistSortField.bitrate,
        resolutions: const <PlaylistResolutionFilter>{
          PlaylistResolutionFilter.k4k,
        },
        mediaTagIds: const <int>[1],
      );
      expect(filtered.hasActiveFilters, isTrue);

      final cleared = filtered.copyWith(
        sortField: null,
        resolutions: const <PlaylistResolutionFilter>{},
        mediaTagIds: const <int>[],
      );
      expect(cleared.sortField, isNull);
      expect(cleared.hasActiveFilters, isFalse);
    });

    test('resetFilters clears filters but keeps sort', () {
      const state = PlaylistFilterState(
        sortField: PlaylistSortField.bitrate,
        sortDirection: SortDirection.asc,
        statuses: <MovieStatusFilter>{MovieStatusFilter.playable},
        years: <int>{2024},
      );

      final reset = state.resetFilters();
      expect(reset.hasActiveFilters, isFalse);
      expect(reset.sortField, PlaylistSortField.bitrate);
      expect(reset.sortDirection, SortDirection.asc);
    });

    test('matches compares filters and sort', () {
      const a = PlaylistFilterState.initial;
      const b = PlaylistFilterState.initial;
      final filtered = a.copyWith(
        watchStatuses: const <MovieWatchStatusFilter>{
          MovieWatchStatusFilter.watching,
        },
      );
      final sorted = a.copyWith(sortField: PlaylistSortField.heat);

      expect(a.matches(b), isTrue);
      expect(a.matches(filtered), isFalse);
      expect(a.matches(sorted), isFalse);
      expect(a.matchesFilters(filtered), isFalse);
      expect(a.matchesFilters(sorted), isTrue);
    });

    test('withoutStatsFeatures clears heat sort only', () {
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

  group('playlist sort', () {
    test('maps all unified API values', () {
      for (final field in PlaylistSortField.values) {
        final parsed = playlistSortFromApi('${field.apiValue}:asc');
        expect(parsed?.field, field);
        expect(parsed?.direction, SortDirection.asc);
      }
    });

    test('formats saved sort label', () {
      expect(playlistSortLabel('my_score:desc', l10n), '我的评分 ↓');
      expect(playlistSortLabel('unknown:desc', l10n), isNull);
    });
  });

  group('PlaylistResolutionFilter', () {
    test('fromApiValue round-trips known labels and rejects unknown', () {
      for (final filter in PlaylistResolutionFilter.values) {
        expect(PlaylistResolutionFilterX.fromApiValue(filter.apiValue), filter);
      }
      expect(PlaylistResolutionFilterX.fromApiValue('5K'), isNull);
    });
  });
}
