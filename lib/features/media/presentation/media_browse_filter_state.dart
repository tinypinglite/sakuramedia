import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';

/// 「媒体管理」可选的排序字段。`null` 表示不显式指定排序——由后端隐式使用
/// `created_at:desc`（入库时间倒序）作为默认视图。
enum MediaBrowseSortField { fileSize, heat }

extension MediaBrowseSortFieldX on MediaBrowseSortField {
  String get apiValue => switch (this) {
        MediaBrowseSortField.fileSize => 'file_size_bytes',
        MediaBrowseSortField.heat => 'heat',
      };

  String get label => switch (this) {
        MediaBrowseSortField.fileSize => '文件大小',
        MediaBrowseSortField.heat => '热度',
      };
}

/// 排序方向。默认降序。仅在 [MediaBrowseFilterState.sortField] 非 null 时生效。
enum MediaBrowseSortDirection { desc, asc }

extension MediaBrowseSortDirectionX on MediaBrowseSortDirection {
  String get apiValue => switch (this) {
        MediaBrowseSortDirection.asc => 'asc',
        MediaBrowseSortDirection.desc => 'desc',
      };

  String get label => switch (this) {
        MediaBrowseSortDirection.asc => '升序',
        MediaBrowseSortDirection.desc => '降序',
      };
}

/// 归属筛选值：`null` 表示不限，即后端 `kind=all`。
/// 使用 [MediaListItemKind.jav] / [MediaListItemKind.video]，`unknown` 视为不限。
typedef MediaBrowseKindFilter = MediaListItemKind?;

/// 上次秒传状态筛选值域。对应后端 `MediaRapidUploadFilterStatus`：前 4 项跟
/// [LastRapidUploadStatus] 一一对应；[none] 代表"未参与秒传或最近一次已成功"，
/// 后端用 `Media.id.not_in` 反选实现。
///
/// 前端筛选 `null` = 不限，不下发 `rapid_upload_status` 参数。
enum MediaBrowseRapidUploadFilter { none, notHit, failed, cleanupFailed, inProgress }

extension MediaBrowseRapidUploadFilterX on MediaBrowseRapidUploadFilter {
  String get apiValue => switch (this) {
        MediaBrowseRapidUploadFilter.none => 'none',
        MediaBrowseRapidUploadFilter.notHit => 'not_hit',
        MediaBrowseRapidUploadFilter.failed => 'failed',
        MediaBrowseRapidUploadFilter.cleanupFailed => 'cleanup_failed',
        MediaBrowseRapidUploadFilter.inProgress => 'in_progress',
      };

  /// 复用列表 badge 的 label 保持一致文案；`none` 独立文案（badge 侧不显示这个态）。
  String get label => switch (this) {
        MediaBrowseRapidUploadFilter.none => '未秒传',
        MediaBrowseRapidUploadFilter.notHit => LastRapidUploadStatus.notHit.label,
        MediaBrowseRapidUploadFilter.failed => LastRapidUploadStatus.failed.label,
        MediaBrowseRapidUploadFilter.cleanupFailed =>
            LastRapidUploadStatus.cleanupFailed.label,
        MediaBrowseRapidUploadFilter.inProgress =>
            LastRapidUploadStatus.inProgress.label,
      };
}

/// 「媒体管理」筛选状态：不可变值对象，UI 改后调 `controller.reload()` 生效。
class MediaBrowseFilterState {
  const MediaBrowseFilterState({
    this.kind,
    this.libraryId,
    this.rapidUploadStatus,
    this.sortField,
    this.sortDirection = MediaBrowseSortDirection.desc,
  });

  final MediaBrowseKindFilter kind;
  final int? libraryId;

  /// `null` = 不按秒传状态筛选。非 null 时下发 `rapid_upload_status` 参数。
  final MediaBrowseRapidUploadFilter? rapidUploadStatus;

  /// `null` = 使用后端默认（入库时间倒序）；非 null 明确按选中字段+方向排序。
  final MediaBrowseSortField? sortField;
  final MediaBrowseSortDirection sortDirection;

  static const MediaBrowseFilterState initial = MediaBrowseFilterState();

  bool get isDefault =>
      kind == null &&
      libraryId == null &&
      rapidUploadStatus == null &&
      sortField == null &&
      sortDirection == MediaBrowseSortDirection.desc;

  /// 后端 `sort` 查询参数：未指定字段时不下发，让后端使用 `created_at:desc`；
  /// 选中字段后明确下发 `field:dir`。
  String? get sortWire {
    final field = sortField;
    if (field == null) {
      return null;
    }
    return '${field.apiValue}:${sortDirection.apiValue}';
  }

  /// 触发按钮上显示的当前筛选摘要。只反映「归属」维度——库和排序有独立分节，
  /// 不再堆在 trigger 上避免文字变长。归属为 null 时用「全部媒体」占位。
  String get triggerLabel {
    final kindValue = kind;
    if (kindValue == null || kindValue == MediaListItemKind.unknown) {
      return '全部媒体';
    }
    return kindValue.label;
  }

  /// [libraryId] / [rapidUploadStatus] / [sortField] 使用哨兵：省略 = 保持；传 `null` = 清空。
  MediaBrowseFilterState copyWith({
    MediaBrowseKindFilter? kind,
    Object? libraryId = _sentinel,
    Object? rapidUploadStatus = _sentinel,
    Object? sortField = _sentinel,
    MediaBrowseSortDirection? sortDirection,
    bool resetKind = false,
  }) {
    return MediaBrowseFilterState(
      kind: resetKind ? null : (kind ?? this.kind),
      libraryId:
          identical(libraryId, _sentinel) ? this.libraryId : libraryId as int?,
      rapidUploadStatus: identical(rapidUploadStatus, _sentinel)
          ? this.rapidUploadStatus
          : rapidUploadStatus as MediaBrowseRapidUploadFilter?,
      sortField: identical(sortField, _sentinel)
          ? this.sortField
          : sortField as MediaBrowseSortField?,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaBrowseFilterState &&
          other.kind == kind &&
          other.libraryId == libraryId &&
          other.rapidUploadStatus == rapidUploadStatus &&
          other.sortField == sortField &&
          other.sortDirection == sortDirection;

  @override
  int get hashCode => Object.hash(
        kind,
        libraryId,
        rapidUploadStatus,
        sortField,
        sortDirection,
      );
}

const Object _sentinel = Object();

/// 后端 `kind` 查询参数：`jav` / `video` 明确下发，其它一律不加参数（后端默认 `all`）。
String? mediaBrowseKindWire(MediaBrowseKindFilter kind) {
  if (kind == null) {
    return null;
  }
  return switch (kind) {
    MediaListItemKind.jav => 'jav',
    MediaListItemKind.video => 'video',
    MediaListItemKind.unknown => null,
  };
}
