import 'package:sakuramedia/features/playlists/data/playlist_resolution_filter.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

export 'package:sakuramedia/features/playlists/data/playlist_resolution_filter.dart'
    show PlaylistResolutionFilter, PlaylistResolutionFilterX;
export 'package:sakuramedia/features/shared/data/sort_direction.dart'
    show SortDirection, SortDirectionX;

/// 播放列表影片的排序字段，对齐后端 `sort` 参数的 `field:direction`。
enum PlaylistSortField { heat, bitrate, addedAt, releaseDate }

List<PlaylistSortField> visiblePlaylistSortFields({
  required bool statsEnabled,
}) {
  return <PlaylistSortField>[
    for (final field in PlaylistSortField.values)
      if (statsEnabled || field != PlaylistSortField.heat) field,
  ];
}

extension PlaylistSortFieldX on PlaylistSortField {
  String get apiValue => switch (this) {
    PlaylistSortField.heat => 'heat',
    PlaylistSortField.bitrate => 'bitrate',
    PlaylistSortField.addedAt => 'added_at',
    PlaylistSortField.releaseDate => 'release_date',
  };

  String label(AppLocalizations l10n) => switch (this) {
    PlaylistSortField.heat => l10n.playlistSortHeat,
    PlaylistSortField.bitrate => l10n.playlistSortBitrate,
    PlaylistSortField.addedAt => l10n.playlistSortAddedAt,
    PlaylistSortField.releaseDate => l10n.playlistSortReleaseDate,
  };
}

const Object _playlistFilterUnset = Object();

/// 播放列表影片列表的筛选状态。
///
/// 语义对齐 `MovieFilterState` / `VideoFilterState`：
/// - `sortField` 为 null 表示不传 `sort`，走后端默认（最近触达/入库倒序）
/// - `resolution` 为 null 表示不筛分辨率（全部档位）
class PlaylistFilterState {
  const PlaylistFilterState({
    this.sortField,
    this.sortDirection = SortDirection.desc,
    this.resolution,
  });

  final PlaylistSortField? sortField;
  final SortDirection sortDirection;
  final PlaylistResolutionFilter? resolution;

  static const PlaylistFilterState initial = PlaylistFilterState();

  /// 是否存在生效的筛选条件。**不含排序**。
  bool get hasActiveFilters => resolution != null;

  String? get sortExpression => sortField == null
      ? null
      : '${sortField!.apiValue}:${sortDirection.apiValue}';

  PlaylistFilterState withoutStatsFeatures() =>
      sortField == PlaylistSortField.heat ? copyWith(sortField: null) : this;

  /// 筛选入口只反映分辨率，不再混入排序。
  String triggerLabel(AppLocalizations l10n) =>
      resolution?.label ?? l10n.playlistFilterAll;

  /// 重置筛选条件但保留当前排序。
  PlaylistFilterState resetFilters() => PlaylistFilterState.initial.copyWith(
    sortField: sortField,
    sortDirection: sortDirection,
  );

  bool matches(PlaylistFilterState other) =>
      sortField == other.sortField &&
      sortDirection == other.sortDirection &&
      resolution == other.resolution;

  PlaylistFilterState copyWith({
    Object? sortField = _playlistFilterUnset,
    SortDirection? sortDirection,
    Object? resolution = _playlistFilterUnset,
  }) {
    return PlaylistFilterState(
      sortField: identical(sortField, _playlistFilterUnset)
          ? this.sortField
          : sortField as PlaylistSortField?,
      sortDirection: sortDirection ?? this.sortDirection,
      resolution: identical(resolution, _playlistFilterUnset)
          ? this.resolution
          : resolution as PlaylistResolutionFilter?,
    );
  }
}
