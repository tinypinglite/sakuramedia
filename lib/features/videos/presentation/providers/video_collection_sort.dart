import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';

/// 视频合集详情的排序值对象：`field == null` 表手动顺序（后端 `position:asc`）。
///
/// 存在意义是让详情 provider 的 `applySort` 参数可作为整体值传递、以 `==`
/// 判断「是否变化」，并统一收敛 apiValue 拼接。
@immutable
class VideoCollectionSort {
  const VideoCollectionSort({this.field, this.direction = SortDirection.asc});

  /// 手动顺序（后端 `position:asc`）。
  static const VideoCollectionSort manual = VideoCollectionSort();

  final VideoSortField? field;
  final SortDirection direction;

  /// 传给后端的排序表达式；手动顺序返回 `null`（后端默认 `position:asc`）。
  String? get apiValue {
    final f = field;
    if (f == null) {
      return null;
    }
    return '${f.apiValue}:${direction.apiValue}';
  }

  /// 当前是否为手动顺序：仅此模式下允许拖拽重排。
  bool get isManual => field == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoCollectionSort &&
          other.field == field &&
          other.direction == direction);

  @override
  int get hashCode => Object.hash(field, direction);
}
