import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

export 'package:sakuramedia/features/playlists/data/playlist_resolution_filter.dart'
    show PlaylistResolutionFilter, PlaylistResolutionFilterX;
export 'package:sakuramedia/features/shared/data/sort_direction.dart'
    show SortDirection, SortDirectionX;
export 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart'
    show
        MovieStatusFilter,
        MovieStatusFilterX,
        MovieWatchStatusFilter,
        MovieWatchStatusFilterX,
        TagMatchMode,
        TagMatchModeX;

/// 播放列表影片排序字段。普通列表与智能列表共用同一套。
enum PlaylistSortField {
  heat,
  bitrate,
  addedAt,
  releaseDate,
  subscribedAt,
  myScore,
}

List<PlaylistSortField> visiblePlaylistSortFields({
  required bool statsEnabled,
}) {
  return <PlaylistSortField>[
    for (final field in PlaylistSortField.values)
      if (statsEnabled || field != PlaylistSortField.heat) field,
  ];
}

PlaylistSortField visiblePlaylistSortField(
  PlaylistSortField field, {
  required bool statsEnabled,
}) {
  return !statsEnabled && field == PlaylistSortField.heat
      ? PlaylistSortField.releaseDate
      : field;
}

extension PlaylistSortFieldX on PlaylistSortField {
  String get apiValue => switch (this) {
    PlaylistSortField.heat => 'heat',
    PlaylistSortField.bitrate => 'bitrate',
    PlaylistSortField.addedAt => 'added_at',
    PlaylistSortField.releaseDate => 'release_date',
    PlaylistSortField.subscribedAt => 'subscribed_at',
    PlaylistSortField.myScore => 'my_score',
  };

  String label(AppLocalizations l10n) => switch (this) {
    PlaylistSortField.heat => l10n.playlistSortHeat,
    PlaylistSortField.bitrate => l10n.playlistSortBitrate,
    PlaylistSortField.addedAt => l10n.playlistSortAddedAt,
    PlaylistSortField.releaseDate => l10n.playlistSortReleaseDate,
    PlaylistSortField.subscribedAt => l10n.subscriptionSortFieldSubscribedAt,
    PlaylistSortField.myScore => l10n.movieSortMyScore,
  };
}

({PlaylistSortField field, SortDirection direction})? playlistSortFromApi(
  String? sort,
) {
  final normalized = sort?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final parts = normalized.split(':');
  final field = PlaylistSortField.values
      .where((value) => value.apiValue == parts.first.trim())
      .firstOrNull;
  if (field == null) {
    return null;
  }
  final direction = parts.length > 1 && parts[1].trim().toLowerCase() == 'asc'
      ? SortDirection.asc
      : SortDirection.desc;
  return (field: field, direction: direction);
}

String? playlistSortLabel(String? sort, AppLocalizations l10n) {
  final parsed = playlistSortFromApi(sort);
  if (parsed == null) {
    return null;
  }
  return '${parsed.field.label(l10n)} ${parsed.direction.symbol}';
}

const Object _playlistFilterUnset = Object();

/// 播放列表详情页的临时筛选。
///
/// 智能列表进入后以保存条件预填；用户改动只在当前查看生效。普通列表从空状态
/// 开始。排序字段为 null 表示沿用列表默认：智能列表用保存排序，普通列表用最近
/// 触达排序。
@immutable
class PlaylistFilterState {
  const PlaylistFilterState({
    this.sortField,
    this.sortDirection = SortDirection.desc,
    this.statuses = const <MovieStatusFilter>{},
    this.statusMatch = TagMatchMode.or,
    this.watchStatuses = const <MovieWatchStatusFilter>{},
    this.watchMatch = TagMatchMode.or,
    this.years = const <int>{},
    this.resolutions = const <PlaylistResolutionFilter>{},
    this.mediaTagIds = const <int>[],
    this.mediaTagMatch = TagMatchMode.or,
  });

  factory PlaylistFilterState.fromSmartFilter(SmartPlaylistFilterDto? filter) {
    if (filter == null) {
      return PlaylistFilterState.initial;
    }
    return PlaylistFilterState(
      statuses: Set<MovieStatusFilter>.unmodifiable(<MovieStatusFilter>{
        for (final value in filter.statuses)
          if (MovieStatusFilterX.fromApiValue(value) != MovieStatusFilter.all)
            MovieStatusFilterX.fromApiValue(value),
      }),
      statusMatch: TagMatchModeX.fromApiValue(filter.statusMatch),
      watchStatuses:
          Set<MovieWatchStatusFilter>.unmodifiable(<MovieWatchStatusFilter>{
            for (final value in filter.watchStatuses)
              if (MovieWatchStatusFilterX.fromApiValue(value) !=
                  MovieWatchStatusFilter.all)
                MovieWatchStatusFilterX.fromApiValue(value),
          }),
      watchMatch: TagMatchModeX.fromApiValue(filter.watchMatch),
      years: Set<int>.unmodifiable(filter.years),
      resolutions:
          Set<PlaylistResolutionFilter>.unmodifiable(<PlaylistResolutionFilter>{
            for (final value in filter.resolutions)
              ?PlaylistResolutionFilterX.fromApiValue(value),
          }),
      mediaTagIds: List<int>.unmodifiable(filter.mediaTagIds),
      mediaTagMatch: TagMatchModeX.fromApiValue(filter.mediaTagMatch),
    );
  }

  final PlaylistSortField? sortField;
  final SortDirection sortDirection;
  final Set<MovieStatusFilter> statuses;
  final TagMatchMode statusMatch;
  final Set<MovieWatchStatusFilter> watchStatuses;
  final TagMatchMode watchMatch;
  final Set<int> years;
  final Set<PlaylistResolutionFilter> resolutions;
  final List<int> mediaTagIds;
  final TagMatchMode mediaTagMatch;

  static const PlaylistFilterState initial = PlaylistFilterState();

  /// 是否存在生效的筛选条件。**不含排序**。
  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      watchStatuses.isNotEmpty ||
      years.isNotEmpty ||
      resolutions.isNotEmpty ||
      mediaTagIds.isNotEmpty;

  String? get sortExpression => sortField == null
      ? null
      : '${sortField!.apiValue}:${sortDirection.apiValue}';

  PlaylistFilterState withoutStatsFeatures() =>
      sortField == PlaylistSortField.heat ? copyWith(sortField: null) : this;

  String triggerLabel(AppLocalizations l10n) {
    if (!hasActiveFilters) {
      return l10n.playlistFilterAll;
    }
    final parts = <String>[];
    if (watchStatuses.isNotEmpty) {
      parts.add(
        _summary(
          _labels(watchStatuses, (value) => value.labelWith(l10n)),
          l10n,
        ),
      );
    }
    if (statuses.isNotEmpty) {
      parts.add(
        _summary(_labels(statuses, (value) => value.labelWith(l10n)), l10n),
      );
    }
    if (years.isNotEmpty) {
      parts.add(movieFilterYearsLabel(years, l10n));
    }
    if (resolutions.isNotEmpty) {
      parts.add(_summary(_labels(resolutions, (value) => value.label), l10n));
    }
    if (mediaTagIds.isNotEmpty) {
      parts.add(l10n.moviePageMediaTagCount(mediaTagIds.length));
    }
    return _summary(parts, l10n);
  }

  /// 重置筛选条件但保留当前排序。
  PlaylistFilterState resetFilters() => PlaylistFilterState.initial.copyWith(
    sortField: sortField,
    sortDirection: sortDirection,
  );

  bool matches(PlaylistFilterState other) =>
      matchesFilters(other) &&
      sortField == other.sortField &&
      sortDirection == other.sortDirection;

  bool matchesFilters(PlaylistFilterState other) =>
      setEquals(statuses, other.statuses) &&
      statusMatch == other.statusMatch &&
      setEquals(watchStatuses, other.watchStatuses) &&
      watchMatch == other.watchMatch &&
      setEquals(years, other.years) &&
      setEquals(resolutions, other.resolutions) &&
      listEquals(mediaTagIds, other.mediaTagIds) &&
      mediaTagMatch == other.mediaTagMatch;

  PlaylistFilterState copyWith({
    Object? sortField = _playlistFilterUnset,
    SortDirection? sortDirection,
    Set<MovieStatusFilter>? statuses,
    TagMatchMode? statusMatch,
    Set<MovieWatchStatusFilter>? watchStatuses,
    TagMatchMode? watchMatch,
    Set<int>? years,
    Set<PlaylistResolutionFilter>? resolutions,
    List<int>? mediaTagIds,
    TagMatchMode? mediaTagMatch,
  }) {
    return PlaylistFilterState(
      sortField: identical(sortField, _playlistFilterUnset)
          ? this.sortField
          : sortField as PlaylistSortField?,
      sortDirection: sortDirection ?? this.sortDirection,
      statuses: Set<MovieStatusFilter>.unmodifiable(statuses ?? this.statuses),
      statusMatch: statusMatch ?? this.statusMatch,
      watchStatuses: Set<MovieWatchStatusFilter>.unmodifiable(
        watchStatuses ?? this.watchStatuses,
      ),
      watchMatch: watchMatch ?? this.watchMatch,
      years: Set<int>.unmodifiable(years ?? this.years),
      resolutions: Set<PlaylistResolutionFilter>.unmodifiable(
        resolutions ?? this.resolutions,
      ),
      mediaTagIds: List<int>.unmodifiable(mediaTagIds ?? this.mediaTagIds),
      mediaTagMatch: mediaTagMatch ?? this.mediaTagMatch,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaylistFilterState && matches(other);

  @override
  int get hashCode => Object.hash(
    sortField,
    sortDirection,
    Object.hashAllUnordered(statuses),
    statusMatch,
    Object.hashAllUnordered(watchStatuses),
    watchMatch,
    Object.hashAllUnordered(years),
    Object.hashAllUnordered(resolutions),
    Object.hashAll(mediaTagIds),
    mediaTagMatch,
  );
}

List<String> _labels<T>(Iterable<T> values, String Function(T value) label) {
  return values.map(label).toList(growable: false);
}

String _summary(List<String> parts, AppLocalizations l10n) {
  if (parts.isEmpty) {
    return l10n.playlistFilterAll;
  }
  if (parts.length == 1) {
    return parts.single;
  }
  if (parts.length == 2) {
    return parts.join(' · ');
  }
  return l10n.playlistFilterSummary(
    parts.take(2).join(' · '),
    parts.length - 2,
  );
}
