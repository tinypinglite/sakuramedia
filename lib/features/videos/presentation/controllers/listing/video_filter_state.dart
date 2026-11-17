import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart'
    show SortDirection, SortDirectionX;
import 'package:sakuramedia/l10n/app_localizations.dart';

export 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart'
    show SortDirection, SortDirectionX;

/// 非 JAV 视频列表的排序字段，对齐后端 `sort=created_at|title|duration|file_size`。
/// 时长/文件大小取条目第一条媒体，无媒体按 0 参与排序。
enum VideoSortField { createdAt, title, duration, fileSize }

extension VideoSortFieldX on VideoSortField {
  String get apiValue => switch (this) {
    VideoSortField.createdAt => 'created_at',
    VideoSortField.title => 'title',
    VideoSortField.duration => 'duration',
    VideoSortField.fileSize => 'file_size',
  };

  /// 排序项展示文案（语言包）。展示层用这个取当前语言的排序名。
  String labelWith(AppLocalizations l10n) => switch (this) {
    VideoSortField.createdAt => l10n.videoSortCreatedAt,
    VideoSortField.title => l10n.videoSortTitle,
    VideoSortField.duration => l10n.videoSortDuration,
    VideoSortField.fileSize => l10n.videoSortFileSize,
  };
}

/// 视频列表的排序与合集归属筛选。标签/人物/关键词筛选由各自的选择器/查询持有，
/// 不放这里，与影片页 [MovieFilterState] 的职责划分保持一致。
class VideoFilterState {
  const VideoFilterState({
    this.sortField = VideoSortField.createdAt,
    this.sortDirection = SortDirection.desc,
    this.uncollected = false,
  });

  final VideoSortField sortField;
  final SortDirection sortDirection;

  /// 只保留不属于任何视频合集的条目（后端 `uncollected=true`）。
  final bool uncollected;

  static const VideoFilterState initial = VideoFilterState();

  /// 是否存在生效的筛选条件。
  ///
  /// **不含排序**：排序是视图偏好，不是筛选条件；「重置筛选」和空态文案
  /// 都只应看这里。
  bool get hasActiveFilters => uncollected;

  String get sortExpression =>
      '${sortField.apiValue}:${sortDirection.apiValue}';

  /// 筛选入口只反映合集归属，不再混入排序。
  String triggerLabel(AppLocalizations l10n) =>
      uncollected ? l10n.videoFilterUncollected : l10n.videoFilterAll;

  /// 重置筛选条件但保留当前排序。
  VideoFilterState resetFilters() => VideoFilterState.initial.copyWith(
    sortField: sortField,
    sortDirection: sortDirection,
  );

  bool matches(VideoFilterState other) =>
      sortField == other.sortField &&
      sortDirection == other.sortDirection &&
      uncollected == other.uncollected;

  VideoFilterState copyWith({
    VideoSortField? sortField,
    SortDirection? sortDirection,
    bool? uncollected,
  }) {
    return VideoFilterState(
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      uncollected: uncollected ?? this.uncollected,
    );
  }
}
