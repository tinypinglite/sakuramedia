import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';

/// 媒体删除后同步 videos 域缓存的统一规则：非 JAV 媒体会连视频条目一起删除并
/// 级联清理合集成员，需要通知 videos 域（`videoMutationEventsProvider`）就地打补丁。
///
/// 媒体管理页、重复媒体与失效媒体三处删除路径共用。
void reportDeletedVideoItems(
  Iterable<MediaListItemDto> items,
  void Function(int videoItemId) reportDeleted,
) {
  for (final item in items) {
    if (item.isVideo) {
      reportDeletedVideoItem(item.videoItemId, reportDeleted);
    }
  }
}

/// [reportDeletedVideoItems] 的单条版本，供不携带 `isVideo` 的 DTO（如失效媒体）
/// 复用同一「videoItemId 非空即通知」规则。
void reportDeletedVideoItem(
  int? videoItemId,
  void Function(int videoItemId) reportDeleted,
) {
  if (videoItemId != null) {
    reportDeleted(videoItemId);
  }
}
