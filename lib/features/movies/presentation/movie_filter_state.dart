enum MovieStatusFilter { all, subscribed, playable }

extension MovieStatusFilterX on MovieStatusFilter {
  String get apiValue => switch (this) {
        MovieStatusFilter.all => 'all',
        MovieStatusFilter.subscribed => 'subscribed',
        MovieStatusFilter.playable => 'playable',
      };

  String get label => switch (this) {
        MovieStatusFilter.all => '全部',
        MovieStatusFilter.subscribed => '已订阅',
        MovieStatusFilter.playable => '可播放',
      };
}

enum MovieCollectionTypeFilter { all, single }

extension MovieCollectionTypeFilterX on MovieCollectionTypeFilter {
  String get apiValue => switch (this) {
        MovieCollectionTypeFilter.all => 'all',
        MovieCollectionTypeFilter.single => 'single',
      };

  String get label => switch (this) {
        MovieCollectionTypeFilter.all => '全部',
        MovieCollectionTypeFilter.single => '单体',
      };
}

enum MovieSortField {
  releaseDate,
  addedAt,
  subscribedAt,
  commentCount,
  scoreNumber,
  wantWatchCount,
  heat,
}

extension MovieSortFieldX on MovieSortField {
  String get apiValue => switch (this) {
        MovieSortField.releaseDate => 'release_date',
        MovieSortField.addedAt => 'added_at',
        MovieSortField.subscribedAt => 'subscribed_at',
        MovieSortField.commentCount => 'comment_count',
        MovieSortField.scoreNumber => 'score_number',
        MovieSortField.wantWatchCount => 'want_watch_count',
        MovieSortField.heat => 'heat',
      };

  String get label => switch (this) {
        MovieSortField.releaseDate => '发行时间',
        MovieSortField.addedAt => '最近入库',
        MovieSortField.subscribedAt => '订阅时间',
        MovieSortField.commentCount => '评论人数',
        MovieSortField.scoreNumber => '评分人数',
        MovieSortField.wantWatchCount => '想看人数',
        MovieSortField.heat => '热度',
      };
}

enum SortDirection { asc, desc }

extension SortDirectionX on SortDirection {
  String get apiValue => switch (this) {
        SortDirection.asc => 'asc',
        SortDirection.desc => 'desc',
      };

  String get label => switch (this) {
        SortDirection.asc => '升序',
        SortDirection.desc => '降序',
      };
}

enum MovieFilterPreset { latestSubscribed, latestAdded }

const Object _movieFilterUnset = Object();

class MovieFilterYearOption {
  const MovieFilterYearOption({required this.year, required this.movieCount});

  final int year;
  final int movieCount;

  String get label => '$year($movieCount)';
}

extension MovieFilterPresetX on MovieFilterPreset {
  String get key => switch (this) {
        MovieFilterPreset.latestSubscribed => 'latest-subscribed',
        MovieFilterPreset.latestAdded => 'latest-added',
      };

  String get label => switch (this) {
        MovieFilterPreset.latestSubscribed => '最新订阅',
        MovieFilterPreset.latestAdded => '最新入库',
      };

  MovieFilterState get filterState => switch (this) {
        MovieFilterPreset.latestSubscribed => const MovieFilterState(
            status: MovieStatusFilter.subscribed,
            collectionType: MovieCollectionTypeFilter.single,
            sortField: MovieSortField.subscribedAt,
            sortDirection: SortDirection.desc,
          ),
        MovieFilterPreset.latestAdded => const MovieFilterState(
            status: MovieStatusFilter.playable,
            collectionType: MovieCollectionTypeFilter.single,
            sortField: MovieSortField.addedAt,
            sortDirection: SortDirection.desc,
          ),
      };
}

class MovieFilterState {
  const MovieFilterState({
    this.status = MovieStatusFilter.all,
    this.collectionType = MovieCollectionTypeFilter.single,
    this.sortField = MovieSortField.releaseDate,
    this.sortDirection = SortDirection.desc,
    this.year,
  });

  final MovieStatusFilter status;
  final MovieCollectionTypeFilter collectionType;
  final MovieSortField sortField;
  final SortDirection sortDirection;
  final int? year;

  static const MovieFilterState initial = MovieFilterState();

  bool get isDefault =>
      status == MovieStatusFilter.all &&
      collectionType == MovieCollectionTypeFilter.single &&
      sortField == MovieSortField.releaseDate &&
      sortDirection == SortDirection.desc &&
      year == null;

  String get sortExpression =>
      '${sortField.apiValue}:${sortDirection.apiValue}';
  String get triggerLabel =>
      year == null ? status.label : '$year · ${status.label}';

  bool matches(MovieFilterState other) =>
      status == other.status &&
      collectionType == other.collectionType &&
      sortField == other.sortField &&
      sortDirection == other.sortDirection &&
      year == other.year;

  bool matchesPreset(MovieFilterPreset preset) => matches(preset.filterState);

  MovieFilterState copyWith({
    MovieStatusFilter? status,
    MovieCollectionTypeFilter? collectionType,
    MovieSortField? sortField,
    SortDirection? sortDirection,
    Object? year = _movieFilterUnset,
  }) {
    return MovieFilterState(
      status: status ?? this.status,
      collectionType: collectionType ?? this.collectionType,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      year: identical(year, _movieFilterUnset) ? this.year : year as int?,
    );
  }
}
