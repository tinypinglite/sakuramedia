import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/use_selection_controller.dart';

/// 重复媒体 / 多版本影片共用的组内多选。
///
/// 组卡里每个文件都可独立选，但任何一组都必须至少保留一个文件。范围选择同样
/// 受这条约束限制，避免 Shift 一次勾掉整组。
SelectionController<int> useMediaGroupSelection<T>({
  required List<T> Function() currentGroups,
  required List<MediaListItemDto> Function(T group) itemsOf,
}) {
  return useSelectionController<int>(
    orderedIds: () => currentGroups()
        .expand(itemsOf)
        .map((item) => item.id)
        .toList(growable: false),
    policy: SelectionPolicy<int>(
      canSelect: (id, selected) {
        for (final group in currentGroups()) {
          final ids = itemsOf(
            group,
          ).map((item) => item.id).toList(growable: false);
          if (!ids.contains(id)) continue;
          final selectedInGroup = ids.where(selected.contains).length;
          return selectedInGroup < ids.length - 1;
        }
        return false;
      },
    ),
  );
}

List<MediaListItemDto> selectedMediaGroupItems<T>({
  required Iterable<T> groups,
  required List<MediaListItemDto> Function(T group) itemsOf,
  required Set<int> selectedIds,
}) {
  return [
    for (final group in groups)
      for (final item in itemsOf(group))
        if (selectedIds.contains(item.id)) item,
  ];
}
