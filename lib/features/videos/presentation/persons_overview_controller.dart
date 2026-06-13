import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';
import 'package:sakuramedia/features/videos/data/person_dto.dart';

/// 人物列表分页控制器，复用泛型基类 [PagedLoadController]，补按 id 删除。
class PersonsOverviewController extends PagedLoadController<PersonDto> {
  PersonsOverviewController({
    required super.fetchPage,
    super.pageSize = 30,
    super.initialLoadErrorText = '人物列表加载失败，请稍后重试',
    super.loadMoreErrorText = '加载更多失败，请点击重试',
  });

  void removeItem(int personId) {
    final index = mutableItems.indexWhere((item) => item.id == personId);
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
