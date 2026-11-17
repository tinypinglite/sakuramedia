import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';

/// 时刻瀑布流加载态占位时刻：JAV 时刻（带番号），封面为 `null` 不触发网络请求，
/// 让真实 `MomentCard` 撑起与数据到位后同形的骨架。
List<MomentListItem> momentListPlaceholders({int count = 8}) {
  return List<MomentListItem>.generate(
    count,
    (index) => MomentListItem(
      pointId: -1 - index,
      mediaId: 100 + index,
      movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
      thumbnailId: 0,
      offsetSeconds: 30,
      image: null,
    ),
    growable: false,
  );
}
