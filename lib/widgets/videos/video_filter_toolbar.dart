import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';

/// 视频列表的内联排序工具条：排序字段 + 升降序，均为即时生效的 chip。
///
/// 影片页的 `MovieFilterToolbar` 因要承载状态/合集/年份等多维筛选走 overlay 弹层；
/// 视频只有排序一维，内联呈现更直接。
class VideoFilterToolbar extends StatelessWidget {
  const VideoFilterToolbar({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final VideoFilterState filterState;
  final ValueChanged<VideoFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final field in VideoSortField.values)
          AppTextButton(
            key: Key('videos-filter-sort-${field.apiValue}'),
            label: field.label,
            size: AppTextButtonSize.small,
            isSelected: field == filterState.sortField,
            onPressed: () =>
                onChanged(filterState.copyWith(sortField: field)),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.appSpacing.xs),
          child: AppTextButton(
            key: const Key('videos-filter-sort-direction'),
            label: filterState.sortDirection.label,
            icon: Icon(
              filterState.sortDirection == SortDirection.desc
                  ? Icons.south_rounded
                  : Icons.north_rounded,
            ),
            size: AppTextButtonSize.small,
            onPressed: () => onChanged(
              filterState.copyWith(
                sortDirection: filterState.sortDirection == SortDirection.desc
                    ? SortDirection.asc
                    : SortDirection.desc,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
