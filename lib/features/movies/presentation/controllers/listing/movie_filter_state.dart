import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:sakuramedia/features/playlists/data/playlist_resolution_filter.dart';
import 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

export 'package:sakuramedia/features/playlists/data/playlist_resolution_filter.dart';

// 互动数模型跨 movies / rankings 共用，从既有入口 re-export 保持下游 import 不变。
export 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';

// SortDirection 已抬到 lib/features/shared/data/sort_direction.dart，
// 这里 re-export 保持 movies 域现有 import 路径不变。
export 'package:sakuramedia/features/shared/data/sort_direction.dart'
    show SortDirection, SortDirectionX;

enum MovieStatusFilter { all, subscribed, unsubscribed, playable }

extension MovieStatusFilterX on MovieStatusFilter {
  String get apiValue => switch (this) {
    MovieStatusFilter.all => 'all',
    MovieStatusFilter.subscribed => 'subscribed',
    MovieStatusFilter.unsubscribed => 'unsubscribed',
    MovieStatusFilter.playable => 'playable',
  };

  /// 当前语言的筛选档位名；展示层用这个取当前语言的文案。
  String labelWith(AppLocalizations l10n) => switch (this) {
    MovieStatusFilter.all => l10n.widgetMovieFilterAll,
    MovieStatusFilter.subscribed => l10n.movieWidgetSubscribed,
    MovieStatusFilter.unsubscribed => l10n.actorSubscriptionStatusUnsubscribed,
    MovieStatusFilter.playable => l10n.movieFilterStatusPlayable,
  };
}

enum MovieNumberSourceFilter { all, regular, fc2 }

extension MovieNumberSourceFilterX on MovieNumberSourceFilter {
  String get apiValue => switch (this) {
    MovieNumberSourceFilter.all => 'all',
    MovieNumberSourceFilter.regular => 'regular',
    MovieNumberSourceFilter.fc2 => 'fc2',
  };

  /// 当前语言的番号来源名；展示层用这个取当前语言的文案。
  String labelWith(AppLocalizations l10n) => switch (this) {
    MovieNumberSourceFilter.all => l10n.widgetMovieFilterAll,
    MovieNumberSourceFilter.regular => l10n.movieFilterNumberSourceRegular,
    MovieNumberSourceFilter.fc2 => l10n.movieFilterNumberSourceFc2,
  };
}

enum MovieCollectionTypeFilter { all, single }

extension MovieCollectionTypeFilterX on MovieCollectionTypeFilter {
  String get apiValue => switch (this) {
    MovieCollectionTypeFilter.all => 'all',
    MovieCollectionTypeFilter.single => 'single',
  };

  /// 当前语言的合集类型名；展示层用这个取当前语言的文案。
  String labelWith(AppLocalizations l10n) => switch (this) {
    MovieCollectionTypeFilter.all => l10n.widgetMovieFilterAll,
    MovieCollectionTypeFilter.single => l10n.movieFilterCollectionTypeSingle,
  };
}

enum TagMatchMode { or, and }

extension TagMatchModeX on TagMatchMode {
  String get apiValue => switch (this) {
    TagMatchMode.or => 'or',
    TagMatchMode.and => 'and',
  };

  /// 当前语言的匹配模式名；展示层用这个取当前语言的文案。
  String labelWith(AppLocalizations l10n) => switch (this) {
    TagMatchMode.or => l10n.tagMatchModeOr,
    TagMatchMode.and => l10n.tagMatchModeAnd,
  };
}

enum MovieSortField {
  releaseDate,
  addedAt,
  subscribedAt,
  heat,
  score,
  scoreNumber,
  watchedCount,
  wantWatchCount,
  commentCount,
  myScore,
}

extension MovieSortFieldX on MovieSortField {
  String get apiValue => switch (this) {
    MovieSortField.releaseDate => 'release_date',
    MovieSortField.addedAt => 'added_at',
    MovieSortField.subscribedAt => 'subscribed_at',
    MovieSortField.heat => 'heat',
    MovieSortField.score => 'score',
    MovieSortField.scoreNumber => 'score_number',
    MovieSortField.watchedCount => 'watched_count',
    MovieSortField.wantWatchCount => 'want_watch_count',
    MovieSortField.commentCount => 'comment_count',
    MovieSortField.myScore => 'my_score',
  };

  /// 当前语言的排序字段名；展示层用这个取当前语言的文案。
  String labelWith(AppLocalizations l10n) => switch (this) {
    MovieSortField.releaseDate => l10n.movieSortReleaseDate,
    MovieSortField.addedAt => l10n.playlistSortAddedAt,
    MovieSortField.subscribedAt => l10n.subscriptionSortFieldSubscribedAt,
    MovieSortField.heat => l10n.sharedInteractionHeat,
    MovieSortField.score => l10n.sharedInteractionScore,
    MovieSortField.scoreNumber => l10n.sharedInteractionScoreNumber,
    MovieSortField.watchedCount => l10n.sharedInteractionWatchedCount,
    MovieSortField.wantWatchCount => l10n.sharedInteractionWantWatchCount,
    MovieSortField.commentCount => l10n.rankingSortFieldCommentCount,
    MovieSortField.myScore => l10n.movieSortMyScore,
  };
}

const Object _movieFilterUnset = Object();

/// 普通影片库的年份筛选不依赖后端聚合：范围固定为 2008 年至当前年。
///
/// 女优详情会显式传入服务端返回的年份和数量，因此仍可保持「年份(影片数)」
/// 的精确展示。
const int movieFilterEarliestYear = 2008;

/// 出演年龄筛选的滑块范围：18 ~ 50 岁。
///
/// 与后端语义对齐：最小 18 岁即下限不限（不传 `actor_age_min`）；
/// 滑到顶 50 即上限不限（不传 `actor_age_max`，50 岁及以上都包含）。
const int movieFilterActorAgeSliderMin = 18;
const int movieFilterActorAgeSliderMax = 50;

/// 滑块下限值 → 接口参数：18 即不限（不传 `actor_age_min`）。
int? movieActorAgeMinFromSlider(int value) =>
    value <= movieFilterActorAgeSliderMin ? null : value;

/// 滑块上限值 → 接口参数：滑到顶即无上界（不传 `actor_age_max`）。
int? movieActorAgeMaxFromSlider(int value) =>
    value >= movieFilterActorAgeSliderMax ? null : value;

/// 出演年龄范围的展示文案，与热度范围同构。
String movieActorAgeRangeLabel(
  int? actorAgeMin,
  int? actorAgeMax,
  AppLocalizations l10n,
) {
  if (actorAgeMin != null && actorAgeMax != null) {
    return l10n.movieFilterActorAgeRange(actorAgeMin, actorAgeMax);
  }
  if (actorAgeMin != null) {
    return l10n.movieFilterActorAgeMin(actorAgeMin);
  }
  if (actorAgeMax != null) {
    return l10n.movieFilterActorAgeMax(actorAgeMax);
  }
  return l10n.sharedInteractionUnlimited;
}

/// 年份多选的展示文案：1 个直出，2 个以分隔符相连，3 个及以上折叠为
/// 「最新年份 等 N 个年份」；空集返回空串，此时调用方不采用年份标签。
String movieFilterYearsLabel(Set<int> years, AppLocalizations l10n) {
  final ordered = years.toList()..sort((a, b) => b.compareTo(a));
  if (ordered.length <= 2) {
    return ordered.join(l10n.movieWidgetActorNameSeparator);
  }
  return l10n.movieFilterYearsLabel(ordered.first, ordered.length);
}

List<MovieFilterYearOption> buildDefaultMovieFilterYearOptions({
  int? currentYear,
}) {
  final latestYear = currentYear ?? DateTime.now().year;
  if (latestYear < movieFilterEarliestYear) {
    return const <MovieFilterYearOption>[];
  }
  return <MovieFilterYearOption>[
    for (var year = latestYear; year >= movieFilterEarliestYear; year--)
      MovieFilterYearOption(year: year),
  ];
}

class MovieFilterYearOption {
  const MovieFilterYearOption({required this.year, this.movieCount});

  final int year;
  final int? movieCount;

  String get label => movieCount == null ? '$year' : '$year($movieCount)';
}

class MovieFilterState {
  const MovieFilterState({
    this.status = MovieStatusFilter.all,
    this.collectionType = MovieCollectionTypeFilter.single,
    this.numberSource = MovieNumberSourceFilter.all,
    this.sortField = MovieSortField.releaseDate,
    this.sortDirection = SortDirection.desc,
    this.dimensionSortId,
    this.years = const <int>{},
    this.interaction = MovieInteractionFilter.initial,
    this.actorAgeMin,
    this.actorAgeMax,
    this.resolution,
    this.mediaTagIds = const <int>[],
    this.mediaTagMatch = TagMatchMode.or,
  });

  final MovieStatusFilter status;
  final MovieCollectionTypeFilter collectionType;
  final MovieNumberSourceFilter numberSource;
  final MovieSortField sortField;
  final SortDirection sortDirection;

  /// 非空时按该个人评分维度排序，覆盖 [sortField]。
  final int? dimensionSortId;

  /// 多选年份，空集表示不限；多个年份之间为 OR。
  final Set<int> years;

  /// 6 个互动数字段的 min/max 条件；空集表示不限。
  final MovieInteractionFilter interaction;

  /// 出演年龄下限（接口 `actor_age_min` 语义）：null 表示不限。
  final int? actorAgeMin;

  /// 出演年龄上限（接口 `actor_age_max` 语义）：null 表示不限。
  final int? actorAgeMax;
  final PlaylistResolutionFilter? resolution;
  final List<int> mediaTagIds;
  final TagMatchMode mediaTagMatch;

  static const MovieFilterState initial = MovieFilterState();

  /// 是否存在生效的筛选条件。
  ///
  /// **不含排序**：排序是视图偏好，不是筛选条件；「重置筛选」和空态文案
  /// 都只应看这里。
  bool get hasActiveFilters =>
      status != MovieStatusFilter.all ||
      collectionType != MovieCollectionTypeFilter.single ||
      numberSource != MovieNumberSourceFilter.all ||
      years.isNotEmpty ||
      !interaction.isDefault ||
      actorAgeMin != null ||
      actorAgeMax != null ||
      resolution != null ||
      mediaTagIds.isNotEmpty;

  /// 重置筛选条件但保留当前排序。
  MovieFilterState resetFilters() => MovieFilterState.initial.copyWith(
    sortField: sortField,
    sortDirection: sortDirection,
    dimensionSortId: dimensionSortId,
  );

  bool get hasInteractionRange => !interaction.isDefault;

  bool get hasActorAgeRange => actorAgeMin != null || actorAgeMax != null;

  String get sortExpression => dimensionSortId == null
      ? '${sortField.apiValue}:${sortDirection.apiValue}'
      : 'dimension_$dimensionSortId:${sortDirection.apiValue}';

  String triggerLabel(AppLocalizations l10n) {
    final label = switch ((
      years.isNotEmpty,
      hasInteractionRange,
      hasActorAgeRange,
    )) {
      (true, _, _) => movieFilterYearsLabel(years, l10n),
      (_, true, _) => interaction.localizedSummaryLabel(l10n),
      (_, _, true) => movieActorAgeRangeLabel(actorAgeMin, actorAgeMax, l10n),
      _ => status.labelWith(l10n),
    };
    final withResolution = resolution == null
        ? label
        : '$label · ${resolution!.label}';
    return mediaTagIds.isEmpty
        ? withResolution
        : '$withResolution · ${l10n.moviePageMediaTagCount(mediaTagIds.length)}';
  }

  bool matches(MovieFilterState other) =>
      status == other.status &&
      collectionType == other.collectionType &&
      numberSource == other.numberSource &&
      sortField == other.sortField &&
      sortDirection == other.sortDirection &&
      dimensionSortId == other.dimensionSortId &&
      setEquals(years, other.years) &&
      interaction.matches(other.interaction) &&
      actorAgeMin == other.actorAgeMin &&
      actorAgeMax == other.actorAgeMax &&
      resolution == other.resolution &&
      listEquals(mediaTagIds, other.mediaTagIds) &&
      mediaTagMatch == other.mediaTagMatch;

  MovieFilterState copyWith({
    MovieStatusFilter? status,
    MovieCollectionTypeFilter? collectionType,
    MovieNumberSourceFilter? numberSource,
    MovieSortField? sortField,
    SortDirection? sortDirection,
    Object? dimensionSortId = _movieFilterUnset,
    Object? years = _movieFilterUnset,
    MovieInteractionFilter? interaction,
    Object? actorAgeMin = _movieFilterUnset,
    Object? actorAgeMax = _movieFilterUnset,
    Object? resolution = _movieFilterUnset,
    List<int>? mediaTagIds,
    TagMatchMode? mediaTagMatch,
  }) {
    return MovieFilterState(
      status: status ?? this.status,
      resolution: (status ?? this.status) != MovieStatusFilter.playable
          ? null
          : identical(resolution, _movieFilterUnset)
          ? this.resolution
          : resolution as PlaylistResolutionFilter?,
      collectionType: collectionType ?? this.collectionType,
      numberSource: numberSource ?? this.numberSource,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      dimensionSortId: identical(dimensionSortId, _movieFilterUnset)
          ? this.dimensionSortId
          : dimensionSortId as int?,
      years: identical(years, _movieFilterUnset)
          ? this.years
          : years as Set<int>? ?? const <int>{},
      interaction: interaction ?? this.interaction,
      actorAgeMin: identical(actorAgeMin, _movieFilterUnset)
          ? this.actorAgeMin
          : actorAgeMin as int?,
      actorAgeMax: identical(actorAgeMax, _movieFilterUnset)
          ? this.actorAgeMax
          : actorAgeMax as int?,
      mediaTagIds: List<int>.unmodifiable(mediaTagIds ?? this.mediaTagIds),
      mediaTagMatch: mediaTagMatch ?? this.mediaTagMatch,
    );
  }
}
