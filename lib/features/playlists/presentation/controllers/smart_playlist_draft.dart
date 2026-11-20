import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';

const Object _smartPlaylistDraftUnset = Object();

/// 智能列表编辑器里的筛选草稿。
///
/// 与 `MovieFilterState` 的区别：状态、观看状态、年份、分辨率都是多选，
/// 且不再混入列表视图的排序维度语义。提交时翻译成后端 `filter` 快照。
@immutable
class SmartPlaylistDraft {
  const SmartPlaylistDraft({
    this.statuses = const <MovieStatusFilter>{},
    this.statusMatch = TagMatchMode.or,
    this.watchStatuses = const <MovieWatchStatusFilter>{},
    this.watchMatch = TagMatchMode.or,
    this.collectionType = MovieCollectionTypeFilter.single,
    this.numberSource = MovieNumberSourceFilter.all,
    this.sortField = PlaylistSortField.releaseDate,
    this.sortDirection = SortDirection.desc,
    this.years = const <int>{},
    this.resolutions = const <PlaylistResolutionFilter>{},
    this.interaction = MovieInteractionFilter.initial,
    this.actorAgeMin,
    this.actorAgeMax,
    this.mediaTagIds = const <int>[],
    this.mediaTagMatch = TagMatchMode.or,
    this.actorIds = const <int>[],
    this.actorMatch = TagMatchMode.or,
  });

  factory SmartPlaylistDraft.fromFilter(SmartPlaylistFilterDto? filter) {
    if (filter == null) {
      return const SmartPlaylistDraft();
    }
    final sort = playlistSortFromApi(filter.sort);
    return SmartPlaylistDraft(
      statuses: <MovieStatusFilter>{
        for (final value in filter.statuses)
          MovieStatusFilterX.fromApiValue(value),
      },
      statusMatch: TagMatchModeX.fromApiValue(filter.statusMatch),
      watchStatuses: <MovieWatchStatusFilter>{
        for (final value in filter.watchStatuses)
          MovieWatchStatusFilterX.fromApiValue(value),
      },
      watchMatch: TagMatchModeX.fromApiValue(filter.watchMatch),
      collectionType: MovieCollectionTypeFilterX.fromApiValue(
        filter.collectionType,
      ),
      numberSource: MovieNumberSourceFilterX.fromApiValue(filter.numberSource),
      sortField: sort?.field ?? PlaylistSortField.releaseDate,
      sortDirection: sort?.direction ?? SortDirection.desc,
      years: filter.years.toSet(),
      resolutions: <PlaylistResolutionFilter>{
        for (final value in filter.resolutions)
          ?PlaylistResolutionFilterX.fromApiValue(value),
      },
      interaction: filter.heatMin == null && filter.heatMax == null
          ? MovieInteractionFilter.initial
          : MovieInteractionFilter.initial.withRange(
              MovieInteractionMetric.heat,
              min: filter.heatMin,
              max: filter.heatMax,
            ),
      actorAgeMin: filter.actorAgeMin,
      actorAgeMax: filter.actorAgeMax,
      mediaTagIds: filter.mediaTagIds,
      mediaTagMatch: TagMatchModeX.fromApiValue(filter.mediaTagMatch),
      actorIds: filter.actorIds,
      actorMatch: TagMatchModeX.fromApiValue(filter.actorMatch),
    );
  }

  final Set<MovieStatusFilter> statuses;
  final TagMatchMode statusMatch;
  final Set<MovieWatchStatusFilter> watchStatuses;
  final TagMatchMode watchMatch;
  final MovieCollectionTypeFilter collectionType;
  final MovieNumberSourceFilter numberSource;
  final PlaylistSortField sortField;
  final SortDirection sortDirection;
  final Set<int> years;
  final Set<PlaylistResolutionFilter> resolutions;
  final MovieInteractionFilter interaction;
  final int? actorAgeMin;
  final int? actorAgeMax;
  final List<int> mediaTagIds;
  final TagMatchMode mediaTagMatch;
  final List<int> actorIds;
  final TagMatchMode actorMatch;

  /// 分辨率仅在「可播放」状态下生效，与影片库一致。
  bool get isResolutionEnabled => statuses.contains(MovieStatusFilter.playable);

  String get sortExpression =>
      '${sortField.apiValue}:${sortDirection.apiValue}';

  Map<String, dynamic> toFilterJson({
    required List<int> tagIds,
    required TagMatchMode tagMatch,
  }) {
    final filterJson = <String, dynamic>{
      'statuses': <String>[
        for (final value in MovieStatusFilter.values)
          if (statuses.contains(value)) value.apiValue,
      ],
      'status_match': statusMatch.apiValue,
      'watch_statuses': <String>[
        for (final value in MovieWatchStatusFilter.values)
          if (watchStatuses.contains(value)) value.apiValue,
      ],
      'watch_match': watchMatch.apiValue,
      'collection_type': collectionType.apiValue,
      'number_source': numberSource.apiValue,
      'sort': sortExpression,
      'years': years.toList()..sort(),
      'resolutions': <String>[
        for (final value in PlaylistResolutionFilter.values)
          if (isResolutionEnabled && resolutions.contains(value))
            value.apiValue,
      ],
      'tag_ids': tagIds,
      'tag_match': tagMatch.apiValue,
      'media_tag_ids': mediaTagIds,
      'media_tag_match': mediaTagMatch.apiValue,
      'actor_ids': actorIds,
      'actor_match': actorMatch.apiValue,
      if (actorAgeMin != null) 'actor_age_min': actorAgeMin,
      if (actorAgeMax != null) 'actor_age_max': actorAgeMax,
    };
    interaction.addQueryParameters(filterJson);
    return filterJson;
  }

  SmartPlaylistDraft copyWith({
    Set<MovieStatusFilter>? statuses,
    TagMatchMode? statusMatch,
    Set<MovieWatchStatusFilter>? watchStatuses,
    TagMatchMode? watchMatch,
    MovieCollectionTypeFilter? collectionType,
    MovieNumberSourceFilter? numberSource,
    PlaylistSortField? sortField,
    SortDirection? sortDirection,
    Set<int>? years,
    Set<PlaylistResolutionFilter>? resolutions,
    MovieInteractionFilter? interaction,
    Object? actorAgeMin = _smartPlaylistDraftUnset,
    Object? actorAgeMax = _smartPlaylistDraftUnset,
    List<int>? mediaTagIds,
    TagMatchMode? mediaTagMatch,
    List<int>? actorIds,
    TagMatchMode? actorMatch,
  }) {
    return SmartPlaylistDraft(
      statuses: Set<MovieStatusFilter>.unmodifiable(statuses ?? this.statuses),
      statusMatch: statusMatch ?? this.statusMatch,
      watchStatuses: Set<MovieWatchStatusFilter>.unmodifiable(
        watchStatuses ?? this.watchStatuses,
      ),
      watchMatch: watchMatch ?? this.watchMatch,
      collectionType: collectionType ?? this.collectionType,
      numberSource: numberSource ?? this.numberSource,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      years: Set<int>.unmodifiable(years ?? this.years),
      resolutions: Set<PlaylistResolutionFilter>.unmodifiable(
        resolutions ?? this.resolutions,
      ),
      interaction: interaction ?? this.interaction,
      actorAgeMin: identical(actorAgeMin, _smartPlaylistDraftUnset)
          ? this.actorAgeMin
          : actorAgeMin as int?,
      actorAgeMax: identical(actorAgeMax, _smartPlaylistDraftUnset)
          ? this.actorAgeMax
          : actorAgeMax as int?,
      mediaTagIds: List<int>.unmodifiable(mediaTagIds ?? this.mediaTagIds),
      mediaTagMatch: mediaTagMatch ?? this.mediaTagMatch,
      actorIds: List<int>.unmodifiable(actorIds ?? this.actorIds),
      actorMatch: actorMatch ?? this.actorMatch,
    );
  }
}
