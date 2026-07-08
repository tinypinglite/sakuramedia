import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart'
    show SortDirection, SortDirectionX;

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

  String get label => switch (this) {
    VideoSortField.createdAt => '入库时间',
    VideoSortField.title => '标题',
    VideoSortField.duration => '时长',
    VideoSortField.fileSize => '文件大小',
  };
}

/// 视频列表的排序状态。标签/人物/关键词筛选由各自的选择器/查询持有，不放这里，
/// 与影片页 [MovieFilterState] 的职责划分保持一致。
class VideoFilterState {
  const VideoFilterState({
    this.sortField = VideoSortField.createdAt,
    this.sortDirection = SortDirection.desc,
  });

  final VideoSortField sortField;
  final SortDirection sortDirection;

  static const VideoFilterState initial = VideoFilterState();

  bool get isDefault =>
      sortField == VideoSortField.createdAt &&
      sortDirection == SortDirection.desc;

  String get sortExpression =>
      '${sortField.apiValue}:${sortDirection.apiValue}';

  bool matches(VideoFilterState other) =>
      sortField == other.sortField && sortDirection == other.sortDirection;

  VideoFilterState copyWith({
    VideoSortField? sortField,
    SortDirection? sortDirection,
  }) {
    return VideoFilterState(
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }
}
