import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';

/// 视频列表的分页控制器。
///
/// 直接复用干净的泛型基类 [PagedLoadController]（影片页的
/// `PagedMovieSummaryController` 因深绑订阅/番号无法复用），仅补一个按 `id`
/// 删除条目的能力，供删除视频后就地从列表移除。
class PagedVideoSummaryController
    extends PagedLoadController<VideoItemListItemDto> {
  PagedVideoSummaryController({
    required super.fetchPage,
    super.pageSize = 24,
    super.loadMoreTriggerOffset = 300,
    super.initialLoadErrorText = '视频列表加载失败，请稍后重试',
    super.loadMoreErrorText = '加载更多失败，请点击重试',
  });

  /// 删除某视频后就地移除其列表项并同步总数，避免整列重载。
  void removeItem(int videoId) {
    final index = mutableItems.indexWhere((item) => item.id == videoId);
    if (index < 0) {
      return;
    }
    mutableItems.removeAt(index);
    if (mutableTotal > 0) {
      mutableTotal = mutableTotal - 1;
    }
    notifyListenersSafely();
  }
}
